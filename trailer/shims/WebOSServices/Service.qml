// desktop stand-in for LG's luna Service (demo rendering only)
import QtQml 2.12
QtObject {
    property string appId: ""
    property string service: ""
    property string method: ""
    signal response(string payload)
    signal callSuccess(var response)
    function call(a, b, c) {}
    function callService(params) {}
}
