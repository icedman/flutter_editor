import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:ffi' hide Size;
import 'dart:convert';
import 'package:ffi/ffi.dart';

import 'cursor.dart';
import 'document.dart';
import 'view.dart';
import 'theme.dart';
import 'native.dart';

import 'package:highlight/highlight_core.dart' show highlight;
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/json.dart';

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

int themeId = 0;
int langId = 0;

class Highlighter {

  Highlighter() {

    init_highlighter();
    themeId = loadTheme(
        "/home/iceman/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json");
    langId = loadLanguage("test.c");

    // highlight.registerLanguage('cpp', cpp);
    // highlight.registerLanguage('json', json);
  }

  List<InlineSpan> run(Block? block, int line, Document document) {
    TextStyle defaultStyle = TextStyle(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
        color: theme.foreground);
    List<InlineSpan> res = <InlineSpan>[];
    List<LineDecoration> decors = [];// block?.decors ?? [];

    // List<Block> sel = document.selectedBlocks();
    // for (final s in sel) {
    //   s.makeDirty();
    // }
      Block b = block ?? Block('', document: Document());

      Block? prevBlock = b.previous;
      Block? nextBlock = b.next;

      String text = b.text;
      final nspans = runHighlighter(text, langId, themeId, b.blockId,
          prevBlock?.blockId ?? 0, nextBlock?.blockId ?? 0);

      int idx = 0;
      while (idx < (2048 * 4)) {
        final spn = nspans[idx++];
        if (spn.start == 0 && spn.length == 0) break;
        int s = spn.start;
        int l = spn.length;

        // todo... cleanup these checks
        if (s < 0) continue;
        if (s - 1 >= text.length) continue;
        if (s + l >= text.length) {
          l = text.length - s;
        }
        if (l <= 0) continue;

        Color fg = Color.fromRGBO(spn.r, spn.g, spn.b, 1);
        bool hasBg = (spn.bg_r + spn.bg_g + spn.bg_b != 0);

        LineDecoration d = LineDecoration();
        d.start = s;
        d.end = s + l - 1;
        d.color = fg;
        decors.add(d);

        // print('$s $l ${spn.r}, ${spn.g}, ${spn.b}');
      }

      b.decors = decors;


    // String text = block?.text ?? '';
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
