#!/bin/sh
# qml-check.sh <appId> [qml files...]  (run on the TV)
# qml-runner hides QML errors; this loads each component and prints any error.
# Output: one line per file, "OK" or the error text.
APP=$1; shift
D=/media/developer/apps/usr/palm/applications/$APP
FILES=${*:-$(cd $D && ls *.qml)}
OUT=/tmp/qml-check.txt; rm -f $OUT
LIST=$(for f in $FILES; do printf '"%s",' "$f"; done)
cat > /tmp/qml-check.qml <<Q
import QtQuick 2.12
import QtQuick.Window 2.2
Window { visible: false
  Component.onCompleted: {
    var s = "";
    [${LIST%,}].forEach(function (f) {
      var c = Qt.createComponent("file://$D/" + f);
      s += f + ": " + (c.status === Component.Error ? c.errorString().replace(/\n/g, " | ") : "OK") + "\n";
    });
    var x = new XMLHttpRequest(); x.open("PUT", "file://$OUT", false); x.send(s);
    Qt.quit();
  }
}
Q
QML_XHR_ALLOW_FILE_WRITE=1 QT_QPA_PLATFORM=offscreen /usr/bin/qml-runner "{\"appId\":\"$APP\",\"main\":\"file:///tmp/qml-check.qml\",\"params\":{}}" </dev/null >/dev/null 2>&1 &
P=$!; i=0; while [ ! -s $OUT ] && [ $i -lt 12 ]; do sleep 1; i=$((i+1)); done; kill $P 2>/dev/null
cat $OUT 2>/dev/null || echo "no result (runner failed)"
