"""Typed Gio D-Bus transport; Qt drives the GLib context without a second UI loop.

PySide 6.8's non-const QDBusArgument overloads cannot safely decode nested maps.
GVariant preserves the original daemon's exact signatures without binding hacks.
"""
from PySide6.QtCore import QObject, Signal, QTimer, QCoreApplication

SERVICE='org.cutefish.Installer'
OBJECT='/org/cutefish/Installer'
REPLIES={'GetDisks':'(aa{sv})','GetLayout':'(a{sv})','GetFileSystems':'(as)','Running':'(v)','Install':'()'}


def plain(value,depth=0):
    if depth>12:raise ValueError('The installer service returned an excessively nested reply.')
    if isinstance(value,dict):
        if len(value)>4096 or any(type(key) is not str for key in value):raise ValueError('Invalid installer properties.')
        return {key:plain(item,depth+1) for key,item in value.items()}
    if isinstance(value,(tuple,list)):
        if len(value)>4096:raise ValueError('The installer service returned too many entries.')
        return [plain(item,depth+1) for item in value]
    if value is None or type(value) in (str,int,float,bool):return value
    raise ValueError('The installer service returned an unsupported value.')


class InstallerTransport(QObject):
    progress=Signal(str,float)
    finished=Signal(bool,str)
    lost=Signal(str)

    def __init__(self,parent=None,*,bus=None):
        super().__init__(parent)
        self.bus=None;self._calls=set();self._subscriptions=[];self._owner='';self._closed=False
        self.signals_connected=False;self._error='The system installer service connection is unavailable.'
        self.timer=QTimer(self);self.timer.setInterval(10)
        try:
            import gi
            gi.require_version('Gio','2.0')
            from gi.repository import Gio,GLib
            self.Gio,self.GLib=Gio,GLib
            self.context=GLib.MainContext.default()
            self.bus=bus if bus is not None else Gio.bus_get_sync(Gio.BusType.SYSTEM,None)
            self.bus.set_exit_on_close(False)
            self._subscriptions.append(self.bus.signal_subscribe('org.freedesktop.DBus','org.freedesktop.DBus','NameOwnerChanged','/org/freedesktop/DBus',SERVICE,Gio.DBusSignalFlags.NONE,self._owner_changed))
            try:
                self._owner=self.bus.call_sync('org.freedesktop.DBus','/org/freedesktop/DBus','org.freedesktop.DBus','GetNameOwner',GLib.Variant('(s)',(SERVICE,)),GLib.VariantType.new('(s)'),Gio.DBusCallFlags.NONE,2000,None).unpack()[0]
            except GLib.Error:pass  # A read call may activate the daemon later.
            for member in ('Progress','Finished'):
                self._subscriptions.append(self.bus.signal_subscribe(SERVICE,SERVICE,member,OBJECT,None,Gio.DBusSignalFlags.NONE,self._signal))
            self._closed_handler=self.bus.connect('closed',lambda *_:self.lost.emit('The installer service connection closed.') if not self._closed else None)
            self.signals_connected=True
            self.timer.timeout.connect(self._dispatch);self.timer.start()
            if QCoreApplication.instance():QCoreApplication.instance().aboutToQuit.connect(self.stop)
        except (ImportError,ValueError):self._error='The Linux Gio D-Bus support is unavailable.'
        except Exception:self._error='The system installer service connection is unavailable.'

    def _dispatch(self):
        for _ in range(32):
            if not self.context.pending():break
            self.context.iteration(False)

    def _owner_changed(self,connection,sender,path,interface,member,parameters,*_):
        name,old,new=parameters.unpack()
        self._owner=new
        if old and old!=new:self.lost.emit('The installer service disconnected.')

    def _signal(self,connection,sender,path,interface,member,parameters,*_):
        if self._closed or not self._owner or sender!=self._owner:return
        if member=='Progress' and parameters.get_type_string()=='(sd)':self.progress.emit(*parameters.unpack())
        elif member=='Finished' and parameters.get_type_string()=='(bs)':self.finished.emit(*parameters.unpack())

    def call(self,method,arguments,done):
        if method not in REPLIES:done(None,'Unsupported installer method.');return
        if self._closed or not self.bus or self.bus.is_closed() or not self.signals_connected:
            done(None,self._error);return
        Gio,GLib=self.Gio,self.GLib
        interface=SERVICE;wire_method=method
        try:
            if method=='Running':
                interface='org.freedesktop.DBus.Properties';wire_method='Get';parameters=GLib.Variant('(ss)',(SERVICE,'Running'))
            elif method=='GetLayout':parameters=GLib.Variant('(s)',tuple(arguments))
            elif method=='Install':
                if len(arguments)!=1 or type(arguments[0]) is not dict or any(type(key) is not str or type(value) is not str for key,value in arguments[0].items()):
                    raise ValueError('Invalid installer options.')
                parameters=GLib.Variant('(a{sv})',({key:GLib.Variant('s',value) for key,value in arguments[0].items()},))
            else:
                if arguments:raise ValueError('Unexpected installer arguments.')
                parameters=GLib.Variant('()',())
        except (ValueError,TypeError):done(None,'Invalid installer request.');return
        cancellable=Gio.Cancellable();self._calls.add(cancellable)
        def complete(connection,result,*_):
            self._calls.discard(cancellable)
            if self._closed:return
            try:
                values=connection.call_finish(result).unpack()
                done(plain(values[0]) if values else None,'')
            except GLib.Error as error:
                # A remote error must never echo account secrets into UI/logs.
                remote=Gio.DBusError.get_remote_error(error) or 'D-Bus request failed'
                done(None,remote+': The installer rejected or could not complete the request.' if method=='Install' else error.message)
            except (ValueError,TypeError) as error:done(None,str(error))
        flags=Gio.DBusCallFlags.ALLOW_INTERACTIVE_AUTHORIZATION if method=='Install' else Gio.DBusCallFlags.NONE
        self.bus.call(SERVICE,OBJECT,interface,wire_method,parameters,GLib.VariantType.new(REPLIES[method]),flags,310000 if method=='Install' else 25000,cancellable,complete)

    def stop(self):
        if self._closed:return
        self._closed=True;self.timer.stop()
        for call in self._calls:call.cancel()
        self._calls.clear()
        if self.bus:
            for subscription in self._subscriptions:self.bus.signal_unsubscribe(subscription)
            self._subscriptions.clear()
            if hasattr(self,'_closed_handler'):self.bus.disconnect(self._closed_handler)
