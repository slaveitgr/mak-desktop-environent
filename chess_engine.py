"""A small local opponent for the desktop Chess prototype.

Deterministic iterative-deepening alpha-beta search, up to three plies, with a
shared visited-position budget. Only python-chess legal moves are considered.
This is a lightweight opponent, not a substitute for a tournament chess engine.
The caller's board, including its history, is never mutated.
"""
from dataclasses import dataclass
from typing import Optional

import chess

MATE_SCORE = 100_000
_INFINITY = MATE_SCORE * 2
_VALUES = {chess.PAWN: 100, chess.KNIGHT: 320, chess.BISHOP: 335,
           chess.ROOK: 500, chess.QUEEN: 900, chess.KING: 0}


@dataclass(frozen=True)
class SearchResult:
    move: Optional[chess.Move]
    nodes: int
    depth: int
    score: Optional[int]


class _BudgetExceeded(Exception):
    pass


@dataclass
class _SearchState:
    limit: int
    nodes: int = 0

    def visit(self):
        if self.nodes >= self.limit:
            raise _BudgetExceeded()
        self.nodes += 1


def _centrality(square):
    file = chess.square_file(square)
    rank = chess.square_rank(square)
    return min(file, 7-file) + min(rank, 7-rank)


def _evaluate(board):
    """Material plus modest piece-square preferences, from White's perspective."""
    pieces = board.piece_map()
    nonpawn_material = sum(_VALUES[p.piece_type] for p in pieces.values()
                           if p.piece_type != chess.PAWN)
    endgame = nonpawn_material < 2400
    result = 0
    for square, piece in pieces.items():
        file = chess.square_file(square)
        rank = chess.square_rank(square)
        own_rank = rank if piece.color == chess.WHITE else 7-rank
        center = _centrality(square)
        bonus = 0
        if piece.piece_type == chess.PAWN:
            bonus = own_rank * 7 + min(file, 7-file) * 4
            if file in (3, 4) and own_rank in (3, 4):
                bonus += 16
        elif piece.piece_type == chess.KNIGHT:
            bonus = center * 9 + (14 if own_rank > 0 else 0)
            if file in (0, 7):
                bonus -= 12
        elif piece.piece_type == chess.BISHOP:
            bonus = center * 5 + own_rank * 2
        elif piece.piece_type == chess.ROOK:
            bonus = own_rank * 2
        elif piece.piece_type == chess.QUEEN:
            bonus = center * 3
            if board.fullmove_number < 10 and own_rank > 1:
                bonus -= 18
        elif piece.piece_type == chess.KING:
            bonus = center * 9 if endgame else -min(file, 7-file) * 8-own_rank * 7
            if not endgame and own_rank == 0 and file in (2, 6):
                bonus += 25
        value = _VALUES[piece.piece_type] + bonus
        result += value if piece.color == chess.WHITE else -value
    return result


def _move_priority(board, move, preferred=None):
    if move == preferred:
        return 1_000_000
    priority = 0
    attacker = board.piece_at(move.from_square)
    victim = board.piece_at(move.to_square)
    if board.is_en_passant(move):
        victim = chess.Piece(chess.PAWN, not board.turn)
    if victim:
        priority += 10 * _VALUES[victim.piece_type] - _VALUES[attacker.piece_type]
    if move.promotion:
        priority += 8 * _VALUES[move.promotion]
    if board.is_castling(move):
        priority += 50
    priority += 3 * (_centrality(move.to_square)-_centrality(move.from_square))
    if attacker and attacker.piece_type in (chess.BISHOP, chess.KNIGHT):
        home_rank = 0 if attacker.color == chess.WHITE else 7
        if chess.square_rank(move.from_square) == home_rank:
            priority += 20
    return priority


def _ordered_moves(board, preferred=None):
    # Lexicographic UCI order resolves every remaining tie reproducibly.
    return sorted(board.legal_moves,
                  key=lambda move: (-_move_priority(board, move, preferred), move.uci()))


def _terminal_score(board, ply):
    # Claimable repetition/fifty-move draws are player decisions. Automatic
    # endings remain authoritative; root ChessGame owns explicit draw claims.
    outcome = board.outcome(claim_draw=False)
    if outcome is None:
        return None
    if outcome.winner is None:
        return 0
    value = MATE_SCORE-ply
    return value if outcome.winner == board.turn else -value


def _negamax(board, depth, alpha, beta, ply, state):
    state.visit()
    terminal = _terminal_score(board, ply)
    if terminal is not None:
        return terminal
    if depth == 0:
        value = _evaluate(board)
        return value if board.turn == chess.WHITE else -value
    best = -_INFINITY
    for move in _ordered_moves(board):
        board.push(move)
        try:
            score = -_negamax(board, depth-1, -beta, -alpha, ply+1, state)
        finally:
            board.pop()
        best = max(best, score)
        alpha = max(alpha, score)
        if alpha >= beta:
            break
    return best


def _search_root(board, depth, preferred, state):
    state.visit()
    best_move = None
    best_score = -_INFINITY
    alpha = -_INFINITY
    for move in _ordered_moves(board, preferred):
        board.push(move)
        try:
            score = -_negamax(board, depth-1, -_INFINITY, -alpha, 1, state)
        finally:
            board.pop()
        if score > best_score:
            best_move, best_score = move, score
        alpha = max(alpha, score)
    return best_move, best_score


def analyse_position(board, max_nodes=3000):
    """Return a move and search diagnostics without mutating ``board``.

    ``nodes`` counts searched positions, including iterative-deepening roots,
    and never exceeds ``max_nodes``. Static root validation and move ordering
    are outside that count. A zero budget returns a deterministic legal move.
    If an iteration runs out of budget, its incomplete results are discarded
    in favor of the last fully completed depth. All scores are centipawns from
    the root side's perspective; mate scores use ``MATE_SCORE - plies``.
    """
    if not isinstance(max_nodes, int) or max_nodes < 0:
        raise ValueError('max_nodes must be a nonnegative integer')
    position = board.copy(stack=True)
    if position.is_game_over(claim_draw=False):
        return SearchResult(None, 0, 0, _terminal_score(position, 0))
    moves = _ordered_moves(position)
    if not moves:
        return SearchResult(None, 0, 0, None)
    state = _SearchState(max_nodes)
    best_move = moves[0]
    best_score = None
    completed_depth = 0
    for depth in range(1, 4):
        try:
            candidate, score = _search_root(position, depth, best_move, state)
        except _BudgetExceeded:
            break
        best_move, best_score = candidate, score
        completed_depth = depth
        if abs(score) >= MATE_SCORE-depth:
            break
    return SearchResult(best_move, state.nodes, completed_depth, best_score)


def choose_move(board, max_nodes=3000):
    """Choose one legal move, or None after an automatic game ending.

    Use a worker thread for UI integration. Tiny budgets can end before the
    two-ply search needed to see an opponent's immediate mating reply.
    """
    return analyse_position(board, max_nodes).move
