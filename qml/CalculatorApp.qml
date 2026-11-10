import QtQuick
import QtQuick.Controls

Item {
    id: calculator
    required property var host
    property string expression: "0"
    property string previous: ""
    property bool resultShown: false
    property string mode: "basic"
    property string angleMode: "degrees"
    property bool secondary: false
    property bool historyVisible: false
    property var history: []
    property var historyUndo: []
    property string repeatOperator: ""
    property string repeatOperand: ""
    property string memory: "0"
    property string notice: ""
    property bool initialized: false
    readonly property int historyWidth: historyVisible ? 226 : 0
    readonly property var basicKeys: ["⌫", "AC", "%", "÷", "7", "8", "9", "×", "4", "5", "6", "−", "1", "2", "3", "+", "+/−", "0", ".", "="]
    readonly property var scientificKeys: ["(", ")", "mc", "m+", "m−", "mr", "2nd", "x²", "x³", "xʸ", secondary ? "2ˣ" : "eˣ", secondary ? "log₂" : "10ˣ", "1/x", "√x", "∛x", "y√x", "ln", "log₁₀", secondary ? "sin⁻¹" : "sin", secondary ? "cos⁻¹" : "cos", secondary ? "tan⁻¹" : "tan", "e", "EE", "x!", angleMode === "degrees" ? "Rad" : "Deg", secondary ? "sinh⁻¹" : "sinh", secondary ? "cosh⁻¹" : "cosh", secondary ? "tanh⁻¹" : "tanh", "π", "Rand"]
    readonly property var keys: {
        if (mode === "basic")
            return basicKeys;
        let result = [];
        for (let row = 0; row < 5; row++)
            result = result.concat(scientificKeys.slice(row * 6, row * 6 + 6), basicKeys.slice(row * 4, row * 4 + 4));
        return result;
    }
    Component.onCompleted: {
        try {
            let saved = JSON.parse(Bridge.suite.preference("calculator.history", "[]"));
            history = Array.isArray(saved) ? saved.filter(row => typeof row.expression === "string" && typeof row.result === "string").slice(0, 50) : [];
        } catch (e) {
            history = [];
        }
        memory = Bridge.suite.preference("calculator.memory", "0");
        angleMode = Bridge.suite.preference("calculator.angle", "degrees") === "radians" ? "radians" : "degrees";
        mode = Bridge.suite.preference("calculator.mode", "basic") === "scientific" ? "scientific" : "basic";
        initialized = true;
        Qt.callLater(updateGeometry);
    }
    function flush() {
        storeHistory();
    }
    function storeHistory() {
        Bridge.suite.setPreference("calculator.history", JSON.stringify(history.slice(0, 50)));
    }
    function evaluateValue(value) {
        return mode === "scientific" ? Bridge.suite.evaluateScientific(value, angleMode) : Bridge.suite.evaluate(value);
    }
    function updateGeometry() {
        if (!initialized)
            return;
        let available = Math.max(300, host.desktop.width - 32);
        let sideWidth = historyVisible ? 226 : 0;
        host.minimumWindowWidth = Math.min(available, (mode === "scientific" ? 610 : 300) + sideWidth);
        host.minimumWindowHeight = 480;
        if (host.isFullscreen)
            return;
        let width = Math.min(available, (mode === "scientific" ? 760 : 340) + sideWidth);
        let center = host.x + host.width / 2;
        host.width = width;
        host.x = Math.max(12, Math.min(host.desktop.width - width - 12, center - width / 2));
    }
    function setMode(value) {
        if (value !== "basic" && value !== "scientific")
            return;
        mode = value;
        Bridge.suite.setPreference("calculator.mode", value);
        updateGeometry();
        forceActiveFocus();
    }
    function setAngle(value) {
        angleMode = value === "radians" ? "radians" : "degrees";
        Bridge.suite.setPreference("calculator.angle", angleMode);
    }
    onHistoryVisibleChanged: if (initialized)
        updateGeometry()
    function balance(value) {
        let count = 0;
        for (let i = 0; i < value.length; i++)
            count += value[i] === "(" ? 1 : value[i] === ")" ? -1 : 0;
        return count;
    }
    function completed(value) {
        let missing = balance(value);
        return missing > 0 && missing <= 40 ? value + ")".repeat(missing) : value;
    }
    function operand() {
        let value = expression;
        if (!value || value === "Error" || /[+−×÷^,(]$/.test(value))
            return null;
        let start = value.length;
        if (value[value.length - 1] === ")") {
            let depth = 0;
            for (let i = value.length - 1; i >= 0; i--) {
                depth += value[i] === ")" ? 1 : value[i] === "(" ? -1 : 0;
                if (depth === 0) {
                    start = i;
                    break;
                }
            }
            let functionName = value.slice(0, start).match(/[a-zA-Z]+$/);
            if (functionName)
                start = functionName.index;
        } else {
            let match = value.match(/(?:\d+\.?\d*|\.\d+)(?:[eE][+−-]?\d+)?$|(?:pi|e)$/);
            if (!match)
                return null;
            start = match.index;
        }
        if (start > 0 && /[−-]/.test(value[start - 1]) && (start === 1 || /[+−×÷^,(\-]/.test(value[start - 2])))
            start--;
        return {
            start: start,
            prefix: value.slice(0, start),
            value: value.slice(start)
        };
    }
    function clearRepeat() {
        repeatOperator = "";
        repeatOperand = "";
    }
    function findRepeat(value) {
        let depth = 0;
        for (let i = value.length - 1; i > 0; i--) {
            let c = value[i];
            if (c === ")")
                depth++;
            else if (c === "(")
                depth--;
            else if (depth === 0 && /[+−×÷^]/.test(c)) {
                if (/[+−×÷^,(eE]/.test(value[i - 1]))
                    continue;
                let right = evaluateValue(value.slice(i + 1));
                if (right.ok) {
                    repeatOperator = c;
                    repeatOperand = right.value;
                    return;
                }
            }
        }
        clearRepeat();
    }
    function beginEntry() {
        if (resultShown || expression === "Error") {
            expression = "0";
            previous = "";
            clearRepeat();
        }
        resultShown = false;
    }
    function insertConstant(value) {
        beginEntry();
        if (expression === "0")
            expression = value;
        else if (/[\d.)]$/.test(expression) || /(?:pi|e)$/.test(expression))
            expression += "×" + value;
        else
            expression += value;
    }
    function wrapFunction(name) {
        if (expression === "Error")
            expression = "0";
        let last = operand();
        if (expression === "0" && !resultShown)
            expression = name + "(";
        else if (last)
            expression = last.prefix + name + "(" + last.value + ")";
        else
            expression += name + "(";
        resultShown = false;
        clearRepeat();
    }
    function percent() {
        let last = operand();
        if (!last)
            return;
        let source = "(" + last.value + ")÷100";
        if (/[+−]$/.test(last.prefix)) {
            let base = evaluateValue(completed(last.prefix.slice(0, -1)));
            if (base.ok)
                source = "(" + base.value + ")×" + source;
        }
        let result = evaluateValue(source);
        if (result.ok) {
            expression = last.prefix + result.value;
            resultShown = false;
            clearRepeat();
        }
    }
    function negate() {
        if (expression === "Error")
            expression = "0";
        let last = operand();
        if (!last)
            expression += "−0";
        else
            expression = last.prefix + (/^[−-]/.test(last.value) ? last.value.slice(1) : "−" + last.value);
        resultShown = false;
        clearRepeat();
    }
    function equals() {
        if (expression === "Error")
            return;
        let source;
        if (resultShown && repeatOperator)
            source = "(" + expression + ")" + repeatOperator + "(" + repeatOperand + ")";
        else {
            source = completed(expression);
            findRepeat(source);
        }
        let result = evaluateValue(source);
        previous = source;
        if (result.ok) {
            expression = result.value;
            history = [
                {
                    expression: source,
                    result: result.value
                }
            ].concat(history).slice(0, 50);
            storeHistory();
        } else {
            expression = "Error";
            clearRepeat();
        }
        resultShown = true;
    }
    function memoryAction(key) {
        if (key === "mc")
            memory = "0";
        else if (key === "mr") {
            insertConstant(memory);
            return;
        } else {
            let current = evaluateValue(completed(expression));
            if (!current.ok)
                return;
            let value = Bridge.suite.evaluate("(" + memory + ")" + (key === "m+" ? "+" : "−") + "(" + current.value + ")");
            if (!value.ok)
                return;
            memory = value.value;
        }
        Bridge.suite.setPreference("calculator.memory", memory);
    }
    function press(key) {
        notice = "";
        if (key === "AC") {
            expression = "0";
            previous = "";
            resultShown = false;
            clearRepeat();
            return;
        }
        if (key === "⌫") {
            expression = expression === "Error" || expression.length <= 1 ? "0" : expression.slice(0, -1);
            previous = "";
            resultShown = false;
            clearRepeat();
            return;
        }
        if (key === "=") {
            equals();
            return;
        }
        if (key === "+/−") {
            negate();
            return;
        }
        if (key === "%") {
            percent();
            return;
        }
        if (["mc", "m+", "m−", "mr"].indexOf(key) >= 0) {
            memoryAction(key);
            return;
        }
        if (key === "2nd") {
            secondary = !secondary;
            return;
        }
        if (key === "Rad" || key === "Deg") {
            setAngle(key === "Rad" ? "radians" : "degrees");
            return;
        }
        if (key === "π" || key === "e") {
            insertConstant(key === "π" ? "pi" : "e");
            return;
        }
        if (key === "Rand") {
            expression = Math.random().toPrecision(15);
            resultShown = true;
            clearRepeat();
            return;
        }
        let functionNames = {
            "√x": "sqrt",
            "∛x": "cbrt",
            "ln": "ln",
            "log₁₀": "log10",
            "log₂": "log2",
            "sin": "sin",
            "cos": "cos",
            "tan": "tan",
            "sin⁻¹": "asin",
            "cos⁻¹": "acos",
            "tan⁻¹": "atan",
            "sinh": "sinh",
            "cosh": "cosh",
            "tanh": "tanh",
            "sinh⁻¹": "asinh",
            "cosh⁻¹": "acosh",
            "tanh⁻¹": "atanh",
            "x!": "factorial"
        };
        if (functionNames[key]) {
            wrapFunction(functionNames[key]);
            return;
        }
        if (["x²", "x³", "1/x", "eˣ", "10ˣ", "2ˣ", "y√x"].indexOf(key) >= 0) {
            let last = operand();
            if (!last)
                return;
            let value = "(" + last.value + ")";
            let replacement = key === "x²" ? value + "^2" : key === "x³" ? value + "^3" : key === "1/x" ? "(1÷" + value + ")" : key === "eˣ" ? "exp(" + last.value + ")" : key === "10ˣ" ? "10^" + value : key === "2ˣ" ? "2^" + value : "root(" + last.value + ",";
            expression = last.prefix + replacement;
            resultShown = false;
            clearRepeat();
            return;
        }
        if (key === "EE") {
            let last = operand();
            if (last && /^[-−]?\d*\.?\d+$/.test(last.value)) {
                expression += "e";
                resultShown = false;
                clearRepeat();
            }
            return;
        }
        if (key === "xʸ")
            key = "^";
        if (expression.length >= 480)
            return;
        let isOperator = ["+", "−", "×", "÷", "^"].indexOf(key) >= 0;
        if (isOperator) {
            if (expression === "Error")
                expression = "0";
            if (/[eE]$/.test(expression) && (key === "−" || key === "+"))
                expression += key;
            else if (/[×÷^]$/.test(expression) && key === "−")
                expression += key;
            else if (/[(,]$/.test(expression)) {
                if (key === "−")
                    expression += key;
            } else
                expression = expression.replace(/[+−×÷^]+$/, "") + key;
            resultShown = false;
            clearRepeat();
            return;
        }
        beginEntry();
        if (key === "(") {
            if (expression === "0")
                expression = "(";
            else
                expression += /[\d.)]$/.test(expression) || /(?:pi|e)$/.test(expression) ? "×(" : "(";
            return;
        }
        if (key === ")") {
            if (balance(expression) > 0 && !/[+−×÷^,(]$/.test(expression))
                expression += ")";
            return;
        }
        if (key === ".") {
            let last = expression.match(/(?:\d+\.?\d*|\.\d+)(?:[eE][+−-]?\d*)?$/);
            if (last && (last[0].indexOf(".") >= 0 || /[eE]/.test(last[0])))
                return;
            if (/[)a-z]$/.test(expression))
                expression += "×0.";
            else
                expression += /[+−×÷^,(]$/.test(expression) ? "0." : ".";
            return;
        }
        if (/^[0-9]$/.test(key)) {
            if (/[)]$/.test(expression) || /(?:pi|e)$/.test(expression) && !/\d[eE]$/.test(expression))
                expression += "×";
            if (expression === "0")
                expression = key;
            else if (/(?:^|[+−×÷^,(])0$/.test(expression))
                expression = expression.slice(0, -1) + key;
            else
                expression += key;
        }
    }
    function rawInput(text) {
        if (mode !== "scientific" || !/^[a-zA-Z,]$/.test(text))
            return false;
        beginEntry();
        expression = expression === "0" ? text.toLowerCase() : expression + text.toLowerCase();
        return true;
    }
    function recall(row) {
        previous = row.expression;
        expression = row.result;
        resultShown = true;
        findRepeat(row.expression);
        forceActiveFocus();
    }
    function command(name) {
        if (name === "copy" || name === "copyResult")
            Bridge.copyText(expression);
        else if (name === "copyExpression")
            Bridge.copyText(previous || expression);
        else if (name === "new" || name === "clear")
            press("AC");
        else if (name === "undo")
            press("⌫");
        else if (name === "history")
            historyVisible = !historyVisible;
        else if (name.indexOf("mode:") === 0)
            setMode(name.slice(5));
        else if (name.indexOf("angle:") === 0)
            setAngle(name.slice(6));
    }
    focus: host.active
    Keys.onPressed: function (event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.AltModifier))
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.text === "=")
            press("=");
        else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)
            press("⌫");
        else if (event.key === Qt.Key_Escape)
            press("AC");
        else if (event.text === "!" && mode === "scientific")
            press("x!");
        else if (/^[0-9.+\-*/%^()]$/.test(event.text))
            press(event.text.replace("-", "−").replace("*", "×").replace("/", "÷"));
        else if (!rawInput(event.text))
            return;
        event.accepted = true;
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: 20
        color: host.dark ? "#222729" : "#ededee"
    }
    Rectangle {
        visible: calculator.historyVisible
        x: 8
        y: 7
        width: 214
        height: parent.height - 14
        radius: 16
        color: host.dark ? "#293034" : "#f7f7f8"
        Text {
            x: 16
            y: 16
            text: "History"
            color: host.ink
            font.pixelSize: 19
            font.weight: Font.DemiBold
        }
        ToolButton {
            x: parent.width - 68
            y: 8
            width: 61
            height: 32
            text: calculator.historyUndo.length && !calculator.history.length ? "Undo" : "Clear"
            enabled: calculator.history.length > 0 || calculator.historyUndo.length > 0
            onClicked: {
                if (!calculator.history.length && calculator.historyUndo.length) {
                    calculator.history = calculator.historyUndo;
                    calculator.historyUndo = [];
                } else {
                    calculator.historyUndo = calculator.history.slice();
                    calculator.history = [];
                }
                calculator.storeHistory();
            }
        }
        ListView {
            id: historyList
            x: 10
            y: 52
            width: parent.width - 20
            height: parent.height - 62
            clip: true
            spacing: 5
            model: calculator.history
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }
            delegate: Rectangle {
                id: historyRow
                required property var modelData
                width: historyList.width
                height: 83
                radius: 10
                color: historyMouse.containsMouse ? (host.dark ? "#3c464d" : "#e9edf0") : "transparent"
                Text {
                    x: 9
                    y: 12
                    width: parent.width - 37
                    text: historyRow.modelData.expression + " ="
                    color: host.muted
                    font.pixelSize: 12
                    elide: Text.ElideLeft
                    horizontalAlignment: Text.AlignRight
                }
                Text {
                    x: 9
                    y: 36
                    width: parent.width - 18
                    text: historyRow.modelData.result
                    color: host.ink
                    font.pixelSize: 23
                    elide: Text.ElideLeft
                    horizontalAlignment: Text.AlignRight
                }
                MouseArea {
                    id: historyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    Accessible.role: Accessible.Button
                    Accessible.name: historyRow.modelData.expression + " equals " + historyRow.modelData.result
                    onClicked: calculator.recall(historyRow.modelData)
                    Accessible.onPressAction: calculator.recall(historyRow.modelData)
                }
                ToolButton {
                    anchors.right: parent.right
                    y: 4
                    width: 28
                    height: 28
                    text: "⋯"
                    Accessible.name: "History Actions"
                    onClicked: historyMenu.open()
                }
                Menu {
                    id: historyMenu
                    x: Math.max(0, historyRow.width - width)
                    y: 30
                    MenuItem {
                        text: "Copy Expression"
                        onTriggered: Bridge.copyText(historyRow.modelData.expression)
                    }
                    MenuItem {
                        text: "Copy Result"
                        onTriggered: Bridge.copyText(historyRow.modelData.result)
                    }
                    MenuItem {
                        text: "Use Result"
                        onTriggered: calculator.recall(historyRow.modelData)
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: calculator.history.length === 0
                text: "No Calculations"
                color: host.muted
                font.pixelSize: 13
            }
        }
    }
    Item {
        id: displayPane
        x: calculator.historyWidth
        width: parent.width - x
        height: parent.height
        ToolButton {
            x: 13
            y: 0
            width: 32
            height: 32
            Accessible.name: calculator.historyVisible ? "Hide History" : "Show History"
            onClicked: calculator.historyVisible = !calculator.historyVisible
            contentItem: Icon {
                name: "sidebar"
                width: 19
                height: 19
                color: host.muted
            }
        }
        ToolButton {
            x: 49
            y: 0
            height: 32
            text: calculator.mode === "scientific" ? "Scientific ⌄" : "Basic ⌄"
            Accessible.name: "Calculator Mode"
            onClicked: modeMenu.open()
        }
        Menu {
            id: modeMenu
            x: 48
            y: 34
            MenuItem {
                text: "Basic"
                checkable: true
                checked: calculator.mode === "basic"
                onTriggered: calculator.setMode("basic")
            }
            MenuItem {
                text: "Scientific"
                checkable: true
                checked: calculator.mode === "scientific"
                onTriggered: calculator.setMode("scientific")
            }
            MenuItem {
                text: "Programmer"
                enabled: false
            }
            MenuItem {
                text: "Math Notes"
                enabled: false
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 22
            y: 10
            text: (calculator.memory !== "0" ? "M   " : "") + (calculator.mode === "scientific" ? (calculator.angleMode === "degrees" ? "Deg" : "Rad") : "")
            color: host.muted
            font.pixelSize: 11
        }
        Text {
            x: 21
            y: 44
            width: parent.width - 42
            text: calculator.previous
            color: host.muted
            horizontalAlignment: Text.AlignRight
            font.pixelSize: 16
            elide: Text.ElideLeft
        }
        Text {
            x: 18
            y: 77
            width: parent.width - 36
            text: calculator.expression.replace(/pi/g, "π")
            color: host.ink
            horizontalAlignment: Text.AlignRight
            font.pixelSize: calculator.expression.length > (calculator.mode === "scientific" ? 24 : 13) ? 25 : 40
            font.weight: Font.Normal
            elide: Text.ElideLeft
        }
        Grid {
            id: keypad
            x: 14
            y: 142
            width: parent.width - 28
            height: parent.height - y - 14
            columns: calculator.mode === "scientific" ? 10 : 4
            columnSpacing: 7
            rowSpacing: 7
            Repeater {
                model: calculator.keys
                delegate: AbstractButton {
                    id: key
                    required property string modelData
                    required property int index
                    readonly property bool scientific: calculator.mode === "scientific" && index % 10 < 6
                    readonly property bool isOperator: ["+", "−", "×", "÷", "AC", "⌫", "%"].indexOf(modelData) >= 0
                    width: (keypad.width - 7 * (keypad.columns - 1)) / keypad.columns
                    height: (keypad.height - 28) / 5
                    text: modelData
                    Accessible.name: modelData === "⌫" ? "Delete" : modelData === "=" ? "Equals" : modelData === "AC" ? "All Clear" : modelData === "+/−" ? "Change Sign" : modelData
                    onClicked: {
                        calculator.press(modelData);
                        calculator.forceActiveFocus();
                    }
                    background: Rectangle {
                        radius: Math.min(width, height) / 2
                        color: key.down ? (host.dark ? "#697179" : "#bfc1c6") : key.modelData === "=" ? "#ff9300" : key.modelData === "2nd" && calculator.secondary ? "#667780" : host.dark ? (key.isOperator ? "#363a3c" : key.scientific ? "#2a2f32" : "#303436") : (key.isOperator ? "#d0d1d3" : key.scientific ? "#dcdde0" : "#e1e2e4")
                        Behavior on color {
                            ColorAnimation {
                                duration: host.desktop.reduceMotion ? 0 : 70
                            }
                        }
                    }
                    contentItem: Text {
                        text: key.text
                        color: key.modelData === "=" ? "white" : host.ink
                        font.pixelSize: key.scientific ? (key.modelData.length > 4 ? 13 : 17) : key.modelData.length > 2 ? 20 : 28
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
