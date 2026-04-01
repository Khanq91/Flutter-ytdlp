import 'dart:async';
import 'dart:math';

class FakeProgress {
  double value = 0.0;
  Timer? _timer;

  void start(Function(double) onUpdate) {
    _timer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (value >= 0.95) return;

      if (value < 0.2) {
        value += 0.02;
      } else if (value < 0.5) {
        value += 0.01;
      } else if (value < 0.8) {
        value += 0.005;
      } else {
        value += 0.002;
      }

      value = min(value, 0.95);
      onUpdate(value);
    });
  }

  void complete(Function(double) onUpdate) {
    _timer?.cancel();

    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      value += 0.05;
      if (value >= 1.0) {
        value = 1.0;
        timer.cancel();
      }
      onUpdate(value);
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}