import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/editor/view.dart';
import 'package:editor/ffi/bridge.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/fhl.dart';
import 'package:editor/services/highlight/tmparser.dart';

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
  // int loadTheme(String filename);
  HLLanguage loadLanguage(String filename);
  HLLanguage? language(int id);
}

abstract class HLLanguage {
  int langId = 0;
  List<List<String>> brackets = [];
  // List<List<String>> autoClose = [];
  // List<String> blockComment = [];
  // String lineComment = '';
}

class LineDecoration {
  int start = 0;
  int end = 0;
  Color color = Colors.white;
  Color background = Colors.white;
  bool underline = false;
  bool italic = false;
  bool bracket = false;
  bool open = false;

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
  Block? block;
  CustomWidgetSpan({required Widget child, this.line = 0, this.block})
      : super(child: child);
}

class Highlighter {
  HLEngine engine = TMParser();
  // HLEngine engine = FlutterHighlight();

  List<InlineSpan> run(Block? block, int line, Document document,
      {Function? onTap, Function? onHover}) {
    HLTheme theme = HLTheme.instance();

    TextStyle defaultStyle = TextStyle(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
        color: theme.foreground);
    List<InlineSpan> res = <InlineSpan>[];

    String text = block?.text ?? '';

    bool cache = true;
    if (block?.spans != null) {
      return block?.spans ?? [];
    }

    block?.spans?.clear();
    block?.carets.clear();
    block?.brackets.clear();

    HLLanguage? lang = engine.language(0);

    if (block?.decors == null) {
      block?.decors = engine.run(block, line, document);
    }
    List<LineDecoration> decors = block?.decors ?? [];

    text += ' ';
    String prevText = '';
    for (int i = 0; i < text.length; i++) {
      String ch = text[i];
      TextStyle style = defaultStyle.copyWith(letterSpacing: 0);

      // decorate
      for (final d in decors) {
        if (i >= d.start && i <= d.end) {
          style = style.copyWith(color: d.color);
          if (d.italic) {
            style = style.copyWith(fontStyle: FontStyle.italic);
          }
          if (d.underline) {
            style = style.copyWith(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.solid,
                decorationColor: d.color,
                decorationThickness: 1.0);
          }
          if (d.bracket && i == d.start) {
            block?.brackets.add(BlockBracket(
                block: block, position: d.start, open: d.open, bracket: ch));
          }
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

      if (ch == '\t') {
        ch = ' '; // todo!
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

    if (block?.isFolded() ?? false) {
      TextStyle moreStyle = defaultStyle.copyWith(
          fontSize: theme.fontSize * 0.8,
          color: theme.string,
          backgroundColor: theme.selection);
      res.add(TextSpan(
          text: '...',
          style: moreStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              onTap?.call(':unfold');
            }));
    }

    // res.add(TextSpan(text: '-- ${block?.previous?.line} [${block?.line}] ${block?.next?.line}', style: defaultStyle));

    res.add(CustomWidgetSpan(
        child: Container(height: 1, width: 1), line: line, block: block));

    if (cache) {
      block?.spans = res;
    }

    // move to commit ...
    // for (final s in res) {
    //   if (s is TextSpan) {
    //     if (s.style?.color != theme.comment) {
    //       if (s.text != null) {
    //         String txt = s.text ?? '';
    //         if (block?.document != null) {
    //           block?.document?.indexer.indexWords(txt);
    //         }
    //       }
    //     }
    //   }
    // }

    return res;
  }
}
