"""Owned local PTY with VT parsing, resize, bounded history and shell cleanup."""
import codecs
import copy
import fcntl
import html
import os
from pathlib import Path
import pty
import signal
import struct
import subprocess
import sys
import termios
import pyte
from PySide6.QtCore import QObject, Property, Signal, Slot, QTimer

PALETTE = {'black':'#000000','red':'#c01c28','green':'#26a269','brown':'#a27300',
           'blue':'#12488b','magenta':'#a347ba','cyan':'#2aa1b3','white':'#d0cfcc',
           'brightblack':'#5e5c64','brightred':'#f66151','brightgreen':'#33d17a',
           'brightbrown':'#e9ad0c','brightblue':'#2a7bde','brightmagenta':'#c061cb',
           'brightcyan':'#33c7de','brightwhite':'#ffffff'}

class TerminalScreen(pyte.HistoryScreen):
    def __init__(self, columns, lines, response):
        self.response=response;self.alternate=False;self.primary=None
        super().__init__(columns,lines,history=2000)
    def write_process_input(self,data):self.response(data)
    def index(self):
        if self.alternate:pyte.Screen.index(self)
        else:super().index()
    def set_mode(self,*modes,**kwargs):
        if kwargs.get('private') and any(mode in (47,1047,1049) for mode in modes) and not self.alternate:
            self.primary=copy.deepcopy((self.buffer,self.cursor,self.history,self.mode,self.margins))
            super().reset();self.alternate=True
        super().set_mode(*modes,**kwargs)
    def reset_mode(self,*modes,**kwargs):
        if kwargs.get('private') and any(mode in (47,1047,1049) for mode in modes) and self.alternate:
            self.buffer,self.cursor,self.history,self.mode,self.margins=self.primary
            self.primary=None;self.alternate=False
            self.cursor.x=min(self.cursor.x,self.columns-1);self.cursor.y=min(self.cursor.y,self.lines-1)
        super().reset_mode(*modes,**kwargs)

