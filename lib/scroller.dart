import 'dart:async';
import 'package:flutter/material.dart';

class Scroller {
  Timer? periodic;
  Function? onUpdate;
  Function? onDone;
  ScrollController? scrollController;

  double speed = 1.0;
  double direction = 1.0;

  void start({
    ScrollController? scrollController,
    Function? onUpdate,
    Function? onDone,
  }) {
    this.scrollController = scrollController;
    this.onUpdate = onUpdate;
    this.onDone = onDone;
    periodic ??= Timer.periodic(const Duration(milliseconds: 25), (timer) {
      update();
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
