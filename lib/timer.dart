import 'dart:async';
import 'package:flutter/material.dart';

class PeriodicTimer {
  Timer? periodic;
  Function? onUpdate;
  Function? onDone;

  double scale = 1.0;
  double speed = 1.0;
  double direction = 1.0;
  int loops = 0;

  void start({
    double scale = 1.0,
    Function? onUpdate,
    Function? onDone,
  }) {
    this.onUpdate = onUpdate;
    this.onDone = onDone;
    this.scale = scale;
    loops = 0;
    periodic ??=
        Timer.periodic(Duration(milliseconds: (25 * scale).toInt()), (timer) {
      update();
      if (loops++ > 200) cancel();
    });
  }

  void update() {
    if (!(onUpdate?.call() ?? false)) {
      cancel();
    }
  }

  void cancel() {
    if (periodic != null) {
      periodic?.cancel();
      periodic = null;
      onDone?.call();
    }
  }

  bool isRunning() {
    return (periodic != null);
  }
}
