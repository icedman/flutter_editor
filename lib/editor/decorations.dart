import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/services/highlight/theme.dart';

const double caretWidth = 2;
const int caretHideInterval = 350;
const int caretShowInterval = 550;

class CaretPulse extends ChangeNotifier {
  bool show = false;
  Timer timer = Timer(const Duration(milliseconds: 0), () {});

  CaretPulse() {
    Future.delayed(Duration(milliseconds: 0), flipCaret);
  }

  void flipCaret() {
    timer.cancel();
    timer = Timer(
        Duration(milliseconds: show ? caretShowInterval : caretHideInterval),
        () {
      show = !show;
      notifyListeners();
      flipCaret();
    });
  }
}

class DecorInfo extends ChangeNotifier {
    Offset scrollPosition = const Offset(0, 0);
    Offset thumbPosition = const Offset(0, 0);
    Offset thumbAnchorPosition = const Offset(0, 0);
    Cursor thumb = Cursor();
}

class AnimatedCaret extends StatelessWidget {
  AnimatedCaret(
      {this.width = 0, this.height = 0, Color this.color = Colors.yellow});

  double width = 0;
  double height = 0;
  Color color = Colors.yellow;

  @override
  Widget build(BuildContext context) {
    CaretPulse pulse = Provider.of<CaretPulse>(context);
    FocusNode focus = Focus.of(context);
    return Container(
        height: height,
        width: width,
        color: (!focus.hasFocus || !pulse.show) ? null : color);
  }
}

class BracketMatch extends StatelessWidget {
  BracketMatch(
      {this.width = 0, this.height = 0, Color this.color = Colors.yellow});

  double width = 0;
  double height = 0;
  Color color = Colors.yellow;

  @override
  Widget build(BuildContext context) {
    FocusNode focus = Focus.of(context);
    return Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: color, width: 2.0))));
  }
}

class SelectionThumb extends StatelessWidget {
  SelectionThumb({bool this.anchor = false});
  bool anchor = false;

  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    CaretPulse pulse = Provider.of<CaretPulse>(context);
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    if (!doc.doc.hasSelection()) {
      return Container();
    }
    Offset pos = anchor ? doc.anchorOffset : doc.cursorOffset;
    double radius = 16;
    return Positioned(
        top: pos.dy + 20,
        left: pos.dx - (radius / 2),
        child: Container(
            width: radius,
            height: radius,
            decoration: BoxDecoration(
                color: theme.foreground,
                border: Border.all(
                  color: theme.foreground,
                ),
                borderRadius: BorderRadius.all(Radius.circular(radius / 2)))));
  }
}
