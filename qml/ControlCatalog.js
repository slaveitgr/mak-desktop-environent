.pragma library

// Labels are observed in Tahoe's ControlCenterSettings resources and live Menu
// Bar settings. Default arrangement follows the local Tahoe Control Center
// runtime observation recorded in control-center-tahoe-2026-11-10.json.
var controls = [
 {id:"clock",label:"Clock",icon:"clock",category:"System",settingsPage:"Menu Bar",defaultBar:true,menu:true,sizes:["small"],defaultSize:"small",description:"Date and time options."},
 {id:"search",label:"Spotlight",icon:"search",category:"System",settingsPage:"Spotlight",defaultBar:true,menu:true,sizes:["small"],defaultSize:"small",description:"Search this desktop."},
 {id:"wifi",label:"Wi-Fi",icon:"wifi",category:"Connectivity",settingsPage:"Wi-Fi",defaultBar:true,menu:true,sizes:["small","medium"],defaultSize:"medium",description:"View Wi-Fi controls and settings."},
 {id:"bluetooth",label:"Bluetooth",icon:"bluetooth",category:"Connectivity",settingsPage:"Bluetooth",defaultBar:true,menu:true,sizes:["small","medium"],defaultSize:"medium",description:"View Bluetooth controls and settings."},
 {id:"battery",label:"Battery",icon:"battery",category:"System",settingsPage:"Battery",defaultBar:true,menu:true,sizes:["small","medium"],defaultSize:"small",description:"Power status and battery options."},
 {id:"airdrop",label:"AirDrop",icon:"airdrop",category:"Connectivity",settingsPage:"Sharing",defaultBar:false,menu:true,sizes:["small","medium"],defaultSize:"medium",description:"Nearby sharing controls."},
 {id:"focus",label:"Focus",icon:"moon",category:"Focus",settingsPage:"Focus",defaultBar:true,menu:true,supportsMode:true,defaultMode:"When Active",sizes:["small","medium"],defaultSize:"medium",description:"Silence this desktop's notifications."},
 {id:"mirroring",label:"Screen Mirroring",icon:"mirroring",category:"Display",settingsPage:"Displays",defaultBar:true,menu:true,supportsMode:true,defaultMode:"When Active",sizes:["small","medium"],defaultSize:"medium",description:"Screen mirroring controls."},
 {id:"display",label:"Display",icon:"sun",category:"Display",settingsPage:"Displays",defaultBar:true,menu:true,supportsMode:true,defaultMode:"When Active",sizes:["medium","large"],defaultSize:"large",description:"Adjust this desktop's brightness."},
 {id:"sound",label:"Sound",icon:"speaker",category:"Sound",settingsPage:"Sound",defaultBar:true,menu:true,supportsMode:true,defaultMode:"Always",sizes:["medium","large"],defaultSize:"large",description:"System output volume in the Linux session; Music volume in preview."},
 {id:"nowplaying",label:"Now Playing",icon:"play",category:"Sound",settingsPage:"Sound",defaultBar:true,menu:true,supportsMode:true,defaultMode:"When Active",sizes:["medium","large"],defaultSize:"medium",description:"Control the current Music track."},
 {id:"users",label:"Fast User Switching",icon:"account",category:"System",settingsPage:"Users & Groups",defaultBar:false,menu:true,sizes:["small","medium"],defaultSize:"small",description:"User account settings."},
 {id:"textinput",label:"Text Input",icon:"keyboard",category:"System",settingsPage:"Keyboard",defaultBar:false,menu:true,sizes:["small"],defaultSize:"small",description:"Keyboard and input settings."},
 {id:"timemachine",label:"Time Machine",icon:"clock",category:"System",settingsPage:"Time Machine",defaultBar:false,menu:true,sizes:["small"],defaultSize:"small",description:"Backup settings."},
 {id:"timer",label:"Timer",icon:"timer",category:"Utilities",settingsPage:"",defaultBar:true,menu:true,supportsMode:true,defaultMode:"When Active",sizes:["small","medium"],defaultSize:"medium",description:"Start a countdown timer."},
 {id:"weather",label:"Weather",icon:"weather",category:"Utilities",settingsPage:"",defaultBar:false,menu:true,sizes:["small","medium","large"],defaultSize:"medium",description:"Weather service is not connected."},
 {id:"accessibility",label:"Accessibility Shortcuts",icon:"accessibility",category:"Accessibility",settingsPage:"Accessibility",defaultBar:false,sizes:["small","medium"],defaultSize:"small",description:"Reduce Motion and Reduce Transparency."},
 {id:"darkmode",label:"Dark Mode",icon:"appearance",category:"Display",settingsPage:"Appearance",defaultBar:false,sizes:["small","medium"],defaultSize:"small",description:"Switch between light and dark appearance."},
 {id:"keyboardbrightness",label:"Keyboard Brightness",icon:"keyboard",category:"Display",settingsPage:"Keyboard",defaultBar:false,sizes:["medium","large"],defaultSize:"medium",description:"Keyboard lighting requires a connected system service."},
 {id:"lowpower",label:"Low Power Mode",icon:"battery",category:"System",settingsPage:"Battery",defaultBar:false,sizes:["small","medium"],defaultSize:"small",description:"Power management requires a connected system service."},
 {id:"hearing",label:"Hearing",icon:"speaker",category:"Accessibility",settingsPage:"Accessibility",defaultBar:false,sizes:["small","medium"],defaultSize:"small",description:"Hearing accessibility settings."},
 {id:"musicrecognition",label:"Recognize Music",icon:"search",category:"Sound",settingsPage:"",defaultBar:false,sizes:["small"],defaultSize:"small",description:"Music recognition service is not connected."},
 {id:"stagemanager",label:"Stage Manager",icon:"sidebar",category:"Display",settingsPage:"Desktop & Dock",defaultBar:false,sizes:["small","medium"],defaultSize:"small",description:"Window organization settings."},
 {id:"capture",label:"Capture Screen",icon:"camera",category:"Utilities",settingsPage:"",defaultBar:false,sizes:["small"],defaultSize:"small",description:"Screen capture is not connected yet."}
];
var defaultLayout = [{id:"wifi",size:"medium"},{id:"nowplaying",size:"medium"},{id:"bluetooth",size:"medium"},{id:"airdrop",size:"medium"},{id:"stagemanager",size:"small"},{id:"mirroring",size:"small"},{id:"darkmode",size:"small"},{id:"capture",size:"small"},{id:"focus",size:"medium"},{id:"display",size:"large"},{id:"sound",size:"large"}];
var defaultMenuOrder = ["bluetooth","wifi","airdrop","focus","mirroring","display","sound","nowplaying","users","textinput","timemachine","timer","weather","battery","search"];
