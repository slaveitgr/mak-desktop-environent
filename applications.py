"""Explicit application registry and platform launch adapters.

The Dock opens independently implemented suite windows. The explicit host adapter
remains available for host Settings and fallback integrations; it does not port Apple services.
"""
from pathlib import Path
import shutil
import sys

APPLICATIONS = [
    dict(id='apps', name='Apps', bundle='com.apple.apps.launcher', mac='/System/Applications/Apps.app', linux=[]),
    dict(id='calculator', name='Calculator', bundle='com.apple.calculator', mac='/System/Applications/Calculator.app', linux=[]),
    dict(id='chess', name='Chess', bundle='com.apple.Chess', mac='/System/Applications/Chess.app', linux=[]),
    dict(id='photobooth', name='Photo Booth', bundle='com.apple.PhotoBooth', mac='/System/Applications/Photo Booth.app', linux=[]),
    dict(id='safari', name='Safari', bundle='com.apple.Safari', mac='/Applications/Safari.app', linux=['epiphany','firefox','chromium']),
    dict(id='messages', name='Messages', bundle='com.apple.MobileSMS', mac='/System/Applications/Messages.app', linux=['fractal']),
    dict(id='mail', name='Mail', bundle='com.apple.mail', mac='/System/Applications/Mail.app', linux=['thunderbird','evolution']),
    dict(id='maps', name='Maps', bundle='com.apple.Maps', mac='/System/Applications/Maps.app', linux=['gnome-maps']),
    dict(id='photos', name='Photos', bundle='com.apple.Photos', mac='/System/Applications/Photos.app', linux=['shotwell','digikam']),
    dict(id='facetime', name='FaceTime', bundle='com.apple.FaceTime', mac='/System/Applications/FaceTime.app', linux=[]),
    dict(id='phone', name='Phone', bundle='com.apple.mobilephone', mac='/System/Applications/Phone.app', linux=[]),
    dict(id='calendar', name='Calendar', bundle='com.apple.iCal', mac='/System/Applications/Calendar.app', linux=['gnome-calendar','korganizer']),
    dict(id='reminders', name='Reminders', bundle='com.apple.reminders', mac='/System/Applications/Reminders.app', linux=['endeavour','gnome-todo']),
    dict(id='notes', name='Notes', bundle='com.apple.Notes', mac='/System/Applications/Notes.app', linux=['gnote']),
    dict(id='contacts', name='Contacts', bundle='com.apple.AddressBook', mac='/System/Applications/Contacts.app', linux=['gnome-contacts','kaddressbook']),
    dict(id='music', name='Music', bundle='com.apple.Music', mac='/System/Applications/Music.app', linux=['rhythmbox','elisa']),
    dict(id='games', name='Games', bundle='com.apple.games', mac='/System/Applications/Games.app', linux=['lutris','steam']),
    dict(id='appstore', name='App Store', bundle='com.apple.AppStore', mac='/System/Applications/App Store.app', linux=['gnome-software','plasma-discover']),
    dict(id='terminal', name='Terminal', bundle='com.apple.Terminal', mac='/System/Applications/Utilities/Terminal.app', linux=['konsole','gnome-terminal','xfce4-terminal']),
]
APPLICATIONS.sort(key=lambda a: (0 if a['id']=='apps' else 2 if a['id'] in ('calculator','chess','photobooth') else 1))
HOST_SETTINGS = dict(id='host-settings', name='System Settings', bundle='com.apple.systempreferences', mac='/System/Applications/System Settings.app', linux=['dde-control-center','systemsettings','systemsettings6','gnome-control-center'])


class ApplicationLauncher:
    def __init__(self, platform=None, exists=None, which=None):
        self.platform = platform or sys.platform
        self.exists = exists or (lambda path: Path(path).is_dir())
        self.which = which or shutil.which
        self.apps = {item['id']: item for item in APPLICATIONS + [HOST_SETTINGS]}

    def command(self, app_id):
        app = self.apps.get(app_id)
        if not app:
            return []
        if self.platform == 'darwin':
            return ['/usr/bin/open', '-b', app['bundle']] if self.exists(app['mac']) else []
        if self.platform.startswith('linux'):
            for candidate in app['linux']:
                executable = self.which(candidate)
                if executable:
                    return [executable]
        return []

    def catalog(self):
        return [dict(id=a['id'], name=a['name'], image=a['id']+'.png',
                     available=True, provider='Built-in', label=a['name'],
                     hostAvailable=bool(self.command(a['id']))) for a in APPLICATIONS]
