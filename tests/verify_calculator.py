"""Isolated QML calculator verification; no interaction with the user's desktop."""
import os,sys,json
os.environ['QT_QPA_PLATFORM']='offscreen';os.environ['QT_QUICK_CONTROLS_STYLE']='Basic'
from pathlib import Path
from PySide6.QtCore import QObject,Property,Slot,QUrl,Qt,QPoint,QPointF
from PySide6.QtGui import QGuiApplication,QFont
from PySide6.QtQuick import QQuickItem,QQuickWindow
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtTest import QTest
import shiboken6
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root))
from calculator_engine import evaluate
class Store(QObject):
 def __init__(self):super().__init__();self.prefs={}
 @Slot(str,str,result=str)
 def preference(self,key,default):return self.prefs.get(key,default)
 @Slot(str,str)
 def setPreference(self,key,value):self.prefs[key]=value
 @Slot(str,result='QVariantMap')
 def evaluate(self,value):return self.evaluateScientific(value,'degrees')
 @Slot(str,str,result='QVariantMap')
 def evaluateScientific(self,value,angle):
  try:return {'ok':True,'value':evaluate(value,angle)}
  except (ValueError,ArithmeticError,SyntaxError):return {'ok':False,'value':'Error'}
class Bridge(QObject):
 def __init__(self):super().__init__();self.store=Store();self.copied=''
 @Property(QObject,constant=True)
 def suite(self):return self.store
 @Slot(str)
 def copyText(self,value):self.copied=value
 @Property(str,constant=True)
 def assetRoot(self):return QUrl.fromLocalFile(str(root/'assets')).toString()+'/'
app=QGuiApplication([]);app.setFont(QFont('.AppleSystemUIFont',13));bridge=Bridge();engine=QQmlApplicationEngine();errors=[]
engine.warnings.connect(lambda items:errors.extend(str(e) for e in items));engine.rootContext().setContextProperty('Bridge',bridge)
engine.loadData(b'''import QtQuick
import QtQuick.Controls
ApplicationWindow { width:1360;height:850;visible:true
 QtObject { id:desk; property int width:1360; property bool reduceMotion:true; function openApplication(id){} }
 Item { id:holder;objectName:"host";x:100;y:50;width:340;height:540;property bool active:true;property bool isFullscreen:false;property int minimumWindowWidth:300;property int minimumWindowHeight:480;property bool dark:true;property color ink:"white";property color muted:"gray";property var desktop:desk
 CalculatorApp {id:calc;objectName:"calculator";anchors.fill:parent;host:holder} }
}''',QUrl.fromLocalFile(str(root/'qml/CalculatorVerification.qml')))
assert engine.rootObjects(),errors
window=engine.rootObjects()[0];calc=window.findChild(QObject,'calculator');host=window.findChild(QObject,'host');QTest.qWait(50)
def press(*keys):
 for key in keys:calc.press(key)
def result(expected,*keys):
 press('AC',*keys);assert calc.property('expression')==expected,(keys,calc.property('expression'))
result('220','2','0','0','+','1','0','%','=')
result('20','2','0','0','×','1','0','%','=')
result('8','2','+','3','=','=');press('=');assert calc.property('expression')=='11'
result('5','5','+/−','+/−','=')
result('-52','5','+/−','2','=')
result('-1','2','+','3','+/−','=')
result('2.5','2','+','.','5','=')
result('0.3','0','.','1','+','0','.','2','=')
result('1.23','1','.','2','.','3','=')
result('Error','1','÷','0','=');press('7');assert calc.property('expression')=='7'
result('5','2','+','3','=');calc.command('copyExpression');assert bridge.copied=='2+3';calc.command('copyResult');assert bridge.copied=='5'
calc.setMode('scientific');QTest.qWait(10);assert host.width()>=610
result('0.5','sin','3','0','=')
result('0.5','3','0','sin','=')
result('8','2','xʸ','3','=')
result('0.125','2','^','−','3','=')
result('-6','2','×','−','3','=')
result('3','9','√x','=')
result('120','5','x!','=')
result('0.002','2','EE','−','3','=')
calc.setAngle('radians');result('1','π','÷','2','=','sin','=')
calc.setAngle('degrees');press('AC','mc','5','m+','AC','2','m+','AC','mr','=');assert calc.property('expression')=='7'
assert bridge.store.prefs['calculator.memory']=='7'
calc.command('history');assert calc.property('historyVisible');assert host.width()>=800
calc.command('history');calc.setMode('basic');assert host.width()==340
calc.command('mode:programmer');assert calc.property('mode')=='basic'
press('AC');calc.forceActiveFocus();window.requestActivate();QTest.qWait(20)
QTest.keyClick(window,Qt.Key_7);QTest.keyClick(window,Qt.Key_Asterisk);QTest.keyClick(window,Qt.Key_8);QTest.keyClick(window,Qt.Key_Return)
assert calc.property('expression')=='56',calc.property('expression')
def items(item):
 for child in item.childItems():
  yield child
  yield from items(child)
press('AC');QTest.qWait(20);buttons=[o for o in items(calc) if o.inherits('QQuickAbstractButton') and o.property('text')=='7'];assert buttons
button=buttons[0];point=button.mapToScene(QPointF(button.width()/2,button.height()/2))
QTest.mouseClick(window,Qt.LeftButton,Qt.NoModifier,QPoint(round(point.x()),round(point.y())))
assert calc.property('expression')=='7',calc.property('expression')
assert len(json.loads(bridge.store.prefs['calculator.history']))>=15
assert not errors,'\n'.join(errors)
calc.flush();window.close();shiboken6.delete(engine)
print('Calculator QML passed: signs, decimals, contextual percent, repeated equals, error recovery, history copy, scientific functions, angle modes, exponent entry, memory, resizing, real keyboard and button input.')
