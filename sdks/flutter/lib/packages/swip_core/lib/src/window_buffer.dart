class WindowBuffer<T> {
  final Duration window;
  final Duration hop;
  final List<T> _buf = [];
  DateTime? _anchor;

  WindowBuffer({required this.window, required this.hop});

  /// Add (ts, value). Returns a window slice when ready; else null.
  List<T>? push(DateTime ts, T v, DateTime Function(T) getTs) {
    _buf.add(v);
    _buf.removeWhere((x) => ts.difference(getTs(x)) > window);
    if (_anchor == null) _anchor = ts;
    final elapsed = ts.difference(_anchor!);
    if (elapsed >= hop) {
      _anchor = ts;
      return List.unmodifiable(_buf);
    }
    return null;
  }
}
