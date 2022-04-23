import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

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

  void cancel() {
    timer.cancel();
  }
}

class DecorInfo extends ChangeNotifier {
  Offset scrollPosition = Offset.zero;

  Offset thumbScrollStart = Offset.zero;
  Offset thumbPosition = Offset.zero;
  Offset thumbAnchorPosition = Offset.zero;
  Cursor thumbCursor = Cursor();

  Offset caretPosition = Offset.zero;
  Cursor caret = Cursor();

  double fontHeight = 0;
  int visibleStart = -1;
  int visibleEnd = -1;

  void notifyLater() {
    Future.delayed(const Duration(milliseconds: 0), () => notifyListeners());
  }

  void onScroll(scroll) {
    scrollPosition = scroll;
    notifyListeners();
  }

  void setVisibleRange(start, end) {
    visibleStart = start;
    visibleEnd = end;
    notifyListeners();
  }

  void setCaret(Offset pos, Cursor cursor) {
    caretPosition = pos;
    caret = cursor.copy();
    notifyLater();
  }

  void setThumb(Offset start, Offset end, Cursor cursor) {
    if (!cursor.hasSelection()) {
      if (thumbCursor.hasSelection()) {
        thumbCursor.clearSelection();
        notifyLater();
      }
      return;
    }
    if (cursor.normalized() == thumbCursor.normalized()) {
      return;
    }
    thumbScrollStart = scrollPosition;
    if (end != Offset.zero) {
      thumbPosition = end;
    }
    if (start != Offset.zero) {
      thumbAnchorPosition = start;
    }
    thumbCursor = cursor.copy();
    notifyLater();
  }
}

class AnimatedCaret extends StatelessWidget {
  AnimatedCaret(
      {Key? key,
      this.width = 0,
      this.height = 0,
      Color this.color = Colors.yellow})
      : super(key: key);

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
            // border: Border(bottom: BorderSide(color: color, width: 2.0))
            border: Border.all(color: color, width: 1.0)));
  }
}

class SelectionThumb extends StatelessWidget {
  SelectionThumb({bool this.anchor = false});
  bool anchor = false;

  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    DecorInfo decor = Provider.of<DecorInfo>(context);

    if (!decor.thumbCursor.hasSelection()) {
      return Container();
    }
    Offset pos = anchor ? decor.thumbAnchorPosition : decor.thumbPosition;
    double dx = decor.thumbScrollStart.dx - decor.scrollPosition.dx;
    double dy = decor.thumbScrollStart.dy - decor.scrollPosition.dy;
    pos = Offset(pos.dx + dx, pos.dy + dy);
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

class SearchResultDecorator extends LineDecorator {
  String text = '';
  bool regex = false;
  bool caseSensitive = false;

  List<LineDecoration> run(Block? block) {
    List<LineDecoration> res = [];
    String t = block?.text ?? '';
    String f = text;

    HLTheme theme = HLTheme.instance();
    int lnIdx = t.indexOf('[Ln');
    if (lnIdx == -1) {
      return [
        LineDecoration()
          ..start = 0
          ..end = t.length
          ..color = theme.comment
      ];
    }

    res.add(LineDecoration()
      ..start = lnIdx
      ..end = t.length
      ..color = theme.function
      ..tap = 'open_search_result');

    if (!caseSensitive && !regex) {
      f = f.toLowerCase();
    }

    RegExp _wordRegExp = RegExp(
      text,
      caseSensitive: caseSensitive,
      multiLine: false,
    );

    List<List<int>> _res = [];
    if (regex) {
      final matches = _wordRegExp.allMatches(t);
      for (final m in matches) {
        var g = m.groups([0]);
        _res.add([m.start, m.end]);
      }
    } else {
      int start = 0;
      if (!caseSensitive && !regex) {
        t = t.toLowerCase();
      }
      while (true) {
        int idx = t.indexOf(f, start);
        if (idx != -1) {
          _res.add([idx, idx + f.length - 1]);
          start = idx + f.length;
          continue;
        }
        break;
      }
    }

    for (final r in _res) {
      res.add(LineDecoration()
        ..start = r[0]
        ..end = r[1]
        ..italic = true
        ..underline = true
        ..color = theme.string
        ..tap = 'open_search_result');
    }

    return res;
  }
}
