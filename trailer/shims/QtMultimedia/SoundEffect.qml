// silent stand-in (demo rendering only; audio is mixed into the video afterwards)
import QtQml 2.12
QtObject {
    enum Loops { Infinite = 999 }
    enum Status { Null, Loading, Ready, Error }
    property url source
    property int loops: 1
    property real volume: 1
    property bool playing: false
    property int status: 2
    function play() { playing = true }
    function stop() { playing = false }
}
