#!/usr/bin/env python3
"""Build a local macOS preview launcher with an explicit camera usage declaration.

This embeds the current Python framework in-process. It references this checkout
and its Python environment; it is not a standalone redistribution package.
"""
import json
from pathlib import Path
import plistlib
import subprocess
import sys
import sysconfig

ROOT = Path(__file__).resolve().parent

def build():
    if sys.platform != 'darwin':
        raise SystemExit('The preview launcher is only needed on macOS. Use run.sh on Linux.')
    framework = Path(sys.base_prefix)
    if '.framework' not in str(framework):
        raise SystemExit('Build with a framework Python distribution on macOS.')
    bundle = ROOT / 'Tahoe Desktop.app'
    macos = bundle / 'Contents/MacOS'; resources = bundle / 'Contents/Resources'
    macos.mkdir(parents=True,exist_ok=True);resources.mkdir(exist_ok=True)
    site = Path(sys.prefix) / 'lib' / ('python' + sysconfig.get_python_version()) / 'site-packages'
    source = resources / 'launcher.c'
    def c(value): return json.dumps(str(value))
    source.write_text('''#include <Python.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    wchar_t *pythonHome = Py_DecodeLocale(HOME_PATH, NULL);
    if (!pythonHome) return 1;
    Py_SetPythonHome(pythonHome);
    setenv("PYTHONPATH", MODULE_PATH, 1);
    setenv("QT_QUICK_CONTROLS_STYLE", "Basic", 0);
    Py_Initialize();
    wchar_t **arguments = calloc((size_t)argc+1, sizeof(wchar_t*));
    if (!arguments) return 1;
    arguments[0] = Py_DecodeLocale(SCRIPT_PATH, NULL);
    for(int i=1;i<argc;i++) arguments[i]=Py_DecodeLocale(argv[i],NULL);
    PySys_SetArgvEx(argc, arguments, 1);
    FILE *script = fopen(SCRIPT_PATH, "r");
    if(!script) { perror("Cannot open desktop entry point"); return 1; }
    int result = PyRun_SimpleFileEx(script, SCRIPT_PATH, 1);
    if(Py_FinalizeEx() < 0) result=1;
    for(int i=0;i<argc;i++) PyMem_RawFree(arguments[i]);
    free(arguments);PyMem_RawFree(pythonHome);
    return result == 0 ? 0 : 1;
}
''')
    framework_root = next(p for p in framework.parents if p.suffix == '.framework')
    framework_name = framework_root.stem
    args=['/usr/bin/clang',str(source),'-I'+sysconfig.get_path('include'),'-F'+str(framework_root.parent),'-framework',framework_name,'-Wl,-rpath,'+str(framework_root.parent),
          '-DHOME_PATH='+c(framework),'-DMODULE_PATH='+c(str(site)+':'+str(ROOT)),'-DSCRIPT_PATH='+c(ROOT/'main.py'),'-o',str(macos/'TahoeDesktop')]
    subprocess.run(args, check=True)
    info={'CFBundleExecutable':'TahoeDesktop','CFBundleIdentifier':'org.tahoedesktop.prototype','CFBundleName':'Tahoe Desktop',
          'CFBundleDisplayName':'Tahoe Desktop','CFBundlePackageType':'APPL','CFBundleShortVersionString':'0.7','CFBundleVersion':'7',
          'NSPrincipalClass':'NSApplication','NSHighResolutionCapable':True,'NSSupportsAutomaticGraphicsSwitching':True,
          'NSCameraUsageDescription':'Photo Booth uses the camera when you choose Start Camera, to preview and save photos in this desktop.'}
    (bundle/'Contents/Info.plist').write_bytes(plistlib.dumps(info))
    (resources/'launcher.json').write_text(json.dumps({'python':sys.executable,'framework':str(framework),'sitePackages':str(site),'project':str(ROOT),'portable':False},indent=2))
    subprocess.run(['/usr/bin/codesign','--force','--sign','-',str(bundle)],check=True)
    print(bundle)

if __name__=='__main__':build()
