import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:editor/cursor.dart';
import 'package:editor/document.dart';
import 'package:editor/view.dart';
import 'package:editor/theme.dart';
import 'package:editor/native.dart';
import 'package:editor/services/fhl.dart';
import 'package:editor/services/tmparser.dart';

Color colorCombine(Color a, Color b, {int aw = 1, int bw = 1}) {
  int red = (a.red * aw + b.red * bw) ~/ (aw + bw);
  int green = (a.green * aw + b.green * bw) ~/ (aw + bw);
  int blue = (a.blue * aw + b.blue * bw) ~/ (aw + bw);
  return Color.fromRGBO(red, green, blue, 1);
}

Size getTextExtents(String text, TextStyle style,
    {double minWidth = 0,
    double maxWidth: double.infinity,
    int? maxLines = 1}) {
  final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: TextDirection.ltr)
    ..layout(minWidth: minWidth, maxWidth: maxWidth);
  return textPainter.size;
}

abstract class HLEngine {
  List<LineDecoration> run(Block? block, int line, Document document);
}

class LineDecoration {
  int start = 0;
  int end = 0;
  Color color = Colors.white;
  Color background = Colors.white;
  bool underline = false;
  bool italic = false;

  Object toObject() {
    return {
      'start': start,
      'end': end,
      'color': [color.red, color.green, color.blue]
    };
  }

  void fromObject(json) {
    start = json['start'] ?? 0;
    end = json['end'] ?? 0;
    final clr = json['color'] ?? [0, 0, 0];
    color = Color.fromRGBO(clr[0], clr[1], clr[2], 1);
  }
}

class CustomWidgetSpan extends WidgetSpan {
  int line = 0;
  CustomWidgetSpan({required Widget child, this.line = 0})
      : super(child: child);
}

class Highlighter {

  HLEngine engine = TMParser();
  // HLEngine engine = FlutterHighlighter();

  List<InlineSpan> run(Block? block, int line, Document document) {
    TextStyle defaultStyle = TextStyle(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
        color: theme.foreground);
    List<InlineSpan> res = <InlineSpan>[];

    List<Block> sel = document.selectedBlocks();
    for (final s in sel) {
      s.makeDirty();
    }
    Block b = block ?? Block('', document: Document());
    String text = b.text;

    List<LineDecoration> decors = engine.run(block, line, document);

    bool cache = true;
    if (block?.spans != null) {
      return block?.spans ?? [];
    }

    block?.carets.clear();

    text += ' ';
    String prevText = '';
    for (int i = 0; i < text.length; i++) {
      String ch = text[i];
      TextStyle style = defaultStyle.copyWith();

      // decorate
      for (final d in decors) {
        if (i >= d.start && i <= d.end) {
          style = style.copyWith(color: d.color);
          break;
        }
      }

      // is within selection
      for (final c in document.cursors) {
        if (c.hasSelection()) {
          Cursor cur = c.normalized();
          int blockLine = cur.block?.line ?? 0;
          int anchorLine = cur.anchorBlock?.line ?? 0;
          if (line > blockLine ||
              (line == blockLine && i + 1 > cur.column) ||
              line < anchorLine ||
              (line == anchorLine && i < cur.anchorColumn)) {
          } else {
            style = style.copyWith(
                backgroundColor: theme.selection.withOpacity(0.75));
            break;
          }
        }
      }

      // is within caret
      bool inCaret = false;
      for (final c in document.cursors) {
        if (line == (c.block?.line ?? 0)) {
          int l = (c.block?.text ?? '').length;
          if (i == c.column || (i == l && c.column > l)) {
            inCaret = true;
            break;
          }
        }
      }

      if (inCaret) {
        block?.carets
            .add(BlockCaret(position: i, color: style.color ?? Colors.white));
      }

      if (res.length != 0 && !(res[res.length - 1] is WidgetSpan)) {
        TextSpan prev = res[res.length - 1] as TextSpan;
        if (prev.style == style) {
          prevText += ch;
          res[res.length - 1] = TextSpan(
              text: prevText,
              style: style,
              mouseCursor: MaterialStateMouseCursor.textable);
          continue;
        }
      }

      res.add(TextSpan(
          text: ch,
          style: style,
          mouseCursor: MaterialStateMouseCursor.textable));

      prevText = ch;
    }

    res.add(
        CustomWidgetSpan(child: Container(height: 1, width: 1), line: line));

    if (cache) {
      block?.spans = res;
    }

    return res;
  }
}