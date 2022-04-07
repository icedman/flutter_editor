import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class StatusProvider extends ChangeNotifier {
  String status = '';
  Timer timer = Timer(const Duration(milliseconds: 0), () {});

  // todo convert to id, widget
  Map<int, String> statuses = <int, String>{
    0: '',
    1: '',
    2: '',
    3: '',
  };

  void setStatus(String s, {int millis = 2500}) {
    status = s;
    notifyListeners();

    timer.cancel();
    timer = Timer(Duration(milliseconds: millis), () {
      status = '';
      notifyListeners();
    });
  }

  void setIndexedStatus(int idx, String s, {int millis = 0}) {
    statuses[idx] = s;
    if (millis != 0) {
      Future.delayed(Duration(milliseconds: millis), () {
        statuses[idx] = '';
      });
    }
    notifyListeners();
  }
}
