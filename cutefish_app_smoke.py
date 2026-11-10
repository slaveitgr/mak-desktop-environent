"""Native-window startup assertions used only by --smoke-test on Linux CI."""
import json
from PySide6.QtQml import QQmlExpression
from applications import NATIVE_APP_INFO


def verify_startup(app, root, engine, app_id):
    expression = QQmlExpression(engine.rootContext(), root, '''JSON.stringify((function() {
        const windows = controller.windows;
        const window = windows.length === 1 ? windows[0] : null;
        return {count: windows.length, kind: window ? window.appKind : "",
                title: window ? window.windowTitle : "",
                native: !!(window && window.nativeWindow && window.nativeWindow.visible),
                glassProtocol: !!(window && window.nativeWindow && window.nativeWindow.compositorGlass),
                pageReady: !!(window && (window.appKind === "finder" || window.appKind === "settings" || window.pageItem))};
    })())''')
    try:
        result = expression.evaluate()
        value = result[0] if isinstance(result, tuple) else result
        if expression.hasError():
            raise AssertionError(expression.error().toString())
        state = json.loads(value)
        expected = NATIVE_APP_INFO[app_id]
        assert state['count'] == 1, state
        assert state['kind'] == app_id and app.applicationName() == expected['name'], state
        assert state['title'], state
        if app_id != 'finder':
            assert state['title'] == expected['name'], state
        assert state['native'] and state['pageReady'], state
        # Sidebar-free apps intentionally request no sidebar glass.
        assert app.desktopFileName() == expected['desktop_id'], app.desktopFileName()
        state.update(appId=app.desktopFileName(), appName=app.applicationName(), kind=app_id, result='passed')
        print('MAKOS_NATIVE_APP_SMOKE=' + json.dumps(state, sort_keys=True), flush=True)
        app.exit(0)
    except (AssertionError, ValueError, TypeError, KeyError) as error:
        print('FAIL: native application startup: ' + str(error), flush=True)
        app.exit(1)