class TerminalSession(QObject):
    changed = Signal()
    def __init__(self, root, parent=None, *, shell_command=None, environment=None, show_banner=None):
        super().__init__(parent)
        self.root=str(root);self.process=None;self.fd=None
        self.shell_command=shell_command;self.environment=environment
        self.show_banner = shell_command is None if show_banner is None else bool(show_banner)
        self.columns=80;self.rows=24
        self.screen=TerminalScreen(self.columns,self.rows,self.write)
        self.stream=pyte.Stream(self.screen)
        self.decoder=codecs.getincrementaldecoder('utf-8')('replace')
        self._text='';self._html='';self._cursor_position=0;self._pending=b'';self._finished=False;self._error='';self._exit_code=None
        self.timer=QTimer(self);self.timer.setInterval(30);self.timer.timeout.connect(self.read)
        self._render()
    @Property(str,notify=changed)
    def text(self):return self._text
    @Property(str,notify=changed)
    def richText(self):return self._html
    @Property(str,notify=changed)
    def errorText(self):return self._error
    @Property(bool,notify=changed)
    def running(self):return self.process is not None and self.process.poll() is None
    @Property(bool,notify=changed)
    def finished(self):return self._finished
    @Property(int,notify=changed)
    def historyRows(self):return 0 if self.screen.alternate else len(self.screen.history.top)
    @Property(int,notify=changed)
    def cursorRow(self):return self.historyRows+self.screen.cursor.y
    @Property(int,notify=changed)
    def cursorColumn(self):return min(self.screen.cursor.x,self.columns-1)
    @Property(int,notify=changed)
    def cursorPosition(self):return self._cursor_position
    @Property(bool,notify=changed)
    def cursorVisible(self):return self.running and not self.screen.cursor.hidden
    @Property(str,notify=changed)
    def title(self):
        return self.screen.title or (Path(self.shell_command[0]).name if self.shell_command else Path(os.environ.get('SHELL','/bin/sh')).name)
    @Property(str,constant=True)
    def locationName(self):return Path(self.root).name or self.root
    @Property(int,notify=changed)
    def columnCount(self):return self.columns
    @Property(int,notify=changed)
    def rowCount(self):return self.rows
    @Slot()
    def start(self):
        if self.running:return
        self.stop()
        self.screen=TerminalScreen(self.columns,self.rows,self.write);self.stream=pyte.Stream(self.screen)
        self.decoder=codecs.getincrementaldecoder('utf-8')('replace')
        self._pending=b'';self._finished=False;self._error='';self._exit_code=None
        self.fd,slave=pty.openpty()
        fcntl.ioctl(slave,termios.TIOCSWINSZ,struct.pack('HHHH',self.rows,self.columns,0,0))
        env=dict(os.environ if self.environment is None else self.environment,TERM='xterm-256color',COLORTERM='truecolor')
        env['MAKOS_TERMINAL_BANNER'] = '1' if self.show_banner else '0'
        shell=env.get('SHELL','/bin/sh')
        if not os.path.isfile(shell):shell='/bin/sh'
        command=list(self.shell_command) if self.shell_command else [shell,'-i']
        try:
            # This helper performs TIOCSCTTY after setsid, then execs the shell;
            # no unsafe Python preexec callback runs in the multithreaded GUI.
            helper=str(Path(__file__).with_name('terminal_child.py'))
            self.process=subprocess.Popen([sys.executable,'-I','-S',helper,*command],stdin=slave,stdout=slave,stderr=slave,cwd=self.root,env=env,start_new_session=True)
            os.set_blocking(self.fd,False);self.timer.start()
        except OSError as exc:
            self._error=str(exc);self.stop()
        finally:os.close(slave)
        self._render();self.changed.emit()
    @Slot(int,int)
    def resize(self,columns,rows):
        columns=max(20,min(300,columns));rows=max(5,min(150,rows))
        if (columns,rows)==(self.columns,self.rows):return
        self.columns=columns;self.rows=rows;self.screen.resize(lines=rows,columns=columns)
        if self.fd is not None:
            try:fcntl.ioctl(self.fd,termios.TIOCSWINSZ,struct.pack('HHHH',rows,columns,0,0))
            except OSError:pass
        self._render();self.changed.emit()
    @Slot(str)
    def write(self,value):
        if self.fd is None or not self.running:return
        data=value.encode('utf-8')
        if len(self._pending)+len(data)>4_000_000:
            self._error='Input is too large for the terminal buffer.';self.changed.emit();return
        self._pending+=data;self._flush_write()
    def _flush_write(self):
        if not self._pending or self.fd is None:return
        try:self._pending=self._pending[os.write(self.fd,self._pending):]
        except BlockingIOError:pass
        except OSError:self._pending=b''
    @Slot(str)
    def paste(self,text):
        if 2004 << 5 in self.screen.mode:self.write('\x1b[200~'+text.replace('\x1b[201~','')+'\x1b[201~')
        else:self.write(text)
    @Slot()
    def interrupt(self):self.write('\x03')
    def owned_groups(self):
        process=self.process
        if not process:return set()
        groups={process.pid}
        if self.fd is not None:
            try:
                foreground=os.tcgetpgrp(self.fd)
                if foreground>0 and os.getsid(foreground)==process.pid:groups.add(foreground)
            except OSError:pass
        return groups
    def signal_process(self,sig,groups=None):
        process=self.process
        if not process:return
        if groups is None:groups=self.owned_groups()
        for group in groups:
            try:
                if os.getsid(group)==process.pid:os.killpg(group,sig)
            except ProcessLookupError:pass
        if process.poll() is None:
            try:process.send_signal(sig)
            except ProcessLookupError:pass
    @Slot()
    def clearScrollback(self):
        self.screen.history.top.clear();self.screen.history.bottom.clear();self._render();self.changed.emit()
    @Slot()
    def clearScreen(self):
        self.clearScrollback();self.screen.erase_in_display(2);self.screen.cursor_position();self._render();self.changed.emit()
    @staticmethod
    def _color(value):
        if value in PALETTE:return PALETTE[value]
        if len(value)==6 and all(c in '0123456789abcdefABCDEF' for c in value):return '#'+value
        return None
    def _render(self):
        rows=list(self.screen.history.top) if not self.screen.alternate else []
        rows.extend(self.screen.buffer[y] for y in range(self.screen.lines))
        plain=[];rendered=[]
        for row in rows:
            chars=[row[x] for x in range(self.columns)]
            plain.append(''.join(char.data for char in chars))
            pieces=[];last=None;run=''
            for char in chars:
                fg,bg=char.fg,char.bg
                if char.reverse:fg,bg=(bg if bg!='default' else '202530'),(fg if fg!='default' else 'e5e9f0')
                style=[]
                if self._color(fg):style.append('color:'+self._color(fg))
                if self._color(bg):style.append('background-color:'+self._color(bg))
                if char.bold:style.append('font-weight:bold')
                if char.italics:style.append('font-style:italic')
                if char.underscore:style.append('text-decoration:underline')
                key=';'.join(style)
                if key!=last and run:
                    value=html.escape(run).replace(' ','&nbsp;');pieces.append('<span style="'+last+'">'+value+'</span>' if last else value);run=''
                last=key;run+=char.data
            if run:
                value=html.escape(run).replace(' ','&nbsp;');pieces.append('<span style="'+last+'">'+value+'</span>' if last else value)
            rendered.append(''.join(pieces))
        self._text='\n'.join(plain)
        self._html='<br/>'.join(rendered)
        before='\n'.join(plain[:self.cursorRow])
        if self.cursorRow:before+='\n'
        before+=''.join(rows[self.cursorRow][x].data for x in range(self.cursorColumn))
        self._cursor_position=len(before.encode('utf-16-le'))//2
    @Slot()
    def read(self):
        if self.fd is None:return
        self._flush_write();changed=False
        for _ in range(16):
            try:
                data=os.read(self.fd,65536)
                if not data:break
                self.stream.feed(self.decoder.decode(data));changed=True
            except BlockingIOError:break
            except OSError:break
        if self.process and self.process.poll() is not None and not self._finished:
            self._finished=True;self._exit_code=self.process.returncode;self.timer.stop()
            self.stream.feed('\r\n[Process completed'+(' — exit '+str(self._exit_code) if self._exit_code else '')+']\r\n');changed=True
        if changed:self._render();self.changed.emit()
    @Slot()
    def stop(self):
        self.timer.stop();process=self.process;failure=None;groups=self.owned_groups()
        try:
            if process and process.poll() is None:
                try:self.signal_process(signal.SIGHUP)
                except OSError as exc:failure=exc
                try:process.wait(timeout=0.2)
                except subprocess.TimeoutExpired:
                    try:self.signal_process(signal.SIGKILL)
                    except OSError as exc:failure=exc
                    try:process.wait(timeout=1)
                    except subprocess.TimeoutExpired:failure=RuntimeError('The shell did not exit after its termination request.')
        finally:
            # The shell may exit on HUP before a foreground job that ignores it.
            # Kill only captured groups still belonging to this owned session.
            if process:
                try:self.signal_process(signal.SIGKILL,groups)
                except OSError as exc:failure=exc
            if self.fd is not None:
                try:os.close(self.fd)
                except OSError:pass
                self.fd=None
            self._pending=b''
            if process is None or process.poll() is not None:self.process=None
            elif failure:self._error='Unable to stop this shell: '+str(failure)
            self.changed.emit()
