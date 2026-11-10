import QtQuick

// An opaque window body with a rounded transparent opening for the real
// compositor backdrop. Gutters remain opaque, including the glass corners.
Canvas {
    id: frame
    property color bodyColor: "#fcfcfd"
    property color borderColor: "#b8bdc4"
    property real borderWidth: 1
    property real corner: 25
    property real glassCorner: 19
    property rect glassRect: Qt.rect(8, 8, 200, height - 16)
    onBodyColorChanged: requestPaint()
    onBorderColorChanged: requestPaint()
    onBorderWidthChanged: requestPaint()
    onCornerChanged: requestPaint()
    onGlassCornerChanged: requestPaint()
    onGlassRectChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    function rounded(ctx, x, y, w, h, radius) {
        let r = Math.max(0, Math.min(radius, w / 2, h / 2));
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.lineTo(x + w - r, y); ctx.quadraticCurveTo(x + w, y, x + w, y + r);
        ctx.lineTo(x + w, y + h - r); ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
        ctx.lineTo(x + r, y + h); ctx.quadraticCurveTo(x, y + h, x, y + h - r);
        ctx.lineTo(x, y + r); ctx.quadraticCurveTo(x, y, x + r, y);
        ctx.closePath();
    }
    onPaint: {
        let ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        rounded(ctx, 0, 0, width, height, corner);
        ctx.fillStyle = bodyColor; ctx.fill();
        if (glassRect.width > 0 && glassRect.height > 0) {
            ctx.globalCompositeOperation = "destination-out";
            rounded(ctx, glassRect.x, glassRect.y, glassRect.width, glassRect.height, glassCorner);
            ctx.fillStyle = "black"; ctx.fill();
            ctx.globalCompositeOperation = "source-over";
        }
        if (borderWidth > 0) {
            let inset = borderWidth / 2;
            rounded(ctx, inset, inset, width - borderWidth, height - borderWidth, Math.max(0, corner - inset));
            ctx.strokeStyle = borderColor; ctx.lineWidth = borderWidth; ctx.stroke();
        }
    }
}
