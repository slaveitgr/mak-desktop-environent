"""Persistent application data and user-visible calculator/chess behavior."""
import base64
from email import policy
from email.parser import BytesParser
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    import chess
    from PySide6.QtCore import QCoreApplication, QUrl
    from suite import Suite, ChessGame, calculate
    HAS_SUITE = True
except ImportError:
    HAS_SUITE = False


@unittest.skipUnless(HAS_SUITE, 'Run with the project Qt/chess environment')
class SuiteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.temp = TemporaryDirectory()
        self.root = Path(self.temp.name).resolve() / 'desktop'
        self.root.mkdir()
        self.suite = Suite(self.root)
        self.errors = []
        self.suite.error.connect(self.errors.append)

    def tearDown(self):
        self.suite.db.close()
        self.temp.cleanup()

    def test_unicode_notes_survive_reopen_with_same_identity(self):
        record_id = self.suite.save('notes', '', {'title':'Καλημέρα 🌅', 'body':'Ελληνικά\n日本語\nA second paragraph.'})
        self.assertTrue(record_id)
        self.suite.save('notes', record_id, {'title':'Καληνύχτα 🌙', 'body':'Updated\nΕλληνικά'})
        self.suite.db.close()
        self.suite = Suite(self.root)
        rows = self.suite.records('notes')
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['id'], record_id)
        self.assertEqual(rows[0]['title'], 'Καληνύχτα 🌙')
        self.assertEqual(rows[0]['body'], 'Updated\nΕλληνικά')
        self.assertTrue(rows[0]['modified'])

    def test_invalid_event_does_not_replace_valid_event(self):
        event = {'title':'Birthday', 'date':'2028-02-29', 'time':'18:30', 'list':'Personal'}
        record_id = self.suite.save('calendar', '', event)
        self.assertTrue(record_id)
        self.assertFalse(self.suite.save('calendar', record_id, dict(event, date='2027-02-29')))
        self.assertFalse(self.suite.save('calendar', '', dict(event, time='24:61')))
        self.assertEqual(len(self.suite.records('calendar')), 1)
        self.assertEqual(self.suite.records('calendar')[0]['date'], '2028-02-29')
        self.assertEqual(len(self.errors), 2)

    def test_deletion_is_reversible_and_preserves_fields(self):
        fields = {'title':'Call dentist', 'date':'2026-11-12', 'done':True, 'body':'Bring the form'}
        record_id = self.suite.save('reminders', '', fields)
        self.suite.setDeleted(record_id, True)
        self.assertEqual(self.suite.records('reminders'), [])
        self.assertEqual(self.suite.records('reminders', True)[0]['body'], fields['body'])
        self.suite.setDeleted(record_id, False)
        self.assertEqual(self.suite.records('reminders')[0]['done'], True)
        self.assertEqual(self.suite.records('reminders', True), [])

    def test_cross_application_and_unknown_ids_cannot_overwrite(self):
        record_id = self.suite.save('notes', '', {'title':'Keep me'})
        self.assertEqual(self.suite.save('mail', record_id, {'title':'Overwrite'}), '')
        self.assertEqual(self.suite.save('notes', 'missing-id', {'title':'Overwrite'}), '')
        self.assertEqual(self.suite.save('unknown', '', {'title':'No'}), '')
        self.assertEqual(self.suite.records('notes')[0]['title'], 'Keep me')
        self.assertEqual(self.suite.records('mail'), [])
        self.assertEqual(len(self.errors), 3)

    def test_preference_reopen_and_idempotent_change_notifications(self):
        revision = self.suite.revision
        self.suite.setPreference('sound.volume', '0.35')
        self.assertEqual(self.suite.revision, revision+1)
        self.suite.setPreference('sound.volume', '0.35')
        self.assertEqual(self.suite.revision, revision+1)
        self.suite.db.close()
        self.suite = Suite(self.root)
        self.assertEqual(self.suite.preference('sound.volume', '1'), '0.35')
        self.assertEqual(self.suite.preference('unset', 'fallback'), 'fallback')

    def test_media_import_preserves_existing_photo_and_lists_copies(self):
        source_dir = Path(self.temp.name) / 'chosen'
        source_dir.mkdir()
        source = source_dir / 'Holiday.png'
        image = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aQ0cAAAAASUVORK5CYII=')
        source.write_bytes(image)
        destination = self.root / 'Pictures'
        destination.mkdir()
        (destination/'Holiday.png').write_bytes(b'original photo')
        uri = QUrl.fromLocalFile(str(source)).toString()
        self.assertEqual(self.suite.importMedia([uri], 'photos'), 1)
        self.assertEqual((destination/'Holiday.png').read_bytes(), b'original photo')
        self.assertEqual((destination/'Holiday 2.png').read_bytes(), image)
        self.assertEqual(source.read_bytes(), image)
        self.assertEqual({row['name'] for row in self.suite.media('photos')}, {'Holiday.png','Holiday 2.png'})
        self.assertEqual(self.suite.importMedia([QUrl.fromLocalFile(str(destination/'Holiday.png')).toString()], 'photos'), 0)

    def test_media_does_not_follow_destination_or_library_symlinks(self):
        external = Path(self.temp.name) / 'outside'
        external.mkdir()
        (external/'private.png').write_bytes(b'do not import automatically')
        (self.root/'Pictures').symlink_to(external, target_is_directory=True)
        self.assertEqual(self.suite.media('photos'), [])
        uri = QUrl.fromLocalFile(str(external/'private.png')).toString()
        self.assertEqual(self.suite.importMedia([uri], 'photos'), 0)
        self.assertEqual(self.suite.photoPath(), '')
        self.assertEqual(sorted(p.name for p in external.iterdir()), ['private.png'])
        self.assertTrue(self.errors)

    def test_photo_paths_unique_and_confined(self):
        first, second = Path(self.suite.photoPath()), Path(self.suite.photoPath())
        self.assertNotEqual(first, second)
        self.assertEqual(first.parent, self.root/'Pictures'/'Photo Booth'/'.originals')
        self.assertEqual(first.suffix, '.jpg')
        self.assertFalse(first.exists(), 'Allocating a path must not turn on a camera or create a photo')
        with self.assertRaises(ValueError): self.suite.safe_folder('../outside')
        with self.assertRaises(ValueError): self.suite.safe_folder('/tmp/outside')

    def test_eml_export_roundtrips_unicode_without_sending(self):
        record_id = self.suite.save('mail', '', {'title':'Δοκιμή', 'recipient':'reader@example.test', 'body':'Καλημέρα\nA draft only.'})
        first = Path(self.suite.exportMail(record_id))
        second = Path(self.suite.exportMail(record_id))
        self.assertNotEqual(first, second)
        self.assertEqual(first.parent, self.root/'Documents'/'Mail Drafts')
        message = BytesParser(policy=policy.default).parsebytes(first.read_bytes())
        self.assertEqual(str(message['Subject']), 'Δοκιμή')
        self.assertEqual(str(message['To']), 'reader@example.test')
        self.assertEqual(message.get_content().strip(), 'Καλημέρα\nA draft only.')
        self.assertEqual(len(self.suite.records('mail')), 1)

    def test_web_address_never_navigates_script_or_local_file_schemes(self):
        self.assertEqual(self.suite.webAddress('example.com'), 'https://example.com')
        self.assertEqual(self.suite.webAddress('https://example.com/path'), 'https://example.com/path')
        for value in ('javascript:alert(1)', 'file:///etc/passwd', 'data:text/html,hello'):
            self.assertTrue(self.suite.webAddress(value).startswith('https://duckduckgo.com/?q='))


