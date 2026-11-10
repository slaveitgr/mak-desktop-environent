"""Actual QML plus owned, no-profile fixture shells; never user Terminal sessions."""
import os
from pathlib import Path
import sys
import tempfile
import time
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT))
from PySide6.QtCore import QObject,QUrl,Slot,QSettings,Qt
from PySide6.QtGui import QGuiApplication,QFont
from PySide6.QtQml import QQmlApplicationEngine,QQmlEngine
from PySide6.QtTest import QTest
from PySide6.QtQuick import QQuickWindow
import shiboken6
from main import Bridge
from filesystem import Workspace
from terminal_session import TerminalSession
from makos_fetch import render

class FixtureBridge(Bridge):
    @Slot(result=QObject)
    def createTerminal(self):
        terminal=TerminalSession(self.workspace.root,self,shell_command=['/bin/sh','-i'],
            environment={**os.environ,'ENV':'','BASH_ENV':'','HISTFILE':'/dev/null','PS1':'fixture$ '},show_banner=False)
        self.terminals.append(terminal);QQmlEngine.setObjectOwnership(terminal,QQmlEngine.CppOwnership)
        return terminal

app=QGuiApplication([]);app.setFont(QFont('.AppleSystemUIFont' if sys.platform=='darwin' else 'Inter',13))
app.setOrganizationName('MakOSTerminalVerification');app.setApplicationName('Isolated')
with tempfile.TemporaryDirectory() as directory:
    QSettings.setDefaultFormat(QSettings.IniFormat);QSettings.setPath(QSettings.IniFormat,QSettings.UserScope,directory)
    bridge=FixtureBridge(Workspace(Path(directory)));engine=QQmlApplicationEngine();warnings=[]
    engine.warnings.connect(lambda items:warnings.extend(str(i) for i in items))
    for key,value in {'Bridge':bridge,'startSettings':False,'startFullscreen':False,'comparisonMode':False,'startNativeWindows':False}.items():engine.rootContext().setContextProperty(key,value)
    engine.load(QUrl.fromLocalFile(str(ROOT/'qml/Main.qml')));assert engine.rootObjects(),warnings
    root=engine.rootObjects()[0];root.setWidth(1360);root.setHeight(900);root.show();root.requestActivate()
    desktop=root.findChild(QObject,'desktop');desktop.setProperty('reduceMotion',True);desktop.setProperty('reduceTransparency',True)
    def wait(predicate):
        deadline=time.monotonic()+4
        while time.monotonic()<deadline:
            QTest.qWait(20)
            if predicate():return
        raise AssertionError('Terminal UI condition timed out: '+repr(warnings))
    def windows():return desktop.property('windows').toVariant()
    try:
        desktop.openApplication('terminal');QTest.qWait(100)
        window=next(w for w in windows() if w.property('appKind')=='terminal');page=window.property('pageItem')
        first=page.property('session');wait(lambda:first.running and 'fixture$' in first.text)
        assert not first.show_banner and first.process.pid and first.fd is not None
        assert (window.property('width'),window.property('height'),window.property('titlebarHeight'))==(877,500,32)
        assert not page.property('tabBarVisible')
        output=page.findChild(QObject,'terminalOutput');output.forceActiveFocus()
        # Real input travels through QML key events, the PTY, and the shell.
        for character in "printf 'real-%s\\n' terminal":QTest.keyClick(root,character)
        QTest.keyClick(root,Qt.Key_Return)
        wait(lambda:'real-terminal' in first.text)
        first.write('stty size\r');wait(lambda:f'{first.rowCount} {first.columnCount}' in first.text)
        assert first.columnCount>=100 and first.rowCount>=25
        shell_menu=desktop.menuRows('Shell').toVariant()
        assert next(row for row in shell_menu if row.get('label')=='New Window')['enabled']
        page.command('newTab');wait(lambda:len(bridge.terminals)==2 and page.property('session').running)
        second=page.property('session');second_process=second.process
        assert page.property('tabBarVisible') and second.process.pid!=first.process.pid
        page.command('previousTab');assert page.property('session')==first and 'real-terminal' in first.text
        page.command('nextTab');assert page.property('session')==second
        page.command('closeTab');wait(lambda:second_process.poll() is not None)
        assert page.property('session')==first and not page.property('tabBarVisible')
        old_cols=first.columnCount;page.command('bigger');wait(lambda:first.columnCount<old_cols)
        page.command('defaultFont');wait(lambda:first.columnCount==old_cols)
        first.write("i=0; while [ $i -lt 60 ]; do printf 'history-%s\\n' $i; i=$((i+1)); done\r")
        wait(lambda:first.historyRows>0 and 'history-59' in first.text)
        assert 'history-0' in first.text
        page.command('clearScrollback');assert first.historyRows==0
        # A fixed inventory fixture allows a public screenshot without host data.
        first.clearScreen();first.stream.feed(render({'version':'Development preview','platform':'Fixture Linux','model':'Fixture PC','kernel':'Linux fixture','architecture':'x86_64','processor':'Fixture processor','graphics':'Fixture graphics','memory':'8 GiB'},True).replace('\n','\r\n'));first._render();first.changed.emit()
        QTest.qWait(100)
        if '--screenshot' in sys.argv:
            image=root.grabWindow();scale=image.width()/root.width()
            image.copy(round(window.x()*scale),round(window.y()*scale),round(window.width()*scale),round(window.height()*scale)).save('/tmp/makos-terminal-fixture.png')
        page.command('newWindow');wait(lambda:len([w for w in windows() if w.property('appKind')=='terminal'])==2)
        assert len(bridge.terminals)==2 and all(t.running for t in bridge.terminals)
        owned=[t.process for t in bridge.terminals]
        root.flushApplications();assert not bridge.terminals and all(p.poll() is not None for p in owned)
        assert not warnings,warnings
        print('Terminal: automatic owned PTY, real keyboard execution, size, tabs, new window, history, font resize, and cleanup passed.')
    finally:
        root.flushApplications();bridge.shutdown();root.close();shiboken6.delete(engine);app.processEvents()
