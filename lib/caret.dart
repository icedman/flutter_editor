import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

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
      decoration: BoxDecoration(border: Border.all(color: color, width: 2.0)),
    );
  }
}
