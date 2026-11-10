"""Session-local launcher activation. Apps is a shell overlay, never a toplevel app."""
from PySide6.QtCore import ClassInfo, QObject, Slot

SERVICE='org.makos.Shell'
PATH='/Shell'

@ClassInfo(**{'D-Bus Interface': SERVICE})
class ShellLauncher(QObject):
    def __init__(self, root, parent=None):
        super().__init__(parent)
        from PySide6.QtDBus import QDBusConnection
        self.root=root
        self.bus=QDBusConnection.sessionBus()
        if not self.bus.registerService(SERVICE):
            raise RuntimeError('The makOS shell launcher service is already owned or unavailable.')
        if not self.bus.registerObject(PATH,self,QDBusConnection.ExportAllSlots):
            self.bus.unregisterService(SERVICE)
            raise RuntimeError('The makOS shell launcher interface could not be registered.')

    @Slot(result=bool)
    def ToggleApps(self):
        self.root.toggleAppsLauncher()
        return True

    def stop(self):
        self.bus.unregisterObject(PATH)
        self.bus.unregisterService(SERVICE)


def request_apps_overlay():
    from PySide6.QtDBus import QDBusConnection,QDBusMessage,QDBus
    message=QDBusMessage.createMethodCall(SERVICE,PATH,SERVICE,'ToggleApps')
    message.setAutoStartService(False)
    reply=QDBusConnection.sessionBus().call(message,QDBus.Block,2000)
    if reply.type()==QDBusMessage.ErrorMessage:
        return False,reply.errorMessage()
    return reply.arguments()==[True],''
