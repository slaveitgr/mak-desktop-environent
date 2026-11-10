"""Owned Qt Quick browser sessions, separate from the user's host browser."""
from pathlib import Path

from PySide6.QtCore import QObject, Slot
from PySide6.QtQml import QQmlEngine


class BrowserProfiles(QObject):
    def __init__(self, data_dir, parent=None):
        super().__init__(parent)
        self.data_dir = Path(data_dir)
        self._regular = None
        self._private = set()

    @Slot(bool, result=QObject)
    def acquire(self, private=False):
        # Import/create only after QtWebEngineQuick and QGuiApplication startup.
        from PySide6.QtWebEngineQuick import QQuickWebEngineProfile

        if not private and self._regular is not None:
            return self._regular
        profile = QQuickWebEngineProfile(self)
        QQmlEngine.setObjectOwnership(profile, QQmlEngine.CppOwnership)
        if private:
            profile.setOffTheRecord(True)
            profile.setHttpCacheType(QQuickWebEngineProfile.MemoryHttpCache)
            profile.setPersistentCookiesPolicy(QQuickWebEngineProfile.NoPersistentCookies)
            self._private.add(profile)
        else:
            browser_dir = self.data_dir / 'browser'
            for folder in (browser_dir, browser_dir / 'regular', browser_dir / 'cache'):
                if folder.is_symlink():
                    profile.deleteLater()
                    raise ValueError('Browser storage cannot be a symbolic link')
                folder.mkdir(mode=0o700, exist_ok=True)
            profile.setStorageName('makos-regular')
            profile.setPersistentStoragePath(str(browser_dir / 'regular'))
            profile.setCachePath(str(browser_dir / 'cache'))
            profile.setOffTheRecord(False)
            profile.setHttpCacheType(QQuickWebEngineProfile.DiskHttpCache)
            profile.setPersistentCookiesPolicy(QQuickWebEngineProfile.AllowPersistentCookies)
            self._regular = profile
        return profile

    @Slot(QObject)
    def release(self, profile):
        # Call after the owning window has unloaded all of its WebEngineViews.
        # The shared regular profile lives until application/Bridge teardown.
        if profile in self._private:
            self._private.remove(profile)
            profile.deleteLater()

    @Slot(QObject)
    def releaseDownload(self, request):
        # Qt owns the request and forwards its destruction to Chromium's
        # DownloadItem::Remove. Defer destruction beyond download signal frames.
        if request is not None and request.inherits('QWebEngineDownloadRequest'):
            request.deleteLater()
