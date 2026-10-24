"""Render the Home trailer on a desktop GPU: runs the real home QML (with stand-ins
for LG's Eos.Window / WebOSServices) in record mode. QML_FIXED_ANIMATION_STEP makes
every rendered frame exactly 1/60 s of animation, main.qml saves every 2nd -> 30 fps."""
import os, sys, glob
os.environ["QML_FIXED_ANIMATION_STEP"] = "1"
os.environ["QSG_RENDER_LOOP"] = "windows"        # single-threaded loop with the fixed-step animation driver
os.environ.setdefault("QT_QPA_PLATFORM", "xcb")
os.environ["QML_XHR_ALLOW_FILE_READ"] = "1"
from PySide2.QtCore import QUrl, QTimer, QLocale
from PySide2.QtGui import QGuiApplication, QFontDatabase
from PySide2.QtQml import QQmlApplicationEngine

D = os.path.dirname(os.path.abspath(__file__))
os.environ["LANG"] = "en_GB.UTF-8"; os.environ["LC_ALL"] = "en_GB.UTF-8"
app = QGuiApplication(sys.argv)
QLocale.setDefault(QLocale(QLocale.English, QLocale.UnitedKingdom))   # TV is set to English (en-GB)
for f in glob.glob(os.path.join(D, "fonts", "*.ttf")):
    QFontDatabase.addApplicationFont(f)
eng = QQmlApplicationEngine()
eng.addImportPath(os.path.join(D, "shims"))
eng.warnings.connect(lambda ws: [print("QML:", w.toString()) for w in ws])
eng.load(QUrl.fromLocalFile(os.path.join(D, "build", "app", "main.qml")))
if not eng.rootObjects():
    print("failed to load"); sys.exit(1)
win = eng.rootObjects()[0]
# the grabbed stage stays 1920x1080; shrinking the visible window halves the software-GL work
win.setWidth(192); win.setHeight(108)
state = {"seen": False}

def check():
    rec = win.property("recording")
    if rec:
        state["seen"] = True
    elif state["seen"]:
        print("recording finished, frames:", len(os.listdir(os.path.join(D, "build", "rec"))))
        QTimer.singleShot(1500, app.quit)
        return
    QTimer.singleShot(200, check)

QTimer.singleShot(200, check)
QTimer.singleShot(240000, app.quit)   # safety stop
sys.exit(app.exec_())
