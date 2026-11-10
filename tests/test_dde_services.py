"""DDE wire contracts and unavailable-service handling without changing the host."""
import sys
from pathlib import Path
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dde_services import DdeAudio


class DdeAudioTests(unittest.TestCase):
    def make_audio(self):
        self.calls = []
        self.values = {'DefaultSink': '/org/deepin/dde/Audio1/Sink7', 'Volume': 0.65, 'Mute': False}
        def transport(path, interface, method, arguments, callback):
            self.calls.append((path, interface, method, arguments))
            if method == 'Get': callback([self.values[arguments[1]]], '')
            elif method == 'SetVolume': self.values['Volume'] = arguments[0]; callback([], '')
            elif method == 'SetMute': self.values['Mute'] = arguments[0]; callback([], '')
        with patch('dde_services.sys.platform', 'linux'):
            audio = DdeAudio(True, transport=transport)
        audio.refresh()
        return audio

    def test_service_discovery_and_verified_write_signatures(self):
        audio = self.make_audio()
        self.assertTrue(audio.available)
        self.assertEqual(audio.volume, 0.65)
        audio.setVolume(0.3); audio.setMuted(True)
        writes = [call for call in self.calls if call[2] != 'Get']
        self.assertEqual(writes, [
            ('/org/deepin/dde/Audio1/Sink7', 'org.deepin.dde.Audio1.Sink', 'SetVolume', [0.3, False]),
            ('/org/deepin/dde/Audio1/Sink7', 'org.deepin.dde.Audio1.Sink', 'SetMute', [True])])
        self.assertEqual(audio.volume, 0.3); self.assertTrue(audio.muted)

    def test_unavailable_device_and_disconnect_disable_writes(self):
        audio = self.make_audio()
        self.values['DefaultSink'] = '/'
        audio.refresh()
        self.assertFalse(audio.available)
        count = len(self.calls)
        audio.setVolume(0.9); audio.setMuted(False)
        self.assertEqual(len(self.calls), count)

    def test_errors_and_invalid_values_do_not_fake_success(self):
        audio = self.make_audio(); errors = []
        audio.error.connect(errors.append)
        count = len(self.calls)
        for value in [-1, 1.1, float('nan'), float('inf')]: audio.setVolume(value)
        self.assertEqual(len(self.calls), count)
        self.assertEqual(len(errors), 4)
        audio._transport = lambda path, interface, method, args, callback: callback(None, 'Device vanished')
        audio.setVolume(0.4)
        self.assertFalse(audio.available)
        self.assertIn('Device vanished', errors[-1])

    def test_opt_in_and_shutdown_boundaries(self):
        audio = DdeAudio(False, transport=lambda *_: self.fail('Host service was called'))
        audio.refresh(); audio.setVolume(0.5); audio.setMuted(True)
        self.assertFalse(audio.available)
        audio = self.make_audio(); audio.stop()
        count = len(self.calls)
        audio.refresh(); audio.setVolume(0.1)
        self.assertEqual(len(self.calls), count)


if __name__ == '__main__': unittest.main()
