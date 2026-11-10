"""Chess worker/controller integration, using an isolated SQLite store and Qt loop.

The real opponent is exercised once. Gated legal replies make races reproducible
without timing a CPU search or touching any GUI, camera, or network service.
"""
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import threading
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    import chess
    from PySide6.QtCore import QCoreApplication
    from PySide6.QtTest import QTest
    import suite as suite_module
    from suite import Suite, ChessGame
    HAS_CHESS_QT = True
except ImportError:
    HAS_CHESS_QT = False


@unittest.skipUnless(HAS_CHESS_QT, 'Run with the project Qt/chess environment')
class ChessAsyncTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.app = QCoreApplication.instance() or QCoreApplication([])

    def setUp(self):
        self.temporary = TemporaryDirectory()
        self.suite = Suite(self.temporary.name)
        self.game = ChessGame(self.suite)
        self.gates = []
        self.closed = False
        self.errors = []
        self.suite.error.connect(self.errors.append)

    def tearDown(self):
        self.game.shutdown()
        for gate in self.gates:
            gate.set()
        if self.game._executor:
            self.game._executor.shutdown(wait=True, cancel_futures=True)
        self.app.processEvents()
        self.suite._downloads.close()
        if not self.closed:
            self.suite.db.close()
        self.temporary.cleanup()

    def until(self, condition, timeout_ms=5000):
        deadline = time.monotonic() + timeout_ms / 1000
        while not condition() and time.monotonic() < deadline:
            QTest.qWait(10)
        self.assertTrue(condition(), 'The bounded Qt/worker operation did not complete')

    def move(self, uci):
        move = chess.Move.from_uci(uci)
        self.game.select(move.from_square)
        self.game.select(move.to_square)

    def gated_worker(self, reply='b8c6'):
        started, release, finished = threading.Event(), threading.Event(), threading.Event()
        self.gates.append(release)
        def worker(position, budget):
            move = chess.Move.from_uci(reply)
            if move not in position.legal_moves:
                raise AssertionError('The test reply must be legal in its captured position')
            started.set()
            try:
                if not release.wait(4):
                    raise AssertionError('Test failed to release its worker')
                return move
            finally:
                finished.set()
        return worker, started, release, finished

    def start_white_opening(self):
        self.game.setComputer(True)
        self.move('e2e4')
        self.assertTrue(self.game.thinking)
        self.assertEqual([move.uci() for move in self.game.board.move_stack], ['e2e4'])

    def test_real_bounded_reply_is_legal_persisted_on_qt_thread_and_undoes_two_plies(self):
        main_thread = threading.get_ident()
        observations, writes = [], []
        choose = suite_module.choose_move
        save = self.suite.setPreference
        def observed_search(board, budget):
            before = board.fen()
            result = choose(board, budget)
            observations.append((threading.get_ident(), budget, before, board.fen()))
            return result
        def observed_save(key, value):
            writes.append(threading.get_ident())
            return save(key, value)
        with patch.object(suite_module, 'choose_move', side_effect=observed_search), patch.object(self.suite, 'setPreference', side_effect=observed_save):
            self.start_white_opening()
            before_reply = self.game.board.copy(stack=True)
            self.until(lambda: len(self.game.board.move_stack) == 2 and not self.game.thinking)
            reply = self.game.board.peek()
            self.assertIn(reply, before_reply.legal_moves)
            self.assertEqual(self.game.board.turn, chess.WHITE)
            self.assertTrue(self.game.board.is_valid())
            self.assertEqual(json.loads(self.suite.preference('chess.moves', '[]')), ['e2e4', reply.uci()])
            self.assertEqual(len(observations), 1)
            worker_thread, budget, start, end = observations[0]
            self.assertNotEqual(worker_thread, main_thread)
            self.assertEqual(budget, 3000)
            self.assertEqual(start, end, 'Search must not mutate its supplied position')
            self.assertTrue(writes)
            self.assertEqual(set(writes), {main_thread}, 'SQLite writes must stay on the Qt thread')
            self.game.undo()
            self.assertEqual(self.game.board.fen(), chess.STARTING_FEN)
            self.assertFalse(self.game.thinking)
            self.assertEqual(json.loads(self.suite.preference('chess.moves', '[]')), [])
        self.assertEqual(self.errors, [])

    def test_new_game_cancels_running_reply_and_keeps_reset_position(self):
        worker, started, release, finished = self.gated_worker()
        with patch.object(suite_module, 'choose_move', side_effect=worker):
            self.start_white_opening(); self.until(started.is_set)
            self.game.newGame()
            self.assertFalse(self.game.thinking)
            self.assertFalse(self.game._poll.isActive())
            self.assertEqual(self.game.board.fen(), chess.STARTING_FEN)
            release.set(); self.until(finished.is_set); QTest.qWait(70)
            self.assertEqual(self.game.board.fen(), chess.STARTING_FEN)
            self.assertEqual(json.loads(self.suite.preference('chess.moves', '[]')), [])

    def test_undo_while_thinking_cancels_one_pending_turn(self):
        worker, started, release, finished = self.gated_worker()
        with patch.object(suite_module, 'choose_move', side_effect=worker):
            self.start_white_opening(); self.until(started.is_set)
            self.game.undo()
            self.assertFalse(self.game.thinking)
            self.assertFalse(self.game.canUndo)
            release.set(); self.until(finished.is_set); QTest.qWait(70)
            self.assertEqual(self.game.board.fen(), chess.STARTING_FEN)
            self.assertEqual(self.suite.preference('chess.moves', '[]'), '[]')

    def test_switching_to_two_players_cancels_reply_and_allows_manual_black_move(self):
        worker, started, release, finished = self.gated_worker()
        with patch.object(suite_module, 'choose_move', side_effect=worker):
            self.start_white_opening(); self.until(started.is_set)
            self.game.setComputer(False)
            self.assertFalse(self.game.versusComputer)
            self.assertFalse(self.game.thinking)
            self.assertEqual(self.suite.preference('chess.computer', ''), 'false')
            self.move('e7e5')
            release.set(); self.until(finished.is_set); QTest.qWait(70)
            self.assertEqual([move.uci() for move in self.game.board.move_stack], ['e2e4','e7e5'])
            self.assertEqual(self.game.board.turn, chess.WHITE)

    def test_stale_reply_cannot_apply_to_new_search_even_when_position_matches(self):
        started_first, started_second = threading.Event(), threading.Event()
        release_first, release_second = threading.Event(), threading.Event()
        self.gates.extend([release_first, release_second])
        positions = []
        def worker(board, budget):
            positions.append(board.fen())
            ordinal = len(positions)
            gate, started, move = (release_first, started_first, 'b8c6') if ordinal == 1 else (release_second, started_second, 'g8f6')
            started.set()
            if not gate.wait(4): raise AssertionError('Test failed to release worker')
            result = chess.Move.from_uci(move)
            if result not in board.legal_moves: raise AssertionError('Test reply must be legal')
            return result
        with patch.object(suite_module, 'choose_move', side_effect=worker):
            self.start_white_opening(); self.until(started_first.is_set)
            self.game.newGame()
            self.move('e2e4')
            self.assertTrue(self.game.thinking)
            release_first.set(); self.until(started_second.is_set); QTest.qWait(70)
            self.assertEqual(len(positions), 2)
            self.assertEqual(positions[0], positions[1])
            self.assertEqual([move.uci() for move in self.game.board.move_stack], ['e2e4'])
            self.assertTrue(self.game.thinking, 'The current worker is still pending')
            release_second.set(); self.until(lambda: not self.game.thinking)
            self.assertEqual([move.uci() for move in self.game.board.move_stack], ['e2e4','g8f6'])
            self.assertEqual(json.loads(self.suite.preference('chess.moves', '[]')), ['e2e4','g8f6'])

    def test_changed_position_rejects_a_still_legal_stale_move(self):
        worker, started, release, finished = self.gated_worker()
        with patch.object(suite_module, 'choose_move', side_effect=worker):
            self.start_white_opening(); self.until(started.is_set)
            # Exercise the position guard independently of explicit cancellation.
            replacement = chess.Board(); replacement.push_uci('d2d4')
            self.assertIn(chess.Move.from_uci('b8c6'), replacement.legal_moves)
            self.game.board = replacement
            release.set(); self.until(lambda: not self.game.thinking)
            self.assertEqual([move.uci() for move in self.game.board.move_stack], ['d2d4'])
            self.assertEqual(json.loads(self.suite.preference('chess.moves', '[]')), ['e2e4'])

    def test_claimed_draw_cancels_pending_computer_reply(self):
        for move in ['g1f3','g8f6','f3g1','f6g8','g1f3','g8f6','f3g1']:
            self.move(move)
        self.assertTrue(self.game.canClaimDraw)
        before = self.game.board.fen()
        worker, started, release, finished = self.gated_worker()
        with patch.object(suite_module, 'choose_move', side_effect=worker):
            self.game.setComputer(True); self.until(started.is_set)
            self.game.claimDraw()
            self.assertFalse(self.game.canClaimDraw)
            self.assertFalse(self.game.thinking)
            release.set(); self.until(finished.is_set); QTest.qWait(70)
            self.assertEqual(self.game.board.fen(), before)
            self.assertEqual(len(self.game.board.move_stack), 7)
            self.assertTrue(self.game.status.startswith('Draw'))
            self.assertEqual(self.suite.preference('chess.drawClaimed', ''), 'true')

    def test_shutdown_drops_pending_results_before_database_is_closed(self):
        worker, started, release, finished = self.gated_worker()
        writes_after_close = []
        save = self.suite.setPreference
        def guarded_save(key, value):
            if self.closed:
                writes_after_close.append((key, value))
                return
            return save(key, value)
        with patch.object(suite_module, 'choose_move', side_effect=worker), patch.object(self.suite, 'setPreference', side_effect=guarded_save):
            self.start_white_opening(); self.until(started.is_set)
            pending = self.game._future
            before = self.game.board.fen()
            self.game.shutdown()
            self.assertFalse(self.game.thinking)
            self.assertFalse(self.game._poll.isActive())
            self.assertFalse(pending.done(), 'Shutdown should not wait on a blocked worker')
            self.suite.db.close(); self.closed = True
            release.set(); self.until(finished.is_set); self.until(pending.done); QTest.qWait(70)
            self.assertEqual(writes_after_close, [])
            self.assertEqual(self.game.board.fen(), before)
            self.assertTrue(self.game._stopping)
        self.assertEqual(self.errors, [])

if __name__ == '__main__': unittest.main()
