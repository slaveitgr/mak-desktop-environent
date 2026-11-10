#!/usr/bin/env python3
"""Render with the shipped Plymouth script plugin in CI's private Xvfb display.

This is a real Plymouth/X11 render test with synthetic daemon messages, not a
kernel boot or DRM/hardware test. It neither formats disks nor starts a login.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time
from PySide6.QtGui import QGuiApplication


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    if os.environ.get('MAKOS_BUILD_RECOVERY_ISO')!='1' or not os.environ.get('DISPLAY') or not Path('/tmp/makos/source').is_dir():
        raise SystemExit('Use the isolated recovery-image workflow with Xvfb.')
    output=args.output;output.mkdir(parents=True,exist_ok=True)
    os.environ['QT_QPA_PLATFORM']='xcb'
    app=QGuiApplication([])
    children=[]
    def command(*args):
        return subprocess.run(['plymouth',*args],capture_output=True,text=True,timeout=4,check=True)
    def screenshot(name):
        app.processEvents()
        image=app.primaryScreen().grabWindow(0).toImage()
        assert image.width()>=800 and image.height()>=600
        assert image.save(str(output/(name+'.png')))
        # The code-generated track has no white pixels; require a substantial
        # white glyph, plus the dark background. The built-in text fallback
        # cannot satisfy the centered logo region check.
        white=0
        for y in range(120,420):
            for x in range(180,min(1400,image.width())):
                c=image.pixelColor(x,y)
                if min(c.red(),c.green(),c.blue())>210:white+=1
        assert white>100,('Logo did not render',white)
        return white
    checks=[]
    for request in ('normal','password','question'):
        debug=output/('plymouth-'+request+'.log')
        with (output/('plymouth-'+request+'-process.log')).open('w') as log:
            process=subprocess.Popen(['plymouthd','--no-daemon','--debug','--debug-file='+str(debug),
                '--mode=boot','--no-boot-log','--kernel-command-line=quiet splash','--pid-file=/run/plymouth/makos-check.pid'],stdout=log,stderr=log)
            children.append(process)
            prompt=None
            try:
                deadline=time.monotonic()+8
                while time.monotonic()<deadline:
                    if process.poll() is not None:raise RuntimeError('Plymouth exited before showing the theme')
                    try:command('--ping');break
                    except subprocess.CalledProcessError:time.sleep(.1)
                else:raise RuntimeError('Plymouth did not become ready')
                command('--show-splash');time.sleep(.8)
                if request=='normal':
                    command('update','--status=makos-theme-validation')
                    command('display-message','--text=makOS boot theme validation')
                    time.sleep(.3);command('hide-message','--text=makOS boot theme validation')
                else:
                    action='ask-for-password' if request=='password' else 'ask-question'
                    prompt=subprocess.Popen(['plymouth',action,'--prompt=makOS '+request+' prompt'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
                    children.append(prompt);time.sleep(.4)
                white=screenshot('plymouth-'+request)
                checks.append({'state':request,'centered_white_pixels':white})
            finally:
                if prompt and prompt.poll() is None:prompt.terminate();prompt.communicate(timeout=3)
                try:command('quit')
                except (subprocess.SubprocessError,OSError):pass
                try:process.wait(timeout=4)
                except subprocess.TimeoutExpired:process.kill();process.wait(timeout=2)
        trace=debug.read_text()
        assert 'makos.plymouth' in trace or 'makos.script' in trace,trace[-2500:]
        assert not any(word in trace.lower() for word in ('parser error','parse error','syntax error','could not execute script')),trace[-2500:]
    (output/'plymouth-verification.json').write_text(json.dumps({'mode':'pinned Plymouth script.so / X11 on Xvfb; synthetic messages; not a boot','checks':checks},indent=2)+'\n')
    print('PASS: pinned Plymouth renders makOS logo, progress theme, password and question prompts in Xvfb.')


if __name__=='__main__':main()
