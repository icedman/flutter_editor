import 'dart:async';
import 'package:flutter/material.dart';

class UIProvider extends ChangeNotifier {
  Map<String, Function?> actions = <String, Function?>{};
  List<Widget> popups = <Widget>[];

  bool hasPopups() {
    return popups.isNotEmpty;
  }

  void setPopup(Widget widget, {bool blur = false, bool shield = false}) {
    clearPopups();
    pushPopup(widget, blur: blur, shield: shield);
  }

  void pushPopup(Widget widget, {bool blur = false, bool shield = false}) {
    if (blur || shield) {
      popups.add(GestureDetector(
          onTap: () {
            if (shield) {
              popPopup();
            }
          },
          child: Stack(children: [
            Container(color: Colors.black.withOpacity(blur ? 0.5 : 0.015)),
            widget
          ])));
    } else {
      popups.add(Stack(children: [widget]));
    }
    notifyListeners();
  }

  void popPopup() {
    if (popups.isNotEmpty) {
      popups.removeLast();
      Future.delayed(const Duration(milliseconds: 50), notifyListeners);
    }
  }

  void clearPopups() {
    if (popups.isNotEmpty) {
      popups.clear();
      Future.delayed(const Duration(milliseconds: 50), notifyListeners);
    }
  }

}