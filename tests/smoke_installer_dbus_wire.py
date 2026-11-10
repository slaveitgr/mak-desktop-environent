"""Original installer wire types on a new private bus; no disk implementation.

Gio validates aa{sv}/a{sv}/v without PySide's mutable QDBusArgument overloads.
Only fixture data and a fixed fixture password cross this private session bus.
"""
import os
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'installer'));sys.path.insert(0,str(ROOT/'tests'))


def inside():
    import gi
    gi.require_version('Gio','2.0')
    from gi.repository import Gio,GLib
    from PySide6.QtCore import QCoreApplication,QTimer
    from makos_install import InstallerTransport,InstallController,SERVICE,OBJECT
    from test_makos_installer import DISK,LAYOUT,PASSWORD
    app=QCoreApplication([]);bus=Gio.bus_get_sync(Gio.BusType.SESSION,None);errors=[];observed=[]
    owned=bus.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','RequestName',GLib.Variant('(su)',(SERVICE,4)),GLib.VariantType.new('(u)'),Gio.DBusCallFlags.NONE,2000,None).unpack()[0]
    assert owned==1,'Refusing to replace an existing service.'
    def value(item):
        if type(item) is str:return GLib.Variant('s',item)
        if type(item) is bool:return GLib.Variant('b',item)
        if type(item) is int:return GLib.Variant('t',item)
        if type(item) is list:return GLib.Variant('aa{sv}',[mapping(row) for row in item])
        raise AssertionError('Unsupported fixture value')
    def mapping(row):return {key:value(item) for key,item in row.items()}
    xml='<node><interface name="'+SERVICE+'"><method name="GetDisks"><arg direction="out" type="aa{sv}"/></method><method name="GetLayout"><arg direction="in" type="s"/><arg direction="out" type="a{sv}"/></method><method name="Install"><arg direction="in" type="a{sv}"/></method><property name="Running" type="b" access="read"/><signal name="Progress"><arg type="s"/><arg type="d"/></signal><signal name="Finished"><arg type="b"/><arg type="s"/></signal></interface></node>'
    interface=Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0]
    def method(connection,sender,path,iface,name,parameters,invocation):
        if name=='GetDisks':invocation.return_value(GLib.Variant('(aa{sv})',([mapping(DISK)],)))
        elif name=='GetLayout':
            assert parameters.unpack()==(DISK['path'],)
            invocation.return_value(GLib.Variant('(a{sv})',(mapping(LAYOUT),)))
        elif name=='Install':
            assert parameters.get_type_string()=='(a{sv})'
            options=parameters.unpack()[0]
            expected={'disk','fullName','userName','password','hostName','timeZone'}
            if set(options)!=expected or any(type(item) is not str for item in options.values()):errors.append('Installer option types mismatch.')
            if options.get('disk')!=DISK['path'] or options.get('password')!=PASSWORD:errors.append('Fixture options mismatch.')
            observed.append(sorted(options))  # Keys only; never log input values.
            invocation.return_value(GLib.Variant('()',()))
            QTimer.singleShot(10,lambda:bus.emit_signal(None,OBJECT,SERVICE,'Progress',GLib.Variant('(sd)',('copy',0.4))))
            QTimer.singleShot(30,lambda:bus.emit_signal(None,OBJECT,SERVICE,'Finished',GLib.Variant('(bs)',(True,''))))
    registered=bus.register_object(OBJECT,interface,method,lambda *_:GLib.Variant('b',False),None)
    assert registered
    transport=InstallerTransport(bus=bus);assert transport.signals_connected
    controller=InstallController(live=True,transport=transport);stage=[0]
    # A different sender cannot impersonate the installer signal source.
    rogue=Gio.DBusConnection.new_for_address_sync(os.environ['DBUS_SESSION_BUS_ADDRESS'],Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT|Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,None,None)
    rogue.emit_signal(None,OBJECT,SERVICE,'Finished',GLib.Variant('(bs)',(True,'')))
    def step():
        if controller.errorText:errors.append(controller.errorText);app.exit(1);return
        if stage[0]==0 and controller.available and not controller.busy:
            assert controller.disks==[DISK]
            stage[0]=1;controller.selectDisk(DISK['path'])
        elif stage[0]==1 and controller.selectedDisk and not controller.busy:
            assert controller.layout==LAYOUT
            controller.account();assert controller.prepare('Fixture User','fixture',PASSWORD,PASSWORD,'fixture-computer','Etc/UTC')
            stage[0]=2;controller.commit(DISK['path'],True,PASSWORD)
        elif stage[0]==2 and controller.phase=='complete':
            assert len(observed)==1;app.exit(0 if not errors else 1)
    timer=QTimer();timer.timeout.connect(step);timer.start(20)
    QTimer.singleShot(8000,lambda:(errors.append('Private D-Bus fixture timed out.'),app.exit(1)))
    controller.begin();result=app.exec();transport.stop();bus.unregister_object(registered);rogue.close_sync(None)
    assert not errors,errors
    assert result==0 and stage[0]==2 and controller.phase=='complete'
    print('PASS: private-bus GetDisks aa{sv}, nested GetLayout a{sv}, Running variant, Install a{sv}, Progress sd, Finished bs and foreign-sender rejection. Mock daemon only; no disk operations.')
    return result


if __name__=='__main__':
    if sys.platform!='linux':raise SystemExit('This private D-Bus wire test requires Linux/dbus-run-session.')
    if '--inside-private-bus' in sys.argv:raise SystemExit(inside())
    raise SystemExit(subprocess.run(['dbus-run-session','--',sys.executable,str(Path(__file__).resolve()),'--inside-private-bus'],check=False).returncode)
