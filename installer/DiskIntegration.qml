import QtQuick
import MakOS.Cutefish 1.0
Item {
    id:adapter
    property var host:null
    CutefishWindow {
        objectName:"cutefishDiskBridge"
        window:adapter.host
        glassEnabled:false
        menus:JSON.stringify([
            {label:"Disk Utility",role:1,submenu:[{label:"Quit Disk Utility",command:"close",shortcut:"Ctrl+W"}]},
            {label:"File",submenu:[{label:"Refresh",command:"refresh"}]},
            {label:"View",submenu:[{label:"Show Sidebar",command:"sidebar",checked:adapter.host?adapter.host.sidebarVisible:true},{label:"Show Only Volumes",command:"volumes",checked:adapter.host?!adapter.host.allDevices:false},{label:"Show All Devices",command:"devices",checked:adapter.host?adapter.host.allDevices:true}]},
            {label:"Window",role:2,submenu:[{label:"Disk Utility",checked:true}]}
        ])
        onCommandTriggered:function(command){if(adapter.host)adapter.host.nativeCommand(command);}
    }
}
