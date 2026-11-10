import sys
from pathlib import Path
import unittest
from decimal import Decimal
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from calculator_engine import evaluate

class CalculatorEngineTests(unittest.TestCase):
    def test_exact_decimal_arithmetic_and_operator_precedence(self):
        self.assertEqual(evaluate('0.1+0.2'), '0.3')
        self.assertEqual(evaluate('0.123456789123456789+0.000000000000000001'), '0.12345678912345679')
        self.assertEqual(evaluate('2+3×4'), '14')
        self.assertEqual(evaluate('-(2+3)×4+8÷2'), '-16')
        self.assertEqual(evaluate('9999999999999999+1'), '1E+16')
        self.assertEqual(evaluate('2^3^2'), '512')

    def test_scientific_functions_and_angle_modes(self):
        self.assertEqual(evaluate('sin(30)'), '0.5')
        self.assertEqual(evaluate('cos(60)'), '0.5')
        self.assertEqual(evaluate('sin(180)'), '0')
        self.assertEqual(evaluate('cos(90)'), '0')
        self.assertEqual(evaluate('tan(180)'), '0')
        self.assertEqual(evaluate('asin(0.5)'), '30')
        self.assertEqual(evaluate('sin(pi/2)', 'radians'), '1')
        self.assertEqual(evaluate('atan(1)', 'degrees'), '45')
        self.assertAlmostEqual(float(evaluate('atan(1)', 'radians')), 0.7853981633974483, places=14)
        self.assertEqual(evaluate('sqrt(81)'), '9')
        self.assertEqual(evaluate('cbrt(-8)'), '-2')
        self.assertEqual(evaluate('root(-32,5)'), '-2')
        self.assertEqual(evaluate('ln(exp(2))'), '2')
        self.assertEqual(evaluate('log10(1000)'), '3')
        self.assertEqual(evaluate('log2(1024)'), '10')
        self.assertEqual(evaluate('factorial(10)'), '3628800')
        self.assertEqual(evaluate('2^-3'), '0.125')

    def test_domains_are_rejected_without_inventing_results(self):
        for expr in ('1/0','sqrt(-1)','ln(0)','log(-10)','asin(2)','tan(90)','factorial(-1)','factorial(2.5)','factorial(70)','root(-16,2)','root(4,0)','(-2)^0.5'):
            with self.subTest(expr=expr), self.assertRaises((ValueError,ArithmeticError)):
                evaluate(expr)

    def test_code_execution_and_unbounded_work_are_rejected(self):
        for expr in ('__import__("os").getcwd()','open("file")','(1).__class__','[1,2]','True','0x10','2**100000','factorial(1000000)','1e101','2+'*300+'1','sin(1e13)','sqrt(x=4)'):
            with self.subTest(expr=expr), self.assertRaises((ValueError,ArithmeticError,SyntaxError)):
                evaluate(expr)
        with self.assertRaises(ValueError): evaluate('1','gradians')

    def test_small_values_remain_bounded_display_strings(self):
        result=evaluate('1e-999')
        self.assertEqual(Decimal(result),Decimal('1e-999'))
        self.assertLess(len(result),20)

if __name__ == '__main__': unittest.main()
