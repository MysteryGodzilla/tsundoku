/// A hybrid logical clock: wall-clock milliseconds, a counter for changes in the same millisecond
/// (or when a device's clock is behind one it has heard from), and the device id as a tie-break.
/// Its strings sort in time order, so "the later change wins" is a plain string comparison.
library;

class Hlc {
  Hlc(this.device, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final String device;
  final DateTime Function() _clock;
  int _ms = 0;
  int _counter = 0;

  static String format(int ms, int counter, String device) =>
      '${ms.toString().padLeft(15, '0')}:${counter.toString().padLeft(5, '0')}:$device';

  static (int, int) parse(String hlc) {
    final p = hlc.split(':');
    return (int.parse(p[0]), int.parse(p[1]));
  }

  /// A stamp for a new local change.
  String next() {
    final now = _clock().millisecondsSinceEpoch;
    if (now > _ms) {
      _ms = now;
      _counter = 0;
    } else {
      _counter++;
    }
    return format(_ms, _counter, device);
  }

  /// Hearing of a change from another device moves this clock past it.
  void observe(String remote) {
    final (ms, counter) = parse(remote);
    if (ms > _ms || (ms == _ms && counter > _counter)) {
      _ms = ms;
      _counter = counter;
    }
  }
}
