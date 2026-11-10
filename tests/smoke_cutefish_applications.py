"""All native client startup identities in an already isolated Linux compositor.

No UI clicks, cameras, shells, network navigation, pairing, or service writes.
This checks window/page startup, not completeness of each application's features.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from applications import NATIVE_WINDOW_APPLICATIONS


def run(results, environment=None):
    if sys.platform != 'linux':
        raise RuntimeError('Native Wayland application smoke requires Linux.')
    env=dict(os.environ if environment is None else environment)
    if not env.get('WAYLAND_DISPLAY'):
        raise RuntimeError('Start an isolated Cutefish compositor before running this check.')
    results=Path(results);results.mkdir(parents=True,exist_ok=True)
    env.update(WAYLAND_DEBUG='client',QT_QUICK_CONTROLS_STYLE='Basic')
    passed={}
    with TemporaryDirectory(prefix='makos-native-apps-') as temporary:
        workspace=Path(temporary)/'workspace';workspace.mkdir()
        for app in NATIVE_WINDOW_APPLICATIONS:
            kind=app['id'];path=results/(kind+'-startup.log')
            with path.open('w') as log:
                process=subprocess.run([sys.executable,str(ROOT/'main.py'),'--cutefish-app',kind,
                    '--smoke-test','--root',str(workspace)],env=env,stdout=log,stderr=log,timeout=30)
            trace=path.read_text()
            marker=[line.split('=',1)[1] for line in trace.splitlines() if line.startswith('MAKOS_NATIVE_APP_SMOKE=')]
            errors=[token for token in ('TypeError:','ReferenceError:','failed to load component','error in client communication','Expected token','is not a type','FAIL:') if token in trace]
            if process.returncode or len(marker)!=1 or errors:
                raise AssertionError(f'{kind}: exit={process.returncode}, results={len(marker)}, errors={errors}; see {path}')
            state=json.loads(marker[0])
            assert state['appId']==app['desktop_id'] and state['kind']==kind and state['pageReady'] and state['native'],state
            assert '.set_app_id("'+app['desktop_id']+'")' in trace,(kind,'Wayland app_id was not observed')
            assert '.get_toplevel(' in trace and '.set_main_menu(' in trace,(kind,'native window/menu protocol absent')
            passed[kind]=state
    (results/'native-app-startup.json').write_text(json.dumps({'scope':'20 native client windows; Apps is tested separately as a shell overlay; no full-feature or hardware claim','applications':passed},indent=2)+'\n')
    return passed

if __name__=='__main__':
    result=run(Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'cutefish/build/results/native-apps')
    print(f'PASS: {len(result)} native application windows/pages and Wayland identities.')
