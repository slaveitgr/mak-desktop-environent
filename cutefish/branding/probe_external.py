#!/usr/bin/env python3
"""Exercise real external QML shell surfaces in the isolated Linux CI rootfs."""
import argparse
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time
from PySide6.QtGui import QImage

ROOT = Path(__file__).resolve().parents[2]
SERVICE = 'org.cutefish.WindowDebug1'
OBJECT = '/org/cutefish/WindowDebug1'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    if sys.platform!='linux' or os.environ.get('MAKOS_EXTERNAL_SHELL_TEST')!='1' or ROOT!=Path('/tmp/makos/source'):
        raise SystemExit('Use the isolated external-shell CI check.')
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtDBus import QDBusConnection,QDBusMessage
    qt=QCoreApplication.instance() or QCoreApplication([])
    commit=os.environ.get('MAKOS_SOURCE_COMMIT','')
    if not re.fullmatch('[0-9a-f]{40}',commit):raise SystemExit('Missing source commit for the validation report.')
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    report={'result':'running','source_commit':commit,'mode':'real native QML surfaces and compositor, software/headless display','checks':{},
            'limits':['No physical boot, DRM/GPU or visual-parity claim.','Native menu bridge covers cutefish-main-menu clients.']}
    processes=[]
    with tempfile.TemporaryDirectory(prefix='makos-external-') as directory:
        temp=Path(directory);runtime=temp/'runtime';runtime.mkdir(mode=0o700)
        home=temp/'home';home.mkdir();(home/'Documents').mkdir();(home/'Documents/probe.txt').write_text('makOS external shell validation\n')
        geometry=output/'external-shell-geometry.json'
        env=dict(os.environ,XDG_RUNTIME_DIR=str(runtime),XDG_STATE_HOME=str(output/'session-state'),
                 XDG_DATA_HOME=str(temp/'data'),XDG_CONFIG_HOME=str(temp/'config'),
                 MAKOS_SHELL_TEST_GEOMETRY=str(geometry))
        for key in ('DISPLAY','WAYLAND_DISPLAY','WAYLAND_SOCKET','XAUTHORITY'):env.pop(key,None)
        with (output/'external-session.log').open('w') as session_log, (output/'external-finder.log').open('w') as finder_log:
            session=subprocess.Popen([sys.executable,str(ROOT/'cutefish/session.py'),'--headless'],env=env,stdout=session_log,stderr=session_log,start_new_session=True)
            processes.append(session)
            env.update(WAYLAND_DISPLAY='makos-'+str(session.pid),QT_QPA_PLATFORM='wayland',QT_QUICK_BACKEND='software',LIBGL_ALWAYS_SOFTWARE='1',EGL_PLATFORM='surfaceless')
            def call(method,signature='',*arguments):
                command=['busctl','--user','--json=short','call',SERVICE,OBJECT,SERVICE,method]
                if signature:command += [signature]+[str(a).lower() if isinstance(a,bool) else str(a) for a in arguments]
                result=subprocess.run(command,env=env,capture_output=True,text=True,timeout=5)
                if result.returncode:raise RuntimeError(method+': '+result.stderr.strip())
                values=json.loads(result.stdout)['data']
                return values[0] if values else None
            def windows():return json.loads(call('ListWindows'))
            def wait_for(predicate,description,seconds=20):
                deadline=time.monotonic()+seconds;last=None
                while time.monotonic()<deadline:
                    if session.poll() is not None:raise RuntimeError('Supervisor exited during '+description)
                    try:
                        value=predicate()
                        if value:return value
                    except (RuntimeError,ValueError,KeyError) as error:last=str(error)
                    time.sleep(.1)
                raise AssertionError(description+' timed out: '+str(last))
            def role_set():
                values=windows();roles={r:[w for w in values if w['role']==r] for r in ('desktop','panel','dock')}
                if not all(len(v)==1 for v in roles.values()):return None
                if not all(v[0]['appId']=='org.makos.Shell' for v in roles.values()):return None
                return roles
            def snapshot(name):
                path=output/(name+'.png')
                subprocess.run(['cutefish-screenshot',str(path)],env=env,capture_output=True,text=True,timeout=35,check=True)
                image=QImage(str(path));assert not image.isNull() and image.width()>=800 and image.height()>=600
                colors={image.pixel(x,y) for y in range(0,image.height(),13) for x in range(0,image.width(),13)}
                assert len(colors)>20,('Blank compositor capture',name,len(colors))
                return {'file':path.name,'width':image.width(),'height':image.height(),'sampled_colors':len(colors)}
            def finder_windows():return [w for w in windows() if w['role']=='normal' and not w['popup'] and w['appId']=='org.makos.Finder']
            try:
                roles=wait_for(role_set,'one authoritative shell')
                report['checks']['single_shell']=roles
                areas=wait_for(lambda:json.loads(call('WorkAreas')),'work areas')
                bounds=areas[0]['bounds'];work=areas[0]['workArea']
                assert work[1]>=bounds[1]+30 and work[1]+work[3]<bounds[1]+bounds[3],areas
                report['checks']['reserved_work_area']=areas
                report['checks']['desktop_capture']=snapshot('external-desktop')
                finder=subprocess.Popen([sys.executable,str(ROOT/'main.py'),'--cutefish-app','finder','--root',str(home)],env=env,stdout=finder_log,stderr=finder_log,start_new_session=True)
                processes.append(finder)
                window=wait_for(lambda:next(iter(finder_windows()),None),'native Finder')
                identity=int(window['id'])
                assert call('ActivateWindow','t',identity)
                window=wait_for(lambda:next((w for w in finder_windows() if int(w['id'])==identity and w['active']),None),'Finder activation')
                assert window['bounds'][1]>=work[1],window
                report['checks']['finder_overlap']=snapshot('external-finder-overlap')
                menu=wait_for(lambda:(lambda m:m if m.get('available') and len(m.get('items',[]))>1 else None)(json.loads(call('GetWindowMenu','t',identity))),'actual Finder menu')
                for item in menu['items']:
                    if item['id'] and item['hasSubmenu']:
                        call('MenuEvent','tis',identity,item['id'],'prepare')
                menu=wait_for(lambda:(lambda m:m if any('new' in i['label'].lower() and 'window' in i['label'].lower() for i in m['items']) else None)(json.loads(call('GetWindowMenu','t',identity))),'New Finder Window menu command')
                command=next(i for i in menu['items'] if 'new' in i['label'].lower() and 'window' in i['label'].lower() and not i['hasSubmenu'])
                before={w['id'] for w in finder_windows()}
                assert call('MenuEvent','tis',identity,command['id'],'activate')
                added=wait_for(lambda:next((w for w in finder_windows() if w['id'] not in before),None),'menu creates a real Finder window')
                assert call('CloseWindow','t',int(added['id']))
                wait_for(lambda:not any(w['id']==added['id'] for w in finder_windows()),'new window closes')
                assert call('ActivateWindow','t',identity)
                report['checks']['native_menu_action']={'command':command['label'],'created_window':added['id'],'closed':True}
                def right_target():
                    current=next((w for w in finder_windows() if int(w['id'])==identity),None)
                    dock=role_set()['dock'][0]['bounds']
                    target=current['minimizedGeometry'] if current else [0,0,0,0]
                    if target[2]>0 and target[3]>0 and target[0]+target[2]/2>dock[0]+dock[2]/2:return {'window':current,'dock':dock,'target':target}
                    return None
                target=wait_for(right_target,'preassigned right-side Dock minimize target')
                assert call('MinimizeWindow','t',identity)
                minimized=wait_for(lambda:next((w for w in finder_windows() if int(w['id'])==identity and w['state']=='minimized'),None),'Finder minimizes')
                time.sleep(.5)
                report['checks']['minimized_capture']=snapshot('external-finder-minimized')
                assert call('RestoreWindow','t',identity)
                restored=wait_for(lambda:next((w for w in finder_windows() if int(w['id'])==identity and w['state']=='normal' and w['visible']),None),'Finder restores')
                report['checks']['minimize_restore']={'target_before_minimize':target,'minimized':minimized['state'],'restored':restored['state']}
                report['checks']['restored_capture']=snapshot('external-finder-restored')
                assert call('SetWindowFullscreen','tb',identity,True)
                wait_for(lambda:any(int(w['id'])==identity and w['state']=='fullscreen' for w in finder_windows()),'Finder fullscreen')
                time.sleep(.4)
                report['checks']['fullscreen_capture']=snapshot('external-finder-fullscreen')
                assert call('SetWindowFullscreen','tb',identity,False)
                wait_for(lambda:any(int(w['id'])==identity and w['state']=='normal' for w in finder_windows()),'Finder exits fullscreen')
                controls=wait_for(lambda:json.loads(geometry.read_text()).get('controls') if geometry.is_file() else None,'QML control geometry')
                for name in ('apple','control'):
                    control=controls[name]
                    owner=next(w for w in windows() if w['title']==control['windowTitle'] and not w['popup'])
                    x=owner['bounds'][0]+control['x'];y=owner['bounds'][1]+control['y']
                    initial={w['id'] for w in windows() if w['popup']}
                    assert call('PointerMotion','dd',x,y)
                    assert call('PointerButton','ub',272,True);assert call('PointerButton','ub',272,False)
                    popup=wait_for(lambda:next((w for w in windows() if w['popup'] and w['id'] not in initial),None),name+' real popup')
                    assert popup['bounds'][3]>30,popup
                    report['checks'][name+'_popup']={'popup':popup,'capture':snapshot('external-'+name+'-popup')}
                    assert call('Key','ub',1,True);assert call('Key','ub',1,False)
                    wait_for(lambda:not any(w['id']==popup['id'] for w in windows()),name+' popup dismissed')
                # Drive the physical evdev key path, not the shell signal directly.
                def launcher_visible():
                    state=json.loads(geometry.read_text())
                    assert isinstance(state.get('appsOverlayVisible'),bool),state
                    return state['appsOverlayVisible']
                def key(code,pressed):assert call('Key','ub',code,pressed)
                wait_for(lambda:not launcher_visible(),'launcher initially closed')
                normal_before={w['id'] for w in windows() if w['role']=='normal' and not w['popup']}
                key(125,True);time.sleep(.3)
                assert not launcher_visible(),'Super press must wait for release'
                key(125,False)
                wait_for(launcher_visible,'lone Super opens Apps overlay')
                assert {w['id'] for w in windows() if w['role']=='normal' and not w['popup']}==normal_before
                report['checks']['apps_overlay_capture']=snapshot('external-apps-overlay')
                key(125,True);key(125,False)
                wait_for(lambda:not launcher_visible(),'second Super closes Apps overlay')
                key(125,True);key(30,True);key(30,False);key(125,False)
                time.sleep(.5)
                assert not launcher_visible(),'Super+key combination incorrectly toggled Apps'
                key(126,True);key(126,False)
                wait_for(launcher_visible,'right Super opens Apps overlay')
                key(1,True);key(1,False)
                wait_for(lambda:not launcher_visible(),'Escape closes Apps overlay')
                route=subprocess.run([sys.executable,str(ROOT/'main.py'),'--cutefish-app','apps','--root',str(home)],
                                     env=env,capture_output=True,text=True,timeout=10)
                assert route.returncode==0,route.stdout+route.stderr
                wait_for(launcher_visible,'Apps desktop launcher routes to shell overlay')
                key(1,True);key(1,False)
                wait_for(lambda:not launcher_visible(),'Apps route overlay dismisses')
                assert {w['id'] for w in windows() if w['role']=='normal' and not w['popup']}==normal_before
                report['checks']['lone_super_launcher']={'left_and_right':True,'press_waits_for_release':True,
                    'combination_does_not_toggle':True,'toggle_and_escape_close':True,'desktop_launcher_route':True,'no_new_application_window':True}
                # no-DRM mode has no hardware Osd service. A private fixture
                # sender tests native host/input behavior, not physical levels.
                bus=QDBusConnection.sessionBus()
                assert bus.registerService('org.cutefish.Osd'),'Unexpected hardware OSD service on isolated headless test bus'
                try:
                    def level(value=.42,available=True):
                        message=QDBusMessage.createSignal('/Osd','org.cutefish.Osd','LevelChanged')
                        message.setArguments(['volume',value,False,'CI audio fixture',available])
                        assert bus.send(message)
                        qt.processEvents()
                    second=subprocess.Popen([sys.executable,str(ROOT/'main.py'),'--cutefish-app','settings','--root',str(home)],
                                            env=env,stdout=finder_log,stderr=finder_log,start_new_session=True)
                    processes.append(second)
                    settings=wait_for(lambda:next((w for w in windows() if w['appId']=='org.makos.Settings' and w['role']=='normal' and not w['popup']),None),'Settings for OSD click-through')
                    settings_id=int(settings['id'])
                    width=min(920,bounds[2]);height=min(640,work[3])
                    assert call('SetWindowBounds','tiiii',settings_id,bounds[0]+bounds[2]-width,work[1],width,height)
                    assert call('SetWindowBounds','tiiii',identity,bounds[0]+20,work[1]+150,min(700,bounds[2]-40),min(420,work[3]-150))
                    assert call('ActivateWindow','t',identity)
                    wait_for(lambda:any(int(w['id'])==identity and w['active'] for w in finder_windows()),'Finder focus before OSD')
                    time.sleep(.2)
                    level()
                    osd=wait_for(lambda:next((w for w in windows() if w['role']=='osd' and w['visible']),None),'trusted native OSD surface')
                    assert not osd['popup'] and not osd['active'] and osd['appId']=='org.makos.Shell',osd
                    assert osd['bounds'][2:]==[290,62],osd
                    assert any(int(w['id'])==identity and w['active'] for w in finder_windows()),'OSD stole keyboard focus'
                    x,y,width,height=osd['bounds']
                    assert call('PointerMotion','dd',x+width/2,y+height/2)
                    assert call('PointerButton','ub',272,True);assert call('PointerButton','ub',272,False)
                    wait_for(lambda:any(int(w['id'])==settings_id and w['active'] for w in windows()),'pointer passes through OSD to Settings')
                    report['checks']['native_osd_focus']={'fixture_level_event':True,'hardware_test':False,'surface':osd,
                                                         'no_focus_theft':True,'click_through':True}
                    level(available=False)
                    wait_for(lambda:not any(w['role']=='osd' and w['visible'] for w in windows()),'unavailable source dismisses native OSD')
                    assert call('CloseWindow','t',settings_id)
                    wait_for(lambda:not any(int(w['id'])==settings_id for w in windows()),'OSD fixture Settings window closes')
                finally:
                    bus.unregisterService('org.cutefish.Osd')
                assert role_set()
                report['result']='passed'
                print('PASS: single native makOS shell, real Finder menu action, reserved work area, right Dock target, minimize/restore/fullscreen, native menu/Control Center popups and compositor screenshots.')
            except BaseException as error:
                report['result']='failed';report['error']=str(error)
                raise
            finally:
                (output/'external-shell-validation.json').write_text(json.dumps(report,indent=2)+'\n')
                for process in reversed(processes):
                    if process.poll() is None:
                        os.killpg(process.pid,signal.SIGTERM)
                        try:process.wait(timeout=8)
                        except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=2)


if __name__=='__main__':main()
