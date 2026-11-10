import QtQuick
import QtQuick.Controls

FocusScope {
    id:view
    objectName:"spotlightView"
    required property var host
    required property var applications
    readonly property string mode:host.mode
    readonly property bool home:mode==="spotlight"
    readonly property var backend:Bridge.spotlight
    readonly property string heading:home?"Spotlight Search":mode==="files"?"Files":mode==="actions"?"Actions":"Clipboard"
    readonly property string symbol:home?"search":mode==="files"?"folder":mode==="actions"?"group":"document"
    property alias query:search.text
    property string fileCategory:""
    readonly property var scopes:[{id:"apps",icon:"applications",name:"Applications"},{id:"files",icon:"folder",name:"Files"},{id:"actions",icon:"group",name:"Actions"},{id:"clipboard",icon:"document",name:"Clipboard"}]
    readonly property var actions:[
        {id:"settings",name:"Settings…",app:"System Settings",image:"settings.png"},
        {id:"messages",name:"Send Message",app:"Messages",image:"messages.png"},
        {id:"timer",name:"Start Timer",app:"Clock",image:"calendar.png"},
        {id:"notes",name:"Create Note",app:"Notes",image:"notes.png"},
        {id:"mail",name:"Send Email",app:"Mail",image:"mail.png"},
        {id:"calendar",name:"New Event",app:"Calendar",image:"calendar.png"}
    ]
    readonly property var results:{
        let q=query.trim().toLowerCase();
        if(mode==="actions")return actions.filter(a=>(a.name+" "+a.app).toLowerCase().includes(q));
        if(mode==="clipboard")return backend.clipboardItems.filter(t=>t.toLowerCase().includes(q)).map(t=>({name:t,app:"Clipboard",value:t}));
        if(!q)return [];
        return applications.filter(a=>a.name.toLowerCase().includes(q)).map(a=>Object.assign({},a,{type:"app",app:"Application"}))
            .concat(backend.files.map(f=>Object.assign({},f,{type:"file",app:f.kind})));
    }
    readonly property var files:backend.files.filter(f=>!fileCategory||f.kind===fileCategory)
    function focusSearch(clear){if(clear)search.clear();search.forceActiveFocus();search.selectAll();if(mode==="files")backend.search(search.text);}
    function activate(row){
        if(mode==="actions")host.runAction(row.id);
        else if(mode==="clipboard"){Bridge.copyText(row.value);host.dismiss();}
        else if(row.type==="app")host.launchApp(row.id);
        else host.openFile(row.path);
    }
    function move(offset){if(results.length){resultList.currentIndex=Math.max(0,Math.min(results.length-1,resultList.currentIndex+offset));resultList.positionViewAtIndex(resultList.currentIndex,ListView.Contain);resultList.forceActiveFocus();}}
    onModeChanged:{fileCategory="";focusSearch(true);}
    onQueryChanged:if(mode==="files"||home)backend.search(query)
    Keys.onEscapePressed:host.dismiss()
    Item {
        width:view.home?parent.width-256:parent.width;height:56
        Glass {
            anchors.fill:parent;visible:view.home
            backdrop:host.backdrop;sampleX:host.panelX;sampleY:host.panelY
            dark:host.dark;corner:28;tint:host.dark?0.68:0.72;frost:0.98
            reducedTransparency:host.desktop.reduceTransparency
        }
        ToolButton {
            id:back
            objectName:"spotlightBack"
            x:12;y:10;width:38;height:36
            hoverEnabled:true
            Accessible.name:view.home?"Spotlight":"Back to Spotlight"
            onClicked:if(!view.home)host.showMode("spotlight")
            contentItem:Icon{name:!view.home&&back.hovered?"back":view.symbol;color:host.muted}
            background:Item{}
        }
        TextField {
            id:search
            objectName:"spotlightSearch"
            x:58;y:6;height:44;width:parent.width-x-(view.home?16:48)
            placeholderText:view.heading;placeholderTextColor:host.muted;color:host.ink
            font.pixelSize:25;font.weight:Font.Medium
            leftPadding:0;rightPadding:0;background:Item{}
            Accessible.name:view.heading
            Keys.onReturnPressed:if(view.results.length)view.activate(view.results[Math.max(0,resultList.currentIndex)])
            Keys.onEnterPressed:if(view.results.length)view.activate(view.results[Math.max(0,resultList.currentIndex)])
            Keys.onDownPressed:view.move(0)
            Keys.onEscapePressed:host.dismiss()
        }
        ToolButton {
            x:parent.width-44;y:12;width:28;height:30;visible:view.mode==="files"
            Accessible.name:"File search options"
            onClicked:host.desktop.openSettings("Spotlight")
            contentItem:Icon{name:"more";color:host.muted}
            background:Item{}
        }
    }
    Row {
        visible:view.home;x:parent.width-246;y:0;spacing:10
        Repeater {
            model:view.scopes
            delegate:AbstractButton {
                id:scope
                required property var modelData
                width:54;height:56;hoverEnabled:true
                objectName:"spotlightScope_"+modelData.id
                Accessible.name:modelData.name
                onClicked:host.showMode(modelData.id)
                background:Glass {
                    backdrop:host.backdrop;sampleX:host.panelX+scope.parent.x+scope.x;sampleY:host.panelY
                    dark:host.dark;corner:28;tint:host.dark?0.68:0.72;frost:0.98
                    reducedTransparency:host.desktop.reduceTransparency
                }
                contentItem:Item { Icon{anchors.centerIn:parent;width:27;height:27;name:scope.modelData.icon;color:host.muted} }
                ToolTip.visible:hovered;ToolTip.text:modelData.name;ToolTip.delay:400
            }
        }
    }
    Rectangle { x:20;y:56;width:parent.width-40;height:1;visible:!view.home;color:host.dark?"#24ffffff":"#22000000" }
    Flickable {
        visible:view.mode==="files";x:20;y:66;width:parent.width-40;height:27
        contentWidth:filters.width;contentHeight:height;clip:true
        boundsBehavior:Flickable.StopAtBounds;flickableDirection:Flickable.HorizontalFlick
        Row { id:filters;spacing:8
            Repeater {model:["Images","Text","PDF","Archives","Other"]
                delegate:Button {
                    id:filter;required property string modelData
                    text:modelData;height:24;width:Math.max(90,label.implicitWidth+24)
                    onClicked:view.fileCategory=view.fileCategory===text?"":text
                    contentItem:Text{id:label;text:filter.text;color:host.muted;font.pixelSize:15;font.weight:Font.DemiBold;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter}
                    background:Rectangle{radius:8;color:view.fileCategory===filter.text?"#397acf":host.dark?"#18ffffff":"#14000000"}
                }
            }
        }
    }
    Rectangle{x:20;y:101;width:parent.width-40;height:1;visible:view.mode==="files";color:host.dark?"#24ffffff":"#22000000"}
    GridView {
        id:fileGrid;objectName:"spotlightFiles"
        x:20;y:112;width:parent.width-40;height:parent.height-y-8
        visible:view.mode==="files";clip:true;model:view.files
        cellWidth:width/Math.max(1,Math.floor(width/115));cellHeight:128
        boundsBehavior:Flickable.StopAtBounds
        header:Text{width:fileGrid.width;height:34;text:view.query?"Results":"Recents";color:host.ink;font.pixelSize:13;font.weight:Font.Bold}
        delegate:AbstractButton{
            id:file;required property var modelData
            width:fileGrid.cellWidth;height:128;hoverEnabled:true
            Accessible.name:modelData.name
            onClicked:host.openFile(modelData.path)
            background:Rectangle{radius:10;color:file.hovered?"#18ffffff":"transparent"}
            Image{anchors.horizontalCenter:parent.horizontalCenter;y:12;width:70;height:66;fillMode:Image.PreserveAspectFit;source:file.modelData.image||Bridge.assetRoot+"document.png"}
            Text{x:4;y:82;width:parent.width-8;height:39;text:file.modelData.name;color:host.ink;font.pixelSize:13;font.weight:Font.Medium;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter}
        }
        ScrollBar.vertical:ScrollBar{width:10;x:fileGrid.width+6}
        Text{anchors.centerIn:parent;visible:!fileGrid.count&&!backend.busy;text:"No Files Found";color:host.muted}
    }
    Text{x:20;anchors.bottom:parent.bottom;anchors.bottomMargin:3;visible:view.mode==="files"&&backend.limited;text:"More files may exist outside these search results.";color:host.muted;font.pixelSize:11}
    Column {
        id:clipboardConsent
        objectName:"spotlightClipboardConsent"
        visible:view.mode==="clipboard"&&!backend.clipboardEnabled
        width:parent.width-120;anchors.centerIn:parent;spacing:10
        Text{width:parent.width;text:"Allow search results from Clipboard";color:host.ink;font.pixelSize:17;font.weight:Font.Bold;horizontalAlignment:Text.AlignHCenter}
        Text{width:parent.width;text:"Spotlight can search and display text you’ve copied to your clipboard. Personal and sensitive information may appear in search results. History stays in memory for this session.";color:host.muted;font.pixelSize:13;wrapMode:Text.Wrap;horizontalAlignment:Text.AlignHCenter}
        Row{anchors.horizontalCenter:parent.horizontalCenter;spacing:8
            Button{text:"Not Now";width:110;height:28;onClicked:host.showMode("spotlight")}
            Button{objectName:"spotlightAllowClipboard";text:"Allow";width:110;height:28;onClicked:backend.setClipboardEnabled(true)}
        }
    }
    ListView {
        id:resultList;objectName:"spotlightResults"
        x:20;y:view.home?72:66;width:parent.width-40;height:parent.height-y-10
        visible:view.home?view.query.trim().length>0:view.mode==="actions"||(view.mode==="clipboard"&&backend.clipboardEnabled)
        model:view.results;clip:true;currentIndex:0
        boundsBehavior:Flickable.StopAtBounds
        header:Item{width:resultList.width;height:view.mode==="actions"?25:0
            Text{text:"Suggestions";visible:view.mode==="actions";color:host.ink;font.pixelSize:13;font.weight:Font.Bold}
            Rectangle{anchors.bottom:parent.bottom;width:parent.width;height:1;color:host.dark?"#24ffffff":"#22000000"}
        }
        delegate:ItemDelegate {
            id:result;required property var modelData;required property int index
            width:resultList.width;height:57
            Accessible.name:modelData.name
            onClicked:view.activate(modelData)
            background:Rectangle{radius:8;color:result.hovered||(resultList.activeFocus&&resultList.currentIndex===result.index)?"#22ffffff":"transparent"}
            Image{x:1;y:12;width:30;height:30;source:result.modelData.iconUrl||Bridge.assetRoot+(result.modelData.image||"document.png");fillMode:Image.PreserveAspectFit}
            Text{x:51;y:7;width:parent.width-60;height:22;text:result.modelData.name;elide:Text.ElideRight;color:host.ink;font.pixelSize:16;font.weight:Font.DemiBold}
            Text{x:51;y:29;width:parent.width-60;text:result.modelData.app||"";color:host.muted;font.pixelSize:15}
        }
        Keys.onDownPressed:view.move(1)
        Keys.onUpPressed:if(currentIndex===0)search.forceActiveFocus();else view.move(-1)
        Keys.onReturnPressed:if(count)view.activate(view.results[currentIndex])
        Keys.onEscapePressed:host.dismiss()
        ScrollBar.vertical:ScrollBar{width:10;x:resultList.width+6}
    }
}