@unittest.skipUnless(HAS_SUITE, 'Run with the project Qt/chess environment')
class CalculatorTests(unittest.TestCase):
    def test_decimal_arithmetic_precedence_and_unary_sign(self):
        self.assertEqual(calculate('0.1 + 0.2'), '0.3')
        self.assertEqual(calculate('-(2 + 3) × 4 + 8 ÷ 2'), '-16')
        self.assertEqual(calculate('9999999999999999 + 1'), '1E+16')

    def test_long_decimal_literals_keep_their_written_precision(self):
        self.assertEqual(calculate('0.123456789123456789 + 0.000000000000000001'), '0.12345678912345679')

    def test_rejects_code_exponentiation_and_division_by_zero(self):
        with self.assertRaises(ValueError): calculate('__import__("os").getcwd()')
        with self.assertRaises(ValueError): calculate('2 ** 100000')
        with self.assertRaises(ArithmeticError): calculate('1 / 0')
        with self.assertRaises(ValueError): calculate('1+' * 300 + '1')
        with self.assertRaises(ValueError): calculate('1e101')


@unittest.skipUnless(HAS_SUITE, 'Run with the project Qt/chess environment')
class ChessTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.temp = TemporaryDirectory()
        self.suite = Suite(self.temp.name)
        self.game = ChessGame(self.suite)

    def tearDown(self):
        self.suite.db.close()
        self.temp.cleanup()

    def move(self, uci):
        before = len(self.game.board.move_stack)
        self.game.select(chess.parse_square(uci[:2]))
        self.game.select(chess.parse_square(uci[2:4]))
        if len(uci) == 5: self.game.promote(uci[4])
        self.assertEqual(len(self.game.board.move_stack), before+1, uci)

    def test_legal_hints_and_illegal_move_rejection(self):
        self.game.select(chess.E2)
        self.assertEqual({r['name'] for r in self.game.squares if r['legal']}, {'e3','e4'})
        self.game.select(chess.E5)
        self.assertEqual(len(self.game.board.move_stack), 0)
        self.move('e2e4')
        self.assertEqual(self.game.board.piece_at(chess.E4), chess.Piece(chess.PAWN, chess.WHITE))
        self.assertEqual(self.game.status, 'Black to move')

    def test_fools_mate_and_no_moves_after_game_over(self):
        for uci in ('f2f3','e7e5','g2g4','d8h4'): self.move(uci)
        self.assertIn('Black wins', self.game.status)
        self.assertIn('checkmate', self.game.status)
        self.game.select(chess.E2); self.game.select(chess.E4)
        self.assertEqual(len(self.game.board.move_stack), 4)

    def test_castling_moves_both_pieces_and_undo_restores_rights(self):
        for uci in ('e2e4','e7e5','g1f3','b8c6','f1c4','g8f6'): self.move(uci)
        previous = self.game.board.fen()
        self.move('e1g1')
        self.assertEqual(self.game.board.piece_at(chess.G1), chess.Piece(chess.KING, chess.WHITE))
        self.assertEqual(self.game.board.piece_at(chess.F1), chess.Piece(chess.ROOK, chess.WHITE))
        self.assertIsNone(self.game.board.piece_at(chess.H1))
        self.game.undo()
        self.assertEqual(self.game.board.fen(), previous)

    def test_en_passant_removes_the_bypassed_pawn(self):
        for uci in ('e2e4','a7a6','e4e5','d7d5','e5d6'): self.move(uci)
        self.assertIsNone(self.game.board.piece_at(chess.D5))
        self.assertEqual(self.game.board.piece_at(chess.D6), chess.Piece(chess.PAWN, chess.WHITE))
        self.game.undo()
        self.assertEqual(self.game.board.piece_at(chess.D5), chess.Piece(chess.PAWN, chess.BLACK))

    def test_promotion_waits_for_choice_and_supports_underpromotion(self):
        self.game.board = chess.Board('7k/P7/8/8/8/8/8/7K w - - 0 1')
        self.game.select(chess.A7); self.game.select(chess.A8)
        self.assertTrue(self.game.promotionPending)
        self.assertEqual(len(self.game.board.move_stack), 0)
        self.game.promote('x')
        self.assertTrue(self.game.promotionPending)
        self.game.promote('n')
        self.assertFalse(self.game.promotionPending)
        self.assertEqual(self.game.board.piece_at(chess.A8), chess.Piece(chess.KNIGHT, chess.WHITE))
        self.game.undo()
        self.assertEqual(self.game.board.piece_at(chess.A7), chess.Piece(chess.PAWN, chess.WHITE))

    def test_reopen_preserves_game_and_move_history(self):
        for uci in ('e2e4','e7e5','g1f3'): self.move(uci)
        expected = self.game.board.fen()
        self.suite.db.close()
        self.suite = Suite(self.temp.name)
        self.game = ChessGame(self.suite)
        self.assertEqual(self.game.board.fen(), expected)
        self.assertEqual(len(self.game.board.move_stack), 3)
        self.assertTrue(self.game.canUndo)
        self.game.undo()
        self.assertEqual(len(self.game.board.move_stack), 2)

    def test_claimable_repetition_does_not_end_game_without_player_claim(self):
        for uci in ('g1f3','g8f6','f3g1','f6g8','g1f3','g8f6','f3g1'):
            self.move(uci)
        self.assertTrue(self.game.board.can_claim_threefold_repetition())
        self.assertEqual(self.game.status, 'Black to move')
        self.move('f6g8')
        self.assertEqual(self.game.status, 'White to move')

    def test_explicit_draw_claim_survives_reopen_and_undo_reopens_play(self):
        for uci in ('g1f3','g8f6','f3g1','f6g8','g1f3','g8f6','f3g1'):
            self.move(uci)
        self.assertTrue(self.game.canClaimDraw)
        self.game.claimDraw()
        self.assertTrue(self.game.status.startswith('Draw'))
        self.assertFalse(self.game.canClaimDraw)
        self.game.select(chess.F6); self.game.select(chess.G8)
        self.assertEqual(len(self.game.board.move_stack), 7)
        self.suite.db.close()
        self.suite = Suite(self.temp.name)
        self.game = ChessGame(self.suite)
        self.assertTrue(self.game.status.startswith('Draw'))
        self.game.undo()
        self.assertEqual(len(self.game.board.move_stack), 6)
        self.assertEqual(self.game.status, 'White to move')

    def test_new_game_keeps_previous_game_in_archive(self):
        self.move('d2d4');self.move('d7d5')
        self.game.newGame()
        self.assertEqual(self.game.board.fen(), chess.Board().fen())
        self.assertFalse(self.game.canUndo)
        archive = json.loads(self.suite.preference('chess.archive','[]'))
        self.assertEqual(len(archive), 1)
        self.assertIn('1. d4 d5', archive[0]['pgn'])


if __name__ == '__main__': unittest.main()
