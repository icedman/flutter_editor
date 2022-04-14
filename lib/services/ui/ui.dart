import 'dart:async';
import 'package:flutter/material.dart';
import 'package:editor/services/ui/menu.dart';

class Popup {
  Popup({
    Widget? this.widget,
    bool this.isMenu = false,
  });
  bool isMenu = false;
  Widget? widget;
}

class UIProvider extends ChangeNotifier {
  Map<String, Function?> actions = <String, Function?>{};
  List<Popup> popups = <Popup>[];
  Map<String, UIMenuData> menus = {};

  int menuIndex = 0;
  Function? onClearPopups;

  UIMenuData? menu(String id, {Function? onSelect}) {
    menus[id] = menus[id] ?? UIMenuData();
    menus[id]?.onSelect = onSelect ?? menus[id]?.onSelect;
    return menus[id];
  }

  bool hasPopups() {
    return popups.isNotEmpty;
  }

  void setPopup(Widget widget,
      {bool blur = false, bool shield = false, Function? onClearPopups}) {
    this.onClearPopups = null;
    clearPopups();
    pushPopup(widget, blur: blur, shield: shield, onClearPopups: onClearPopups);
  }

  void pushPopup(Widget widget,
      {bool blur = false, bool shield = false, Function? onClearPopups}) {
    this.onClearPopups = onClearPopups;
    if (blur || shield) {
      popups.add(Popup(
          widget: GestureDetector(
              onTap: () {
                if (shield) {
                  popPopup();
                }
              },
              child: Stack(children: [
                Container(color: Colors.black.withOpacity(blur ? 0.5 : 0.015)),
                widget
              ])),
          isMenu: widget is UIMenuPopup));
    } else {
      popups.add(Popup(
          widget: Stack(children: [widget]), isMenu: widget is UIMenuPopup));
    }
    notifyListeners();
  }

  void popPopup() {
    if (popups.isNotEmpty) {
      popups.removeLast();
      Future.delayed(const Duration(milliseconds: 50), notifyListeners);
      if (popups.isEmpty) {
        onClearPopups?.call();
      }
    }
  }

  void clearPopups() {
    if (popups.isNotEmpty) {
      popups.clear();
      Future.delayed(const Duration(milliseconds: 50), notifyListeners);
      onClearPopups?.call();
    }
  }

  void clearMenus() {
    if (popups.isNotEmpty) {
      if (popups[0].isMenu) {
        popups.clear();
        Future.delayed(const Duration(milliseconds: 50), notifyListeners);
        onClearPopups?.call();
      }
    }
  }
}
