class CaptureGate {
  var _busy = false;

  bool tryEnter() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  void leave() {
    _busy = false;
  }
}
