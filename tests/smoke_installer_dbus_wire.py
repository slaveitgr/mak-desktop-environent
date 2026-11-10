"""Exact QtDBus installer wire contract on a newly created private session bus.

The exported mock has no filesystem/install implementation. It validates the
real adapter's a{sv} options and returns aa{sv}/a{sv} like the shipped daemon.
Run on Linux: python tests/smoke_installer_dbus_wire.py
"""
import copy
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'installer'))
sys.path.insert(0,str(ROOT/'tests'))

def inside():
    from PySide6.QtCore import QCoreApplication,QObject,Signal,Slot,Property,QTimer,QMetaType,ClassInfo
    from PySide6.QtDBus import QDBusArgument,QDBusVariant,QDBusMessage,QDBusConnection
    from makos_install import InstallerTransport,InstallController,SERVICE,OBJECT
    from test_makos_installer import DISK,LAYOUT,PASSWORD
    app=QCoreApplication([]);bus=QDBusConnection.sessionBus();errors=[];observed=[]
    assert bus.isConnected()
    assert not bus.interface().isServiceRegistered(SERVICE).value(),'Refusing to replace an existing service.'

    def append_map(argument,values):
        argument.beginMap(QMetaType.Type.QString,QMetaType.Type.QVariant)
        for key,value in values.items():
            argument.beginMapEntry();argument << key;argument << QDBusVariant(value);argument.endMapEntry()
        argument.endMap()
    @ClassInfo(**{'D-Bus Interface':SERVICE})
    class Fixture(QObject):
        Progress=Signal(str,float)
        Finished=Signal(bool,str)
        @Property(bool)
        def Running(self):return False
        @Slot(QDBusMessage)
        def GetDisks(self,message):
            argument=QDBusArgument();argument.beginArray(QMetaType.Type.QVariantMap)
            append_map(argument,DISK);argument.endArray()
            message.setDelayedReply(True);bus.send(message.createReply([argument]))
        @Slot(str,result='QVariantMap')
        def GetLayout(self,path):
            assert path==DISK['path'];return copy.deepcopy(LAYOUT)
        @Slot('QVariantMap')
        def Install(self,options):
            # Matching this method at all requires the exact a{sv} signature.
            expected={'disk','fullName','userName','password','hostName','timeZone'}
            if set(options)!=expected or any(type(value) is not str for value in options.values()):
                errors.append('Installer options did not match a{sv} string contract.')
            if options.get('disk')!=DISK['path'] or options.get('password')!=PASSWORD:errors.append('Fixture options mismatch.')
            observed.append(sorted(options))  # Keys only, never passwords.
            QTimer.singleShot(10,lambda:self.Progress.emit('copy',0.4))
            QTimer.singleShot(30,lambda:self.Finished.emit(True,''))
    fixture=Fixture()
    flags=QDBusConnection.RegisterOption.ExportAllSlots|QDBusConnection.RegisterOption.ExportAllSignals|QDBusConnection.RegisterOption.ExportAllProperties
    assert bus.registerObject(OBJECT,fixture,flags)
    assert bus.registerService(SERVICE)
    transport=InstallerTransport(bus=bus);assert transport.signals_connected
    controller=InstallController(live=True,transport=transport)
    stage=[0]
    def step():
        if controller.errorText:errors.append(controller.errorText);app.exit(1);return
        if stage[0]==0 and controller.available and not controller.busy:
            assert controller.disks==[DISK],controller.disks
            stage[0]=1;controller.selectDisk(DISK['path'])
        elif stage[0]==1 and controller.selectedDisk and not controller.busy:
            assert controller.layout==LAYOUT,controller.layout
            controller.account();assert controller.prepare('Fixture User','fixture',PASSWORD,PASSWORD,'fixture-computer','Etc/UTC')
            stage[0]=2;controller.commit(DISK['path'],True,PASSWORD)
        elif stage[0]==2 and controller.phase=='complete':
            assert len(observed)==1;app.exit(0 if not errors else 1)
    timer=QTimer();timer.timeout.connect(step);timer.start(20)
    QTimer.singleShot(8000,lambda:(errors.append('Private D-Bus fixture timed out.'),app.exit(1)))
    controller.begin();result=app.exec()
    assert not errors,errors
    assert result==0 and stage[0]==2 and controller.phase=='complete'
    print('PASS: private-bus GetDisks aa{sv}, GetLayout a{sv}, Running variant, Install a{sv}, Progress sd and Finished bs. Mock daemon only; no disk operations.')
    return result

if __name__=='__main__':
    if sys.platform!='linux':raise SystemExit('This private D-Bus wire test requires Linux/dbus-run-session.')
    if '--inside-private-bus' in sys.argv:raise SystemExit(inside())
    # DBUS_SESSION_BUS_ADDRESS inherited by this child is freshly allocated.
    raise SystemExit(subprocess.run(['dbus-run-session','--',sys.executable,str(Path(__file__).resolve()),'--inside-private-bus'],check=False).returncode)
