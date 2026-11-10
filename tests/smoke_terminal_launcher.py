"""Exercise the installed system-terminal alternative on the private compositor."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

assert sys.platform == 'linux' and os.environ.get('MAKOS_IMAGE_CHROOT') == '1'
assert Path('/usr/bin/x-terminal-emulator').resolve() == Path('/usr/bin/makos-terminal')
with tempfile.TemporaryDirectory(prefix='makos-terminal-launch-') as temporary:
    folder = Path(temporary); marker = folder/'result.json'
    literal = 'space ; $(touch must-not-exist) `literal`'
    code = ('import json,os,sys; from pathlib import Path; '
            'Path(sys.argv[1]).write_text(json.dumps({"cwd":os.getcwd(),'
            '"tty":all(os.isatty(n) for n in (0,1,2)),"argument":sys.argv[2]}))')
    with (folder/'client.log').open('w+') as log:
        process = subprocess.Popen(['/usr/bin/x-terminal-emulator','-e','/usr/bin/python3','-c',code,str(marker),literal],
                                   cwd=folder, stdout=log, stderr=log, start_new_session=True)
        try:
            deadline=time.monotonic()+25
            while time.monotonic()<deadline and process.poll() is None:
                if marker.is_file():break
                time.sleep(.1)
            assert marker.is_file(), 'Installed Terminal failed to execute its command'
            result=json.loads(marker.read_text())
            assert result == {'cwd':str(folder),'tty':True,'argument':literal}, result
            assert not (folder/'must-not-exist').exists()
            assert process.poll() is None, 'The native Terminal window exited unexpectedly'
            print('PASS: system terminal alternative opens a native window, allocates a PTY, preserves cwd and literal argv')
        except Exception:
            log.flush();log.seek(0);print(log.read()[-5000:]);raise
        finally:
            if process.poll() is None:
                os.killpg(process.pid,signal.SIGTERM)
                try:process.wait(timeout=5)
                except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);process.wait()
