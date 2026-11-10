import QtQuick
import MakOS.Cutefish 1.0
Item {
    id: adapter
    property var host: null
    CutefishWindow {
        objectName: "cutefishRecoveryBridge"
        window: adapter.host
        glassEnabled: false
        menus: JSON.stringify([
            {label:"makOS Recovery", role:1, submenu:[{label:"About makOS Recovery",command:"about"},{separator:true},{label:"Quit Recovery",command:"desktop",shortcut:"Ctrl+Q"}]},
            {label:"Utilities", submenu:[{label:"Restore from Backup",command:"restore"},{label:"Install makOS",command:"install"},{label:"Web Browser",command:"browser"},{label:"Disk Utility",command:"disks"},{separator:true},{label:"Terminal",command:"terminal"}]},
            {label:"Window", role:2, submenu:[{label:"makOS Recovery",checked:true}]},
            {label:"Help", role:3, submenu:[{label:"Recovery Help",command:"help"}]}
        ])
        onCommandTriggered: function(command) { RecoveryBackend.command(command); }
    }
}
