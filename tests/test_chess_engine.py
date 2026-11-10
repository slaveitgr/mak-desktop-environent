"""Behavioral positions for the bounded local Chess opponent."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
    import chess
    from chess_engine import analyse_position, choose_move
    HAS_ENGINE = True
except ImportError:
    HAS_ENGINE = False


@unittest.skipUnless(HAS_ENGINE, 'Install the project chess dependency')
class ChessEngineTests(unittest.TestCase):
    def board_after(self, *moves):
        board = chess.Board()
        for move in moves:
            board.push_uci(move)
        return board

    def test_takes_an_available_mate_in_one(self):
        board = self.board_after('f2f3', 'e7e5', 'g2g4')
        move = choose_move(board)
        self.assertIn(move, board.legal_moves)
        board.push(move)
        self.assertTrue(board.is_checkmate())

    def test_defends_against_scholars_mate_threat(self):
        board = self.board_after('e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4')
        move = choose_move(board)
        self.assertIn(move, board.legal_moves)
        board.push(move)
        mating_replies = []
        for reply in list(board.legal_moves):
            board.push(reply)
            if board.is_checkmate():
                mating_replies.append(reply.uci())
            board.pop()
        self.assertEqual(mating_replies, [], f'{move.uci()} allows mate: {mating_replies}')

    def test_checked_king_always_receives_a_legal_evasion(self):
        board = self.board_after('e2e4', 'd7d5', 'f1b5')
        self.assertTrue(board.is_check())
        move = choose_move(board)
        self.assertIn(move, board.legal_moves)
        mover = board.turn
        board.push(move)
        king = board.king(mover)
        self.assertFalse(board.is_attacked_by(not mover, king))

    def test_game_over_returns_none_for_mate_stalemate_and_material_draw(self):
        boards = [
            self.board_after('f2f3','e7e5','g2g4','d8h4'),
            chess.Board('7k/5Q2/5K2/8/8/8/8/8 b - - 0 1'),
            chess.Board('7k/8/8/8/8/8/8/K7 w - - 0 1'),
        ]
        for board in boards:
            with self.subTest(fen=board.fen()):
                self.assertTrue(board.is_game_over())
                self.assertIsNone(choose_move(board))

    def test_input_position_history_castling_and_en_passant_are_unchanged(self):
        board = self.board_after('e2e4','a7a6','e4e5','d7d5')
        original_fen = board.fen(en_passant='fen')
        original_stack = [move.uci() for move in board.move_stack]
        result = analyse_position(board)
        self.assertIn(result.move, board.legal_moves)
        self.assertEqual(board.fen(en_passant='fen'), original_fen)
        self.assertEqual([move.uci() for move in board.move_stack], original_stack)

    def test_position_budget_is_respected_without_timing_assumptions(self):
        board = chess.Board()
        for budget in (0, 1, 30, 100, 3000):
            with self.subTest(budget=budget):
                result = analyse_position(board, max_nodes=budget)
                self.assertLessEqual(result.nodes, budget)
                self.assertGreaterEqual(result.nodes, 0)
                self.assertIn(result.move, board.legal_moves)
                self.assertLessEqual(result.depth, 3)
        self.assertGreaterEqual(analyse_position(board).depth, 2)

    def test_opening_tiebreak_is_deterministic(self):
        board = chess.Board()
        first = choose_move(board, max_nodes=300)
        self.assertEqual(choose_move(board, max_nodes=300), first)

    def test_claimable_draw_remains_playable_until_claimed_by_game_controller(self):
        board = self.board_after('g1f3','g8f6','f3g1','f6g8','g1f3','g8f6','f3g1')
        self.assertTrue(board.can_claim_threefold_repetition())
        self.assertIn(choose_move(board), board.legal_moves)

    def test_invalid_budget_is_rejected(self):
        with self.assertRaises(ValueError): choose_move(chess.Board(), max_nodes=-1)
        with self.assertRaises(ValueError): choose_move(chess.Board(), max_nodes=1.5)


if __name__ == '__main__': unittest.main()
