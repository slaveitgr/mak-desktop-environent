"""Native-window startup assertions used only by --smoke-test on Linux CI."""
import json
import subprocess
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
                pageReady: !!(window && (window.appKind === "finder" || window.appKind === "settings" || window.pageItem)),
                menuTitles: window ? JSON.parse(controller.nativeMenuRows(window)).map(function(menu){return menu.label;}) : []};
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
        assert state['menuTitles'] and state['menuTitles'][0] == expected['name'], state
        # Read the compositor's real protocol model, not just the QML export.
        def compositor(method, *arguments):
            result = subprocess.run(['busctl', '--user', '--json=short', 'call',
                'org.cutefish.WindowDebug1', '/org/cutefish/WindowDebug1', 'org.cutefish.WindowDebug1',
                method, *arguments], capture_output=True, text=True, timeout=3)
            assert result.returncode == 0, result.stderr
            return json.loads(json.loads(result.stdout)['data'][0])
        clients = [window for window in compositor('ListWindows') if window['appId'] == expected['desktop_id']
                   and window['role'] == 'normal' and not window['popup']]
        assert len(clients) == 1, clients
        menu = compositor('GetWindowMenu', 't', str(clients[0]['id']))
        items = {item['id']: item for item in menu['items']}
        actual_titles = [items[identity]['label'] for identity in items[0]['children']]
        assert menu['available'] and actual_titles == state['menuTitles'], (actual_titles, state['menuTitles'])
        if app_id == 'safari': assert 'Bookmarks' in actual_titles
        if app_id == 'appstore': assert 'Store' in actual_titles
        state['compositorMenuTitles'] = actual_titles
        state.update(appId=app.desktopFileName(), appName=app.applicationName(), kind=app_id, result='passed')
        print('MAKOS_NATIVE_APP_SMOKE=' + json.dumps(state, sort_keys=True), flush=True)
        app.exit(0)
    except (AssertionError, ValueError, TypeError, KeyError, OSError, subprocess.SubprocessError) as error:
        print('FAIL: native application startup: ' + str(error), flush=True)
        app.exit(1)
