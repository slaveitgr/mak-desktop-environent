#!/usr/bin/env python3
"""makOS installer UI over the ISO's original Cutefish installation daemon.

Discovery is read-only. Only commit(), after explicit review and confirmation in
an actual makOS live session, can call Install. Passwords never enter argv, logs,
preferences or disk files. The privileged daemon remains responsible for policy,
validation, partitioning, copying and bootloader installation.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sys
from zoneinfo import available_timezones
from PySide6.QtCore import QObject, Property, Signal, Slot, QTimer, QUrl, SLOT
from PySide6.QtGui import QGuiApplication, QFont
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow

ROOT=Path(__file__).resolve().parents[1]
SERVICE='org.cutefish.Installer'
OBJECT='/org/cutefish/Installer'
MINIMUM_SIZE=16_000_000_000
STAGES={'prepare':'Preparing the destination disk…','copy':'Installing makOS…','configure':'Setting up your account…','bootloader':'Installing startup files…','finish':'Finishing installation…'}


def live_system():
    return (sys.platform=='linux' and Path('/run/live/medium').is_mount()
            and Path('/run/live/medium/live/filesystem.squashfs').is_file()
            and Path('/etc/makos/live.json').is_file())


def fingerprint(disk,layout):
    return hashlib.sha256(json.dumps({'disk':disk,'layout':layout},sort_keys=True,separators=(',',':')).encode()).hexdigest()


try:
    from .installer_transport import InstallerTransport
except ImportError:
    from installer_transport import InstallerTransport


class InstallController(QObject):
    changed=Signal()
    returned=Signal()
    def __init__(self,*,live=None,transport=None,parent=None,preview=False):
        super().__init__(parent)
        self._live=live_system() if live is None else bool(live)
        self._preview=bool(preview or not self._live)
        self._transport=transport if transport is not None else (InstallerTransport(self) if self._live and not preview else None)
        self._disks=[];self._disk={};self._layout={};self._error='';self._phase='intro';self._busy=False
        self._available=False;self._accepted=False;self._committing=False;self._fingerprint='';self._review={}
        self._progress=0.;self._stage='';self._pending_progress=None;self._pending_finished=None
        self._serial=0;self._zones=sorted(zone for zone in available_timezones() if '/' in zone and not zone.startswith(('posix/','right/')))
        if self._transport:
            self._transport.progress.connect(self._on_progress)
            self._transport.finished.connect(self._on_finished)
            self._transport.lost.connect(self._on_lost)
    @Property(bool,constant=True)
    def live(self):return self._live and not self._preview
    @Property(bool,constant=True)
    def preview(self):return self._preview
    @Property('QVariantList',notify=changed)
    def disks(self):return self._disks
    @Property('QVariantMap',notify=changed)
    def selectedDisk(self):return self._disk
    @Property('QVariantMap',notify=changed)
    def layout(self):return self._layout
    @Property('QVariantMap',notify=changed)
    def review(self):return self._review
    @Property('QStringList',constant=True)
    def timeZones(self):return self._zones
    @Property(str,notify=changed)
    def phase(self):return self._phase
    @Property(bool,notify=changed)
    def busy(self):return self._busy
    @Property(bool,notify=changed)
    def available(self):return self._available
    @Property(str,notify=changed)
    def errorText(self):return self._error
    @Property(float,notify=changed)
    def progress(self):return self._progress
    @Property(str,notify=changed)
    def stageText(self):return self._stage
    @Property(bool,notify=changed)
    def canClose(self):return not self._committing and self._phase not in ('starting','installing','uncertain')
    def _fail(self,error,phase=None):
        self._busy=False;self._committing=False;self._error=str(error)
        if phase:self._phase=phase
        self.changed.emit()
    def _read(self,method,args,done):
        if not self._transport:done(None,'Boot the makOS live image to use the system installer.');return
        self._transport.call(method,args,done)
    @Slot()
    def begin(self):
        if not self.canClose or self._busy:return
        self._phase='disk';self.refresh()
    @Slot()
    def refresh(self):
        if self._busy or not self.canClose:return
        self._disk={};self._layout={};self._review={};self._fingerprint='';self._error='';self._available=False
        if self._preview:
            self._disks=[];self._error='Preview only. Boot the makOS live image to discover installation disks.';self.changed.emit();return
        self._busy=True;self._serial+=1;serial=self._serial;self.changed.emit()
        def disks_done(disks,error):
            if serial!=self._serial:return
            if error:self._disks=[];self._fail(error);return
            try:self._disks=self._validated_disks(disks)
            except (ValueError,TypeError) as exc:self._fail(exc);return
            def running_done(running,error):
                if serial!=self._serial:return
                if error or type(running) is not bool:self._fail(error or 'Invalid installer state.');return
                self._busy=False;self._available=not running
                self._error='Another installation is already running.' if running else ('' if self._disks else 'No available destination disks were reported by the live installer.')
                self.changed.emit()
            self._read('Running',[],running_done)
        self._read('GetDisks',[],disks_done)
    @staticmethod
    def _validated_disks(disks):
        if not isinstance(disks,list) or len(disks)>256:raise ValueError('Invalid disk list from the installer.')
        result=[];seen=set()
        for disk in disks:
            if not isinstance(disk,dict):raise ValueError('Invalid disk information.')
            path=disk.get('path');size=disk.get('size');model=disk.get('model')
            if not isinstance(path,str) or not re.fullmatch(r'/dev/[A-Za-z0-9_.-]+',path) or path in seen:raise ValueError('Invalid disk identity.')
            if type(size) is not int or size<=0 or not isinstance(model,str):raise ValueError('Invalid disk size or model.')
            seen.add(path);result.append({'path':path,'size':size,'model':model,'removable':bool(disk.get('removable'))})
        return result
    @staticmethod
    def _validated_layout(layout,disk):
        if not isinstance(layout,dict) or layout.get('disk')!=disk['path'] or layout.get('size')!=disk['size']:
            raise ValueError('The destination disk changed. Refresh and select it again.')
        if not isinstance(layout.get('partitions'),list) or len(layout['partitions'])>256:raise ValueError('Invalid partition information.')
        return layout
    @Slot(str)
    def selectDisk(self,path):
        if self._busy or not self._available or not self.canClose:return
        disk=next((disk for disk in self._disks if disk['path']==path),None)
        if not disk:return
        if disk['size']<MINIMUM_SIZE:self._fail('Choose a disk with at least 16 GB of capacity.');return
        self._busy=True;self._disk={};self._layout={};self._review={};self._error='';self._serial+=1;serial=self._serial;self.changed.emit()
        def layout_done(layout,error):
            if serial!=self._serial:return
            if error:self._fail(error);return
            try:self._layout=self._validated_layout(layout,disk)
            except (ValueError,TypeError) as exc:self._fail(exc);return
            self._disk=disk;self._fingerprint=fingerprint(disk,layout);self._busy=False;self.changed.emit()
        self._read('GetLayout',[path],layout_done)
    @Slot()
    def account(self):
        if self._disk and self._layout and not self._busy:self._phase='account';self._error='';self.changed.emit()
    @Slot(str,str,str,str,str,str,result=bool)
    def prepare(self,full_name,user_name,password,repeated,host_name,time_zone):
        if self._phase!='account' or self._busy or not self._disk:return False
        if not full_name.strip() or len(full_name)>128 or any(char in full_name for char in ('\0','\n','\r',':')):return self._validation('Enter a valid full name.')
        if not re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}',user_name):return self._validation('Use a lowercase account name of up to 32 letters, numbers, underscores or hyphens.')
        if len(password)<8 or len(password)>1024 or any(char in password for char in ('\0',':','\n','\r')):return self._validation('Use a password of 8 or more characters without a colon or line break.')
        if password!=repeated:return self._validation('The passwords do not match.')
        if not re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?',host_name):return self._validation('Enter a computer name using letters, numbers and inner hyphens.')
        if time_zone not in self._zones:return self._validation('Choose a valid time zone.')
        # No password is retained in the review model. commit receives it from
        # the protected UI field after the user confirms the exact destination.
        self._review={'disk':self._disk['path'],'fullName':full_name.strip(),'userName':user_name,'hostName':host_name,'timeZone':time_zone,
                      'mode':'Erase entire disk','scheme':'GUID Partition Table','fileSystem':'ext4'}
        self._phase='review';self._error='';self.changed.emit();return True
    def _validation(self,message):self._error=message;self.changed.emit();return False
    @Slot()
    def back(self):
        if self._busy or not self.canClose:return
        self._phase={'disk':'intro','account':'disk','review':'account','failed':'disk'}.get(self._phase,'intro')
        self._error='';self._review={};self.changed.emit()
    @Slot(str,bool,str,result=bool)
    def commit(self,confirmation,acknowledged,password):
        if not self.live or not self._transport:return self._validation('Installation is disabled outside the makOS live image.')
        if self._phase!='review' or self._busy or not self._available or not self._review:return self._validation('Review the destination and account before installing.')
        if not acknowledged or confirmation!=self._disk.get('path'):return self._validation('Confirm erasing this disk by entering its exact device path.')
        if len(password)<8 or len(password)>1024 or any(char in password for char in ('\0',':','\n','\r')):return self._validation('The account password is no longer valid. Go back and enter it again.')
        self._busy=True;self._committing=True;self._error='';self._stage='Checking the destination again…';self._serial+=1;serial=self._serial;self.changed.emit()
        options={key:self._review[key] for key in ('disk','fullName','userName','hostName','timeZone')};options['password']=password
        def abort(message):options.clear();self._fail(message,'disk');self._available=False;self._disk={};self._layout={};self._review={};self.changed.emit()
        def got_disks(disks,error):
            if serial!=self._serial:return
            if error:abort(error);return
            try:
                listed=self._validated_disks(disks)
                current=next((disk for disk in listed if disk['path']==options['disk']),None)
                if current!=self._disk:raise ValueError('The destination disk changed. Refresh and review it again.')
            except (ValueError,TypeError) as exc:abort(str(exc));return
            def got_layout(layout,error):
                if serial!=self._serial:return
                if error:abort(error);return
                try:
                    self._validated_layout(layout,current)
                    if fingerprint(current,layout)!=self._fingerprint:raise ValueError('The partition layout changed. Review the destination again.')
                except (ValueError,TypeError) as exc:abort(str(exc));return
                def got_running(running,error):
                    if serial!=self._serial:return
                    if error or running is not False:abort(error or 'Another installation is running.');return
                    self._phase='starting';self._stage='Requesting permission to install…';self._accepted=False;self._pending_progress=None;self._pending_finished=None;self.changed.emit()
                    self._transport.call('Install',[options],installed)
                self._read('Running',[],got_running)
            self._read('GetLayout',[current['path']],got_layout)
        def installed(_reply,error):
            options.clear()
            if serial!=self._serial:return
            if error:
                # An ambiguous timeout/disconnect may occur after the daemon
                # has accepted the request. Never offer an automatic retry.
                known_rejection=any(name in error for name in ('org.freedesktop.DBus.Error.AccessDenied','org.freedesktop.DBus.Error.InvalidArgs','org.cutefish.Installer.Error.Busy'))
                self._phase='failed' if known_rejection else 'uncertain';self._busy=False;self._committing=False
                self._error=('Installation was rejected: '+error) if known_rejection else ('Installation was not confirmed: '+error+' Check the installer before restarting or removing the installation media.')
                self.changed.emit();return
            self._accepted=True;self._phase='installing';self._stage='Preparing the destination disk…';self.changed.emit()
            if self._pending_progress:self._on_progress(*self._pending_progress)
            if self._pending_finished:self._on_finished(*self._pending_finished)
        self._read('GetDisks',[],got_disks)
        return True
    @Slot(str,float)
    def _on_progress(self,stage,fraction):
        if self._phase not in ('starting','installing'):return
        if stage not in STAGES or not math.isfinite(fraction) or not 0<=fraction<=1:return
        if not self._accepted:self._pending_progress=(stage,fraction);return
        self._stage=STAGES[stage];self._progress=fraction;self.changed.emit()
    @Slot(bool,str)
    def _on_finished(self,success,error):
        if self._phase not in ('starting','installing'):return
        if not self._accepted:self._pending_finished=(success,error);return
        self._phase='complete' if success else 'failed';self._busy=False;self._committing=False;self._accepted=False
        self._error='' if success else (error or 'The installer reported a failure.')
        self._stage='makOS was installed.' if success else 'Installation did not complete.'
        if success:self._progress=1.
        self.changed.emit()
    @Slot(str)
    def _on_lost(self,message):
        self._serial+=1
        if self._phase in ('starting','installing'):
            self._phase='uncertain';self._error=message+' Installation may still be running. Do not restart or remove the installation media.';self._busy=False;self._committing=False;self.changed.emit()
        else:self._available=False;self._fail(message)
    @Slot()
    def close(self):
        if self.canClose:self.returned.emit()


def main(argv=None):
    parser=argparse.ArgumentParser();parser.add_argument('--preview',action='store_true');parser.add_argument('--native-shell',action='store_true');parser.add_argument('--smoke-test',action='store_true');parser.add_argument('--screenshot',type=Path)
    args=parser.parse_args(argv)
    os.environ.setdefault('QT_QUICK_CONTROLS_STYLE','Basic')
    app=QGuiApplication([]);app.setApplicationName('Install makOS');app.setOrganizationName('makOS');app.setDesktopFileName('org.makos.Installer')
    app.setFont(QFont('.AppleSystemUIFont' if sys.platform=='darwin' else 'Inter',13))
    controller=InstallController(preview=args.preview or args.smoke_test)
    engine=QQmlApplicationEngine();native=bool(args.native_shell and os.environ.get('WAYLAND_DISPLAY'))
    if native:engine.addImportPath(str(ROOT/'cutefish/build/qml'))
    engine.rootContext().setContextProperty('InstallBackend',controller);engine.rootContext().setContextProperty('nativeShell',native)
    engine.load(QUrl.fromLocalFile(str(ROOT/'installer/InstallWindow.qml')))
    if not engine.rootObjects():return 1
    window=engine.rootObjects()[0];window.show();controller.returned.connect(app.quit)
    if args.smoke_test or args.screenshot:
        def capture():
            if args.screenshot:window.grabWindow().save(str(args.screenshot))
            print('PASS: makOS installer preview loaded; installation disabled.');app.quit()
        QTimer.singleShot(800,capture)
    result=app.exec()
    import shiboken6
    shiboken6.delete(engine)
    return result

if __name__=='__main__':raise SystemExit(main())
