import 'dart:async';
import 'package:flutter/material.dart';

class UIMenuData {
  int menuIndex = 0;
  String title = '';
  List<UIMenuData> items = [];

  Function? onSelect;

  void select(int index) {
    if (index >= 0 && index < items.length && items[index] != null) {
      onSelect?.call(items[index]);
    }
  }
}

class UIProvider extends ChangeNotifier {
  Map<String, Function?> actions = <String, Function?>{};
  List<Widget> popups = <Widget>[];
  Map<String, UIMenuData> menus = {};

  int menuIndex = 0;

  UIMenuData? menu(String id, {Function? onSelect}) {
    menus[id] = menus[id] ?? UIMenuData();
    menus[id]?.onSelect = onSelect ?? menus[id]?.onSelect;
    return menus[id];
  }

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
