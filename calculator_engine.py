"""Bounded arithmetic/scientific calculator. AST is interpreted; Python is never evaluated.

Arithmetic and decimal scientific functions use 28 decimal digits. Trigonometric
and hyperbolic functions use the platform math library, rounded to 15 significant
digits; their large-argument precision is intentionally bounded.
"""
import ast
from decimal import Decimal, localcontext
import math
import operator
import re

MAX_EXPRESSION = 500
MAX_NODES = 150
MAX_DEPTH = 40
MAX_MAGNITUDE = Decimal('1e100')
CONSTANTS = {'pi': Decimal('3.141592653589793238462643383'), 'e': Decimal('2.718281828459045235360287471')}


def evaluate(expression, angle_mode='degrees'):
    if angle_mode not in ('degrees', 'radians'):
        raise ValueError('Unknown angle mode')
    if not isinstance(expression, str) or not expression.strip() or len(expression) > MAX_EXPRESSION:
        raise ValueError('Expression is empty or too long')
    source = expression.replace('×', '*').replace('÷', '/').replace('−', '-').replace('π', 'pi').replace('^', '**')
    # Decimal literals only: reject Python's binary/octal/hex and underscore syntax.
    if '_' in source or re.search(r'\b0[xob]', source, re.I):
        raise ValueError('Unsupported numeric syntax')
    tree = ast.parse(source, mode='eval')
    if sum(1 for _ in ast.walk(tree)) > MAX_NODES:
        raise ValueError('Expression is too complex')

    def bounded(value):
        if not value.is_finite() or abs(value) > MAX_MAGNITUDE:
            raise ValueError('Number is outside the supported range')
        return value

    def floating(value):
        if not math.isfinite(value):
            raise ValueError('Result is not finite')
        return Decimal(format(value, '.15g'))

    def power(base, exponent):
        if abs(exponent) > 1000:
            raise ValueError('Exponent is outside the supported range')
        if base < 0 and exponent != exponent.to_integral_value():
            raise ValueError('The result is not a real number')
        return bounded(base ** exponent)

    def function(name, args):
        if name == 'root' and len(args) == 2:
            value, degree = args
            if degree == 0 or abs(degree) > 1000:
                raise ValueError('Invalid root degree')
            if value < 0:
                if degree != degree.to_integral_value() or int(degree) % 2 == 0:
                    raise ValueError('The result is not a real number')
                return -floating(float(abs(value)) ** (1.0 / float(degree)))
            return floating(float(value) ** (1.0 / float(degree)))
        if len(args) != 1:
            raise ValueError('This function needs one argument')
        value = args[0]
        if name == 'sqrt': return value.sqrt()
        if name == 'cbrt': return floating(math.copysign(abs(float(value)) ** (1.0 / 3), float(value)))
        if name == 'abs': return abs(value)
        if name == 'ln': return value.ln()
        if name in ('log', 'log10'): return value.log10()
        if name == 'log2': return value.ln() / Decimal(2).ln()
        if name == 'exp':
            if value > 231: raise ValueError('Exponent is outside the supported range')
            return value.exp()
        if name == 'factorial':
            if value != value.to_integral_value() or value < 0 or value > 69:
                raise ValueError('Factorial needs an integer from 0 to 69')
            return Decimal(math.factorial(int(value)))
        if name in ('sin', 'cos', 'tan'):
            if abs(value) > Decimal('1e12'):
                raise ValueError('Angle is outside the supported range')
            if angle_mode == 'degrees':
                reduced = value % 360
                if name == 'sin' and reduced % 180 == 0: return Decimal(0)
                if name == 'cos' and (abs(reduced) % 180) == 90: return Decimal(0)
                if name == 'tan' and reduced % 180 == 0: return Decimal(0)
                if name == 'tan' and abs(reduced) % 180 == 90: raise ValueError('Tangent is undefined at this angle')
                radians = math.radians(float(reduced))
            else:
                radians = float(value)
            return floating(getattr(math, name)(radians))
        if name in ('asin', 'acos', 'atan'):
            radians = getattr(math, name)(float(value))
            return floating(math.degrees(radians) if angle_mode == 'degrees' else radians)
        if name in ('sinh', 'cosh', 'tanh', 'asinh', 'acosh', 'atanh'):
            if abs(value) > 230 and name in ('sinh','cosh'):
                raise ValueError('Argument is outside the supported range')
            return floating(getattr(math, name)(float(value)))
        raise ValueError('Unknown function: ' + name)

    functions = {'sqrt','cbrt','abs','ln','log','log10','log2','exp','factorial','sin','cos','tan','asin','acos','atan','sinh','cosh','tanh','asinh','acosh','atanh','root'}
    operations = {ast.Add:operator.add, ast.Sub:operator.sub, ast.Mult:operator.mul, ast.Div:operator.truediv, ast.Pow:power}

    def visit(node, depth=0):
        if depth > MAX_DEPTH: raise ValueError('Expression is nested too deeply')
        if isinstance(node, ast.Constant) and type(node.value) in (int, float):
            value = Decimal(ast.get_source_segment(source, node))
        elif isinstance(node, ast.Name) and node.id in CONSTANTS:
            value = CONSTANTS[node.id]
        elif isinstance(node, ast.BinOp) and type(node.op) in operations:
            value = operations[type(node.op)](visit(node.left, depth+1), visit(node.right, depth+1))
        elif isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
            value = visit(node.operand, depth+1) * (-1 if isinstance(node.op, ast.USub) else 1)
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id in functions and not node.keywords:
            value = function(node.func.id, [visit(arg, depth+1) for arg in node.args])
        else:
            raise ValueError('Only calculator expressions are supported')
        return bounded(value)

    with localcontext() as context:
        context.prec = 28
        value = visit(tree.body).normalize()
        if value == 0: return '0'
        return format(value, 'f') if Decimal('1e-16') <= abs(value) < Decimal('1e16') else str(value)
