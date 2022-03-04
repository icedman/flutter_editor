import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:collection';
import 'dart:ui' as ui;

import 'cursor.dart';
import 'document.dart';
import 'view.dart';
import 'theme.dart';

import 'package:highlight/highlight_core.dart' show highlight;
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/json.dart';
import 'package:flutter_highlight/themes/dracula.dart';

final theTheme = draculaTheme;

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
}

class CustomWidgetSpan extends WidgetSpan {
  int line = 0;
  CustomWidgetSpan({required Widget child, this.line = 0})
      : super(child: child);
}

class Highlighter {
  Highlighter() {
    highlight.registerLanguage('cpp', cpp);
    highlight.registerLanguage('json', json);
  }

  List<InlineSpan> run(Block? block, int line, Document document) {
    TextStyle defaultStyle = TextStyle(
        fontFamily: fontFamily, fontSize: fontSize, color: foreground);
    List<InlineSpan> res = <InlineSpan>[];
    List<LineDecoration> decors = <LineDecoration>[];

    List<Block> sel = document.selectedBlocks();
    for (final s in sel) {
      s.makeDirty();
    }

    block?.carets.clear();

    String text = block?.text ?? '';
    bool cache = true;
    if (block?.spans != null) {
      return block?.spans ?? [];
    }

    int idx = 0;
    void _traverse(var node) {
      int start = idx;
      final shouldAddSpan = node.className != null &&
          ((node.value != null && node.value!.isNotEmpty) ||
              (node.children != null && node.children!.isNotEmpty));

      if (shouldAddSpan) {
        //
      }

      if (node.value != null) {
        int l = (node.value ?? '').length;
        idx = idx + l;
      } else if (node.children != null) {
        node.children!.forEach(_traverse);
      }

      if (shouldAddSpan) {
        LineDecoration d = LineDecoration();
        d.start = start;
        d.end = idx - 1;
        String className = node.className;
        className = className.replaceAll('meta-', '');
        TextStyle? style = theTheme[className];
        d.color = style?.color ?? foreground;
        decors.add(d);
      }
    }

    Block? prev = block?.previous;
    var continuation = prev?.mode ?? null;
    block?.prevBlockClass = prev?.mode?.className ?? '';
    var result =
        highlight.parse(text, language: 'cpp', continuation: continuation);
    block?.mode = highlight.lastContinuation;

    Block? next = block?.next;
    if (next != null && block?.mode != null) {
      if (next.prevBlockClass != block?.mode?.className) {
        next.makeDirty();
      }
    }

    result.nodes?.forEach(_traverse);

    text += ' ';

    // res.add(TextSpan(
    //           text: text,
    //           style: defaultStyle,
    //           mouseCursor: MaterialStateMouseCursor.textable));

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
            style =
                style.copyWith(backgroundColor: selection.withOpacity(0.75));
            cache = false;
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
        block?.carets.add(i);
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
