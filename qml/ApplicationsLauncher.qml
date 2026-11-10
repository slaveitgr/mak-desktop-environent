import QtQuick
import QtQuick.Controls

FocusScope {
    id: library
    objectName: "applicationsLauncher"
    required property var host
    property string section: ""
    property alias searchText: search.text
    readonly property string viewMode: host.desktop.preference("launcher.view", "grid")
    readonly property bool searching: search.text.trim().length > 0
    readonly property bool showGrid: searching || viewMode === "grid"
    readonly property var categories: ["Productivity & Finance", "Utilities", "Social", "Entertainment", "Creativity", "Information & Reading", "Other"]
    readonly property var allApps: {
        let entries = [{id:"settings",name:"System Settings",image:"settings.png"}]
            .concat(Bridge.applicationCatalog.filter(a=>a.id!=="apps"))
            .concat(Bridge.session.applications);
        let seen = {};
        return entries.filter(a=> {
            // Own .desktop launchers are already represented by the suite catalog.
            if (a.id.startsWith("xdg:org.makos.")) return false;
            if (seen[a.id]) return false;
            seen[a.id]=true; return true;
        });
    }
    function category(a) {
        const id=a.id;
        if (["calendar","notes","reminders","contacts"].indexOf(id)>=0) return categories[0];
        if (["finder","settings","calculator","terminal","appstore"].indexOf(id)>=0) return categories[1];
        if (["messages","mail","facetime","phone"].indexOf(id)>=0) return categories[2];
        if (["music","games","chess"].indexOf(id)>=0) return categories[3];
        if (["photos","photobooth"].indexOf(id)>=0) return categories[4];
        if (["safari","maps"].indexOf(id)>=0) return categories[5];
        let c=a.categories || [];
        if (c.indexOf("Office")>=0) return categories[0];
        if (c.some(x=>["Utility","System","Settings"].indexOf(x)>=0)) return categories[1];
        if (c.indexOf("Network")>=0) return categories[2];
        if (c.some(x=>["Game","AudioVideo","Audio","Video"].indexOf(x)>=0)) return categories[3];
        if (c.indexOf("Graphics")>=0) return categories[4];
        if (c.some(x=>["Education","Science"].indexOf(x)>=0)) return categories[5];
        return categories[6];
    }
    readonly property var filteredApps: {
        let query=search.text.trim().toLowerCase();
        return allApps.filter(a=>(!section || category(a)===section) && (a.name+" "+(a.description||"")).toLowerCase().includes(query))
            .sort((a,b)=>{
                if(query){
                    let recent=host.desktop.recentApps || [];
                    let ai=recent.indexOf(a.id),bi=recent.indexOf(b.id);
                    if(ai>=0||bi>=0){if(ai<0)return 1;if(bi<0)return -1;if(ai!==bi)return ai-bi;}
                    let ap=a.name.toLowerCase().startsWith(query),bp=b.name.toLowerCase().startsWith(query);
                    if(ap!==bp)return ap?-1:1;
                }
                return a.name.localeCompare(b.name);
            });
    }
    readonly property var recentApps: {
        if (section || search.text.trim()) return [];
        let recent=host.desktop.recentApps || [];
        return recent.map(id=>allApps.find(a=>a.id===id)).filter(a=>!!a).slice(0,grid.columns);
    }
    readonly property int selectedIndex: grid.currentIndex
    readonly property string selectedApp: selectedIndex>=0 && selectedIndex<filteredApps.length ? filteredApps[selectedIndex].id : ""
    function chooseSection(name) { section=section===name ? "" : name; }
    function focusSearch(clear) { if(clear){search.clear();section="";} search.forceActiveFocus();search.selectAll(); }
    function launch(id) { host.launchApp(id); }
    function activateSelection() { if(selectedApp)launch(selectedApp); }
    function moveSelection(offset) {
        if(!filteredApps.length)return;
        let target=showGrid?grid:list;
        grid.currentIndex=Math.max(0,Math.min(filteredApps.length-1,grid.currentIndex+offset));
        target.currentIndex=grid.currentIndex;target.positionViewAtIndex(grid.currentIndex,ListView.Contain);target.forceActiveFocus();
    }
    onFilteredAppsChanged: { grid.currentIndex=filteredApps.length?0:-1;grid.positionViewAtBeginning(); }
    Keys.onEscapePressed: host.dismiss()

    ToolButton {
        id: backButton
        objectName: "appsToSpotlight"
        x: 13; y: 9; width: 36; height: 38
        hoverEnabled:true
        Accessible.name: "Back to Spotlight"
        onClicked: host.showMode("spotlight")
        background: Rectangle { radius:10;color:backButton.hovered?(host.dark?"#18ffffff":"#12000000"):"transparent" }
        contentItem: Icon { name:backButton.hovered?"back":"applications"; color:host.muted;width:24;height:24 }
    }
    TextField {
        id: search
        objectName:"appsSearch"
        x: 58; y: 6; width: parent.width-112; height:44
        placeholderText:"Applications"
        color:host.ink;placeholderTextColor:host.muted
        font.pixelSize:25;font.weight:Font.Medium
        leftPadding:0;rightPadding:0
        background:Item{}
        Accessible.name:"Search Applications"
        Keys.onReturnPressed:library.activateSelection()
        Keys.onEnterPressed:library.activateSelection()
        Keys.onDownPressed:library.moveSelection(0)
        Keys.onEscapePressed:host.dismiss()
    }
    ToolButton {
        id: more
        objectName:"appsMore"
        x:parent.width-45;y:11;width:30;height:32
        Accessible.name:"Application display options"
        onClicked:options.open()
        contentItem:Item {
            Rectangle { anchors.centerIn:parent;width:19;height:19;radius:9.5;color:"transparent";border.color:host.muted;border.width:1.5 }
            Icon { anchors.centerIn:parent;width:13;height:13;name:"more";color:host.muted }
        }
        background:Item{}
        GlassMenu {
            id:options
            objectName:"appsViewOptions"
            x:parent.width-width;y:28;width:128
            dark:host.dark;backdrop:host.backdrop
            reducedMotion:host.desktop.reduceMotion;reducedTransparency:host.desktop.reduceTransparency
            rows:[{label:"View content as",enabled:false},{label:"Grid",command:"grid",checked:library.viewMode==="grid"},{label:"List",command:"list",checked:library.viewMode==="list"}]
            onChosen:function(command){Bridge.suite.setPreference("launcher.view",command);}
        }
    }
    Rectangle { x:20;y:56;width:parent.width-40;height:1;color:host.dark?"#24ffffff":"#22000000" }
    Flickable {
        id: categoryStrip
        objectName:"appsCategories"
        visible:!library.searching
        x:20;y:66;width:parent.width-40;height:27
        clip:true;contentWidth:categoryRow.width;contentHeight:height
        flickableDirection:Flickable.HorizontalFlick;boundsBehavior:Flickable.StopAtBounds
        Row {
            id:categoryRow;spacing:8
            Repeater {
                model:library.categories
                delegate:Button {
                    id:chip
                    required property string modelData
                    height:24;width:label.implicitWidth+16;text:modelData
                    Accessible.name:text;Accessible.selected:library.section===text
                    onClicked:library.chooseSection(text)
                    contentItem:Text { id:label;text:chip.text;color:library.section===chip.text?"white":host.muted;font.pixelSize:15;font.weight:Font.DemiBold;verticalAlignment:Text.AlignVCenter;horizontalAlignment:Text.AlignHCenter }
                    background:Rectangle { radius:8;color:library.section===chip.text?"#397acf":host.dark?"#18ffffff":"#14000000" }
                }
            }
        }
    }
    Rectangle { x:20;y:101;width:parent.width-40;height:1;visible:!library.searching;color:host.dark?"#24ffffff":"#22000000" }
    Component {
        id:recentHeader
        Item {
            width:grid.width;height:library.recentApps.length?116:0
            visible:height>0
            Row {
                Repeater {
                    model:library.recentApps
                    delegate:LauncherAppTile {
                        required property var modelData
                        width:grid.cellWidth;height:113;entry:modelData;host:library.host
                        onLaunch:function(application){library.launch(application);}
                    }
                }
            }
            Rectangle { anchors.bottom:parent.bottom;width:parent.width;height:1;color:host.dark?"#24ffffff":"#22000000" }
        }
    }
    GridView {
        id:grid
        objectName:"appsGrid"
        x:20;y:library.searching?57:102;width:parent.width-40;height:parent.height-y-2
        visible:library.showGrid
        clip:true;model:library.filteredApps
        readonly property int columns:Math.max(1,Math.min(7,Math.floor(width/108)))
        cellWidth:width/columns;cellHeight:102
        boundsBehavior:Flickable.StopAtBounds
        keyNavigationEnabled:false;activeFocusOnTab:true
        Accessible.name:"Applications";Accessible.role:Accessible.List
        header:recentHeader
        delegate:LauncherAppTile {
            required property var modelData
            required property int index
            width:grid.cellWidth;height:grid.cellHeight
            entry:modelData;host:library.host;selected:grid.activeFocus&&grid.currentIndex===index
            onLaunch:function(application){grid.currentIndex=index;library.launch(application);}
        }
        Keys.onPressed:event=>{
            if(event.key===Qt.Key_Right)library.moveSelection(1);
            else if(event.key===Qt.Key_Left)library.moveSelection(-1);
            else if(event.key===Qt.Key_Down)library.moveSelection(columns);
            else if(event.key===Qt.Key_Up){if(currentIndex<columns)library.focusSearch(false);else library.moveSelection(-columns);}
            else if(event.key===Qt.Key_Home)library.moveSelection(-count);
            else if(event.key===Qt.Key_End)library.moveSelection(count);
            else if([Qt.Key_Return,Qt.Key_Enter,Qt.Key_Space].indexOf(event.key)>=0)library.activateSelection();
            else if(event.key===Qt.Key_Escape)host.dismiss();
            else if(event.text.length&&!(event.modifiers&(Qt.ControlModifier|Qt.MetaModifier|Qt.AltModifier))){library.focusSearch(false);search.text=event.text;search.cursorPosition=search.text.length;}
            else{event.accepted=false;return;}
            event.accepted=true;
        }
        ScrollBar.vertical:ScrollBar { x:grid.width+6; width:10;policy:host.desktop.alwaysShowScrollbars?ScrollBar.AlwaysOn:ScrollBar.AsNeeded }
        Text { anchors.centerIn:parent;visible:grid.count===0;text:"No Applications Found";color:host.muted;font.pixelSize:17 }
    }
    ListView {
        id:list;objectName:"appsList"
        x:20;y:102;width:parent.width-40;height:parent.height-y-2
        visible:!library.showGrid;clip:true;model:library.filteredApps
        boundsBehavior:Flickable.StopAtBounds
        header:recentHeader
        delegate:ItemDelegate {
            id:row;required property var modelData;required property int index
            width:list.width;height:57;hoverEnabled:true
            Accessible.name:"Open "+modelData.name
            onClicked:library.launch(modelData.id)
            background:Rectangle{radius:8;color:row.hovered||(list.activeFocus&&list.currentIndex===row.index)?"#18ffffff":"transparent"}
            Image{x:-3;y:9;width:38;height:38;source:row.modelData.iconUrl||Bridge.assetRoot+row.modelData.image;fillMode:Image.PreserveAspectFit}
            Text{x:51;anchors.verticalCenter:parent.verticalCenter;width:parent.width-60;text:row.modelData.name;color:host.ink;font.pixelSize:16;font.weight:Font.DemiBold;elide:Text.ElideRight}
        }
        Keys.onDownPressed:library.moveSelection(1)
        Keys.onUpPressed:if(currentIndex===0)library.focusSearch(false);else library.moveSelection(-1)
        Keys.onReturnPressed:library.activateSelection()
        Keys.onEscapePressed:host.dismiss()
        ScrollBar.vertical:ScrollBar{x:list.width+6;width:10;policy:host.desktop.alwaysShowScrollbars?ScrollBar.AlwaysOn:ScrollBar.AsNeeded}
    }
}
