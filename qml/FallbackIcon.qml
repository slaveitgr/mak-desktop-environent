import QtQuick

Canvas {
    id: icon
    property string name: "folder"
    property color color: "#3c4148"
    property real stroke: 1.65
    width: 20
    height: 20
    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        c.scale(width / 24, height / 24);
        c.strokeStyle = color;
        c.fillStyle = color;
        c.lineWidth = stroke;
        c.lineCap = "round";
        c.lineJoin = "round";
        function line(points) {
            c.beginPath();
            c.moveTo(points[0][0], points[0][1]);
            for (let i = 1; i < points.length; i++)
                c.lineTo(points[i][0], points[i][1]);
            c.stroke();
        }
        function rect(x, y, w, h, r) {
            c.beginPath();
            c.roundedRect(x, y, w, h, r, r);
            c.stroke();
        }
        function circle(x, y, r) {
            c.beginPath();
            c.arc(x, y, r, 0, Math.PI * 2);
            c.stroke();
        }
        switch (name) {
        case "back":
            line([[14, 5], [7, 12], [14, 19]]);
            break;
        case "forward":
        case "chevron":
            line([[9, 5], [16, 12], [9, 19]]);
            break;
        case "down":
            line([[6, 9], [12, 15], [18, 9]]);
            break;
        case "up":
            line([[6, 15], [12, 9], [18, 15]]);
            break;
        case "search":
            circle(10, 10, 6.5);
            line([[15, 15], [21, 21]]);
            break;
        case "grid":
            for (let y = 4; y < 20; y += 10)
                for (let x = 4; x < 20; x += 10)
                    rect(x, y, 6, 6, 1);
            break;
        case "list":
            for (let y = 6; y < 21; y += 6) {
                line([[4, y], [5, y]]);
                line([[9, y], [21, y]]);
            }
            break;
        case "columns":
            rect(3, 4, 18, 16, 2);
            line([[9, 4], [9, 20]]);
            line([[15, 4], [15, 20]]);
            break;
        case "more":
            for (let x = 5; x < 22; x += 7) {
                c.beginPath();
                c.arc(x, 12, 1.4, 0, Math.PI * 2);
                c.fill();
            }
            break;
        case "folder":
            line([[3, 7], [3, 20], [21, 20], [21, 7], [12, 7], [10, 4], [3, 4], [3, 7]]);
            break;
        case "newfolder":
            line([[3, 8], [3, 20], [21, 20], [21, 8], [12, 8], [10, 5], [3, 5], [3, 8]]);
            line([[12, 11], [12, 17]]);
            line([[9, 14], [15, 14]]);
            break;
        case "home":
            line([[2, 11], [12, 3], [22, 11]]);
            line([[5, 9], [5, 21], [10, 21], [10, 14], [15, 14], [15, 21], [19, 21], [19, 9]]);
            break;
        case "clock":
            circle(12, 12, 9);
            line([[12, 6], [12, 12], [16, 14]]);
            break;
        case "desktop":
            rect(2, 4, 20, 14, 2);
            line([[8, 22], [16, 22]]);
            line([[12, 18], [12, 22]]);
            break;
        case "document":
            line([[6, 2], [14, 2], [19, 7], [19, 22], [6, 22], [6, 2]]);
            line([[14, 2], [14, 8], [19, 8]]);
            break;
        case "downloads":
            circle(12, 12, 9);
            line([[12, 6], [12, 17]]);
            line([[8, 13], [12, 17], [16, 13]]);
            break;
        case "image":
            rect(3, 3, 18, 18, 3);
            circle(8, 8, 2);
            line([[3, 17], [9, 12], [13, 16], [17, 11], [21, 16]]);
            break;
        case "trash":
            rect(6, 7, 12, 14, 2);
            line([[4, 5], [20, 5]]);
            line([[9, 5], [9, 2], [15, 2], [15, 5]]);
            line([[10, 10], [10, 17]]);
            line([[14, 10], [14, 17]]);
            break;
        case "tag":
            line([[3, 4], [12, 4], [22, 14], [14, 22], [3, 11], [3, 4]]);
            circle(7, 8, 1);
            break;
        case "share":
            line([[12, 15], [12, 2]]);
            line([[8, 6], [12, 2], [16, 6]]);
            line([[7, 10], [4, 10], [4, 21], [20, 21], [20, 10], [17, 10]]);
            break;
        case "wifi":
            c.beginPath();
            c.arc(12, 22, 17, Math.PI * 1.25, Math.PI * 1.75);
            c.stroke();
            c.beginPath();
            c.arc(12, 22, 11, Math.PI * 1.25, Math.PI * 1.75);
            c.stroke();
            c.beginPath();
            c.arc(12, 22, 5, Math.PI * 1.25, Math.PI * 1.75);
            c.stroke();
            break;
        case "battery":
            rect(2, 6, 18, 11, 2);
            line([[23, 10], [23, 13]]);
            c.fillRect(4, 8, 13, 7);
            break;
        case "control":
            rect(2, 4, 20, 6, 3);
            rect(2, 15, 20, 6, 3);
            c.beginPath();
            c.arc(7, 7, 2, 0, 7);
            c.fill();
            c.beginPath();
            c.arc(17, 18, 2, 0, 7);
            c.fill();
            break;
        case "sun":
            circle(12, 12, 4);
            for (let i = 0; i < 8; i++) {
                let a = i * Math.PI / 4;
                line([[12 + 7 * Math.cos(a), 12 + 7 * Math.sin(a)], [12 + 10 * Math.cos(a), 12 + 10 * Math.sin(a)]]);
            }
            break;
        case "moon":
            c.beginPath();
            c.moveTo(15, 3);
            c.bezierCurveTo(4, 0, 0, 17, 11, 21);
            c.bezierCurveTo(17, 23, 22, 18, 22, 14);
            c.bezierCurveTo(13, 18, 8, 9, 15, 3);
            c.stroke();
            break;
        case "close":
            line([[6, 6], [18, 18]]);
            line([[18, 6], [6, 18]]);
            break;
        case "check":
            line([[4, 12], [9, 17], [20, 6]]);
            break;
        case "sidebar":
            rect(2, 4, 20, 16, 2);
            line([[9, 4], [9, 20]]);
            line([[4, 8], [7, 8]]);
            line([[4, 12], [7, 12]]);
            break;
        case "apple":
            c.beginPath();
            c.moveTo(13, 7);
            c.bezierCurveTo(7, 3, 2, 9, 5, 16);
            c.bezierCurveTo(7, 23, 10, 22, 13, 20);
            c.bezierCurveTo(17, 23, 19, 20, 21, 16);
            c.bezierCurveTo(15, 14, 16, 10, 20, 8);
            c.bezierCurveTo(17, 5, 15, 5, 13, 7);
            c.fill();
            c.beginPath();
            c.moveTo(12, 5);
            c.bezierCurveTo(12, 2, 15, 0, 17, 0);
            c.bezierCurveTo(17, 3, 15, 5, 12, 5);
            c.fill();
            break;
        default:
            circle(12, 12, 7);
        }
    }
}
