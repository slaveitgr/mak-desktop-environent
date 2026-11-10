import QtQuick
import MakOS.Cutefish 1.0
Item {
    id: adapter
    property var host: null
    CutefishWindow {
        window: adapter.host
        glassEnabled: false
        menus: JSON.stringify([
            {label:"Install makOS",role:1,submenu:[{label:"Quit Installer",command:"close",enabled:InstallBackend.canClose,shortcut:"Ctrl+Q"}]},
            {label:"File",submenu:[{label:"Close Window",command:"close",enabled:InstallBackend.canClose}]},
            {label:"Window",role:2,submenu:[{label:"Install makOS",checked:true}]},
            {label:"Help",role:3,submenu:[{label:"Installation Help",command:"help"}]}
        ])
        onCommandTriggered: function(command) { if(command === "close") InstallBackend.close(); else if(adapter.host) adapter.host.showHelp(); }
    }
}
