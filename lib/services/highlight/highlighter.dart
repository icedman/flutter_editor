import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/editor/view.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/ffi/bridge.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/fhl.dart';
import 'package:editor/services/highlight/tmparser.dart';

abstract class HLEngine {
  List<LineDecoration> run(Block? block, int line, Document document);

  void loadTheme(String path);
  HLLanguage loadLanguage(String filename);
  HLLanguage? language(int id);
}

abstract class HLLanguage {
  int langId = 0;
  List<String> blockComment = [];
  String lineComment = '';
  Map<String, String> brackets = {};
  Map<String, String> autoClose = {};
  List<String> closingBrackets = [];
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
  bool tab = false;

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

    if (block?.decors == null && text.length < 500) {
      block?.decors = engine.run(block, line, document);
    }
    List<LineDecoration> decors = block?.decors ?? [];

    // tabs
    int indentSize = Document.countIndentSize(text);
    int tabSpaces = (block?.document?.detectedTabSpaces ?? 1);
    if (tabSpaces == 0) tabSpaces = 2;
    int tabStops = indentSize ~/ tabSpaces;
    Color tabStopColor = colorCombine(theme.comment, theme.background, bw: 3);

    // print('$tabStops $indentSize');

    for (int i = 0; i <= tabStops; i++) {
      int start = i * tabSpaces;
      int end = start;
      decors.insert(
          0,
          LineDecoration()
            ..start = start
            ..end = end
            ..color = tabStopColor
            ..tab = true);
    }

    text += ' ';
    String prevText = '';
    for (int i = 0; i < text.length; i++) {
      String ch = text[i];
      TextStyle style = defaultStyle.copyWith(letterSpacing: 0);

      bool isTabStop = false;

      // decorate
      for (final d in decors) {
        if (i >= d.start && i <= d.end) {
          if (d.tab) {
            if (ch != ' ') continue;
            // ch = '|'
            ch = '│';
            // ch = '︳';
            // ch = '︴';
            // ch = '🭰';
            isTabStop = true;
          }

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
      for (final c in document.cursors) {
        if (line == (c.block?.line ?? 0)) {
          int l = (c.block?.text ?? '').length;
          if (i == c.column || (i == l && c.column > l)) {
            Color caretColor = style.color ?? Colors.white;
            if (isTabStop) {
              caretColor = theme.foreground;
            }
            block?.carets.add(BlockCaret(position: i, color: caretColor));
            break;
          }
        }
      }

      if (ch == '\t') {
        ch = ' '; // todo! -- properly handle \t ... make files use \t
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

    res.add(CustomWidgetSpan(
        child: Container(height: 1, width: 1), line: line, block: block));

    if (cache) {
      block?.spans = res;
    }

    return res;
  }
}
