class RetryBackoff {
  static const List<Duration> defaultDelays = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 10),
    Duration(minutes: 15),
  ];

  final List<Duration> delays;
  int _attempt = 0;

  RetryBackoff({this.delays = defaultDelays}) {
    if (delays.isEmpty) {
      throw ArgumentError.value(delays, 'delays', 'No puede estar vacío.');
    }
  }

  Duration nextDelay() {
    final index = _attempt < delays.length ? _attempt : delays.length - 1;
    _attempt++;
    return delays[index];
  }

  void reset() => _attempt = 0;
}
