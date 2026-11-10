import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: window
    objectName: "makOSInstaller"
    width: 920; height: 720
    minimumWidth: 760; minimumHeight: 650
    visible: false
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Install makOS"
    color: "#080809"
    palette.window: "#ededed"
    palette.base: "#ffffff"
    palette.text: "#1d1d1f"
    palette.button: "#eeeeee"
    palette.buttonText: "#1d1d1f"
    palette.highlight: "#1685f8"
    palette.highlightedText: "white"
    readonly property string phase: InstallBackend.phase
    readonly property color ink: "#1d1d1f"
    readonly property color muted: "#6e6e73"
    function showHelp() { help.open(); }
    function next() {
        if(phase === "intro") InstallBackend.begin();
        else if(phase === "disk") InstallBackend.account();
        else if(phase === "account") InstallBackend.prepare(fullName.text,userName.text,password.text,passwordRepeat.text,hostName.text,timeZone.editText);
        else if(phase === "review") InstallBackend.commit(confirmDisk.text,eraseConsent.checked,password.text);
        else if(phase === "complete") InstallBackend.close();
    }
    onClosing: function(event) { event.accepted=false;InstallBackend.close(); }
    Loader { source: nativeShell ? "InstallIntegration.qml" : ""; onLoaded: item.host=window }
    Connections {
        target: InstallBackend
        function onChanged() {
            if(["starting","installing","uncertain","failed","complete"].indexOf(window.phase)>=0) {
                password.clear();passwordRepeat.clear();
            }
            if(window.phase !== "review") { confirmDisk.clear();eraseConsent.checked=false; }
        }
    }
    component Label: Text { color:window.ink;font.pixelSize:13;wrapMode:Text.Wrap }
    component Hint: Text { color:window.muted;font.pixelSize:12;wrapMode:Text.Wrap }
    component Field: TextField {
        width:330;height:32;color:window.ink;selectionColor:"#1685f8";selectedTextColor:"white"
        font.pixelSize:13;leftPadding:10;selectByMouse:true
        background:Rectangle { radius:6;color:"white";border.color:parent.activeFocus?"#4e9de8":"#b5b5b9";border.width:parent.activeFocus?2:1 }
    }
    component Action: Button {
        property bool primary:false
        implicitHeight:28;implicitWidth:Math.max(82,contentItem.implicitWidth+26)
        contentItem:Text { text:parent.text;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;color:parent.enabled?(parent.primary?"white":window.ink):"#aaaab0";font.pixelSize:13 }
        background:Rectangle { radius:6;color:parent.enabled?(parent.primary?"#1685f8":"#ffffff"):"#e1e1e4";border.color:parent.primary?"#389bff":"#b8b8bd" }
    }
    Rectangle {
        visible: !nativeShell
        width:parent.width;height:30;color:"#151517"
        Image { x:13;y:6;width:24;height:18;source:"branding/makos-ck-symbol.svg";fillMode:Image.PreserveAspectFit }
        Text { x:52;anchors.verticalCenter:parent.verticalCenter;text:"Install makOS";font.pixelSize:13;font.weight:Font.DemiBold;color:"#f1f1f2" }
        Text { x:175;anchors.verticalCenter:parent.verticalCenter;text:"File     Window     Help";font.pixelSize:13;color:"#f1f1f2" }
    }
    Rectangle {
        id: card
        width:Math.min(720,window.width-48);height:Math.min(606,window.height-74)
        anchors.centerIn:parent;radius:12
        gradient:Gradient { GradientStop { position:0;color:"#f4f4f4" } GradientStop { position:1;color:"#e6e6e8" } }
        border.color:"#b7b7bc"
        Text {
            x:28;y:21;width:parent.width-56
            text:window.phase === "intro" ? "" : window.phase === "disk" ? "Select the disk where you want to install makOS." : window.phase === "account" ? "Create a Computer Account" : window.phase === "review" ? "Ready to Install makOS" : window.phase === "complete" ? "Installation Complete" : window.phase === "failed" ? "Installation Failed" : "Install makOS"
            color:window.ink;font.pixelSize:20;font.weight:Font.DemiBold;horizontalAlignment:Text.AlignHCenter;wrapMode:Text.Wrap
        }
        Column {
            visible:window.phase === "intro";anchors.horizontalCenter:parent.horizontalCenter;y:46;width:parent.width-100;spacing:24
            Image { anchors.horizontalCenter:parent.horizontalCenter;width:230;height:230;sourceSize:Qt.size(width*Screen.devicePixelRatio,height*Screen.devicePixelRatio);source:"assets/install.svg";fillMode:Image.PreserveAspectFit }
            Text { width:parent.width;text:"makOS";horizontalAlignment:Text.AlignHCenter;font.pixelSize:27;font.weight:Font.DemiBold;color:window.ink }
            Label { width:parent.width;text:"To set up the installation of makOS, click Continue.";horizontalAlignment:Text.AlignHCenter }
            Hint { width:parent.width;text:InstallBackend.preview?"Interface preview. Installation is disabled.":"This installer installs the makOS Linux system from this live image.";horizontalAlignment:Text.AlignHCenter }
        }
        Column {
            visible:window.phase === "disk";x:34;y:83;width:parent.width-68;spacing:14
            Hint { width:parent.width;text:"This first installer supports erasing an entire destination disk. All existing partitions and data on the selected disk will be removed. The installation media is excluded by the system installer." }
            ScrollView {
                width:parent.width;height:200;clip:true
                Column { width:parent.width;spacing:8
                    Repeater {
                        model:InstallBackend.disks
                        delegate:Rectangle {
                            required property var modelData
                            objectName:"installerDisk_"+modelData.path
                            width:parent.width;height:82;radius:8
                            color:InstallBackend.selectedDisk.path===modelData.path?"#d9eaff":"#fafafa"
                            border.color:InstallBackend.selectedDisk.path===modelData.path?"#3f92e6":"#b7b7bc"
                            Image { x:14;y:13;width:54;height:54;source:modelData.removable?"assets/original/drive-external.png":"assets/original/drive-internal.png";fillMode:Image.PreserveAspectFit }
                            Column { x:84;y:14;width:parent.width-100;spacing:5
                                Label { width:parent.width;text:modelData.model || "Disk";font.weight:Font.DemiBold }
                                Hint { width:parent.width;text:modelData.path+" · "+(modelData.size/1000000000).toFixed(1)+" GB";color:"#585860" }
                            }
                            MouseArea { anchors.fill:parent;enabled:InstallBackend.available && !InstallBackend.busy;onClicked:InstallBackend.selectDisk(modelData.path) }
                            Accessible.role:Accessible.Button
                            Accessible.name:(modelData.model || "Disk")+", "+modelData.path
                            Accessible.onPressAction:if(InstallBackend.available && !InstallBackend.busy)InstallBackend.selectDisk(modelData.path)
                        }
                    }
                }
            }
            Row { spacing:14
                Action { text:"Refresh Disks";enabled:!InstallBackend.busy;onClicked:InstallBackend.refresh() }
                Hint { text:InstallBackend.selectedDisk.path ? "Selected: "+InstallBackend.selectedDisk.path : "Choose a destination disk.";height:28;verticalAlignment:Text.AlignVCenter }
            }
            Hint { width:parent.width;text:InstallBackend.layout.partitions ? "Existing partitions: "+InstallBackend.layout.partitions.length+". New format: GUID Partition Table, Linux ext4." : "" }
        }
        GridLayout {
            visible:window.phase === "account";x:38;y:88;width:parent.width-76
            columns:2;rowSpacing:13;columnSpacing:18
            Label { text:"Full name:";Layout.alignment:Qt.AlignRight }
            Field { id:fullName;objectName:"installerFullName";placeholderText:"Your name";Layout.fillWidth:true }
            Label { text:"Account name:";Layout.alignment:Qt.AlignRight }
            Field { id:userName;objectName:"installerUserName";placeholderText:"username";Layout.fillWidth:true }
            Label { text:"Password:";Layout.alignment:Qt.AlignRight }
            Field { id:password;objectName:"installerPassword";echoMode:TextInput.Password;Layout.fillWidth:true }
            Label { text:"Verify password:";Layout.alignment:Qt.AlignRight }
            Field { id:passwordRepeat;objectName:"installerPasswordRepeat";echoMode:TextInput.Password;Layout.fillWidth:true }
            Label { text:"Computer name:";Layout.alignment:Qt.AlignRight }
            Field { id:hostName;objectName:"installerHostName";placeholderText:"makos-computer";Layout.fillWidth:true }
            Label { text:"Time zone:";Layout.alignment:Qt.AlignRight }
            ComboBox {
                id:timeZone;objectName:"installerTimeZone";Layout.fillWidth:true;editable:true
                model:InstallBackend.timeZones
                Component.onCompleted:currentIndex=Math.max(0,InstallBackend.timeZones.indexOf("Etc/UTC"))
            }
            Hint { Layout.columnSpan:2;Layout.fillWidth:true;text:"This creates your Linux login account. Display language and keyboard layout use the live image’s defaults in this first installer." }
        }
        Column {
            visible:window.phase === "review";x:38;y:82;width:parent.width-76;spacing:14
            Row { spacing:18
                Image { width:70;height:70;source:"assets/original/drive-internal.png";fillMode:Image.PreserveAspectFit }
                Column { width:card.width-190;spacing:6
                    Label { width:parent.width;text:(InstallBackend.selectedDisk.model || "")+" · "+(InstallBackend.selectedDisk.path || "");font.pixelSize:16;font.weight:Font.DemiBold }
                    Hint { width:parent.width;text:InstallBackend.selectedDisk.size ? (InstallBackend.selectedDisk.size/1000000000).toFixed(1)+" GB · GUID Partition Table · ext4" : "" }
                    Hint { width:parent.width;text:"Account: "+(InstallBackend.review.userName || "")+" · "+(InstallBackend.review.timeZone || "") }
                }
            }
            Label { width:parent.width;text:"All data on this disk will be permanently erased. This includes every existing partition and operating system. This cannot be undone.";color:"#924200" }
            Hint { width:parent.width;text:"The system will copy the makOS live image, create your account and install startup files. Keep the computer connected to power. There is no cancel operation after installation starts." }
            CheckBox { id:eraseConsent;objectName:"installerEraseConsent";text:"I understand that this entire disk will be erased.";enabled:!InstallBackend.busy;indicator:Rectangle { x:2;anchors.verticalCenter:parent.verticalCenter;width:15;height:15;radius:3;color:eraseConsent.checked?"#1685f8":"#ffffff";border.color:eraseConsent.checked?"#5bafff":"#99999e";Text { anchors.centerIn:parent;text:eraseConsent.checked?"✓":"";font.pixelSize:12;color:"white" } }
                contentItem:Label { text:parent.text;leftPadding:25;verticalAlignment:Text.AlignVCenter } }
            Label { width:parent.width;text:"Type "+(InstallBackend.selectedDisk.path || "the device path")+" to confirm:" }
            Field { id:confirmDisk;objectName:"installerDiskConfirmation";width:parent.width;enabled:!InstallBackend.busy }
        }
        Column {
            visible:["starting","installing","complete","failed","uncertain"].indexOf(window.phase)>=0
            x:65;y:100;width:parent.width-130;spacing:25
            Image { anchors.horizontalCenter:parent.horizontalCenter;width:110;height:110;sourceSize:Qt.size(width*Screen.devicePixelRatio,height*Screen.devicePixelRatio);source:"assets/install.svg";fillMode:Image.PreserveAspectFit }
            Label { width:parent.width;text:InstallBackend.stageText;horizontalAlignment:Text.AlignHCenter;font.pixelSize:17 }
            ProgressBar { width:parent.width;visible:window.phase!=="failed" && window.phase!=="uncertain";from:0;to:1;value:InstallBackend.progress;indeterminate:window.phase==="starting" }
            Hint { width:parent.width;horizontalAlignment:Text.AlignHCenter;text:window.phase==="complete"?"You can close the installer. Restart the computer when you are ready to start using the installed system.":window.phase==="uncertain"?"The installer cannot confirm the current operation. Do not restart or remove the installation media.":window.phase==="failed"?"The system installer reported an error. The destination may contain a partial installation.":"Progress comes from the system installer. Keep the installation media connected." }
        }
        Text {
            x:30;y:parent.height-122;width:parent.width-60;height:68
            visible:InstallBackend.errorText!==""
            text:InstallBackend.errorText;color:"#924200";font.pixelSize:12;wrapMode:Text.Wrap;elide:Text.ElideRight
        }
        Rectangle { visible:window.phase!=="intro";x:24;y:parent.height-54;width:parent.width-48;height:1;color:"#c9c9ce" }
        Action {
            text:window.phase==="intro"?"Cancel":"Back"
            x:window.phase==="intro"?26:continueAction.x-width-10;y:parent.height-41
            visible:["intro","disk","account","review","failed"].indexOf(window.phase)>=0
            enabled:InstallBackend.canClose && !InstallBackend.busy
            onClicked:window.phase==="intro"?InstallBackend.close():InstallBackend.back()
        }
        Action {
            id:continueAction
            objectName:"installerContinue"
            x:window.phase==="intro"?(parent.width-width)/2:parent.width-width-26;y:parent.height-41
            text:window.phase==="review"?"Erase and Install":window.phase==="complete"?"Done":"Continue"
            primary:true;visible:["intro","disk","account","review","complete"].indexOf(window.phase)>=0
            enabled:!InstallBackend.busy && (window.phase!=="disk" || !!InstallBackend.selectedDisk.path) && (window.phase!=="review" || (InstallBackend.live && eraseConsent.checked && confirmDisk.text===InstallBackend.selectedDisk.path))
            onClicked:window.next()
        }
    }
    Popup {
        id:help;anchors.centerIn:parent;width:480;modal:true;padding:24
        background:Rectangle { color:"#f3f3f5";radius:12;border.color:"#aaaab0" }
        Column { width:parent.width;spacing:18
            Label { width:parent.width;text:"makOS Installation Help";font.pixelSize:18;font.weight:Font.DemiBold }
            Hint { width:parent.width;text:"Choose a destination disk and create your account, then review the plan. This version erases the entire selected disk. Advanced partitioning is not available. Installation requires the makOS live image and its system installer service." }
            Action { anchors.right:parent.right;text:"OK";onClicked:help.close() }
        }
    }
}
