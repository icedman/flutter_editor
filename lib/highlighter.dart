import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:collection';
import 'dart:ui' as ui;

import 'cursor.dart';
import 'document.dart';
import 'view.dart';
import 'theme.dart';

Size getTextExtents(String text, TextStyle style) {
  final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr)
    ..layout(minWidth: 0, maxWidth: double.infinity);
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
  HashMap<String, Color> colorMap = HashMap<String, Color>();

  Highlighter() {
    colorMap.clear();
    colorMap['\\b(class|struct)\\b'] = function;
    colorMap['("|<){1}\\b(.*)\\b("|>){1}'] = string;
    // keywords and meta-keywords list is copied from flutter_highlight
    colorMap[
            '\\b(if|else|elif|endif|define|undef|warning|error|line|pragma|_Pragma|ifdef|ifndef|include)\\b'] =
        function;
    colorMap[
            '\\b(keyword|int|float|while|private|char|char8_t|char16_t|char32_t|catch|import|module|export|virtual|operator|sizeof|dynamic_cast|10|typedef|const_cast|10|const|for|static_cast|10|union|namespace|unsigned|long|volatile|static|protected|bool|template|mutable|if|public|friend|do|goto|auto|void|enum|else|break|extern|using|asm|case|typeid|wchar_tshort|reinterpret_cast|10|default|double|register|explicit|signed|typename|try|this|switch|continue|inline|delete|alignas|alignof|constexpr|consteval|constinit|decltype|concept|co_await|co_return|co_yield|requires|noexcept|static_assert|thread_local|restrict|final|override|atomic_bool|atomic_char|atomic_schar|atomic_uchar|atomic_short|atomic_ushort|atomic_int|atomic_uint|atomic_long|atomic_ulong|atomic_llong|atomic_ullong|new|throw|return|and|and_eq|bitand|bitor|compl|not|not_eq|or|or_eq|xor|xor_eq)\\b'] =
        keyword;
  }

  List<InlineSpan> run(String text, int line, Document document) {
    TextStyle defaultStyle = TextStyle(
        fontFamily: 'FiraCode', fontSize: fontSize, color: foreground);
    List<InlineSpan> res = <InlineSpan>[];
    List<LineDecoration> decors = <LineDecoration>[];

    for (var exp in colorMap.keys) {
      RegExp regExp = new RegExp(exp, caseSensitive: false, multiLine: false);
      var matches = regExp.allMatches(text);
      matches.forEach((m) {
        if (m.start == m.end) return;
        LineDecoration d = LineDecoration();
        d.start = m.start;
        d.end = m.end - 1;
        d.color = colorMap[exp] ?? foreground;
        decors.add(d);
      });
    }

    text += ' ';
    String prevText = '';
    for (int i = 0; i < text.length; i++) {
      String ch = text[i];
      TextStyle style = defaultStyle.copyWith();

      // decorate
      decors.forEach((d) {
        if (i >= d.start && i <= d.end) {
          style = style.copyWith(color: d.color);
        }
      });

      // is within selection
      for (final c in document.cursors) {
        Cursor cur = c.normalized();
        if (cur.hasSelection()) {
          if (line < cur.line ||
              (line == cur.line && i < cur.column) ||
              line > cur.anchorLine ||
              (line == cur.anchorLine && i + 1 > cur.anchorColumn)) {
          } else {
            style =
                style.copyWith(backgroundColor: selection.withOpacity(0.75));
            break;
          }
        }
      }

      // is within caret
      bool inCaret = false;
      for (final c in document.cursors) {
        if ((line == c.line && i == c.column)) {
          inCaret = true;
          break;
        }
      }

      if (inCaret) {
        res.add(WidgetSpan(
            alignment: ui.PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
                decoration: BoxDecoration(
                    border: Border(
                        left: BorderSide(
                            width: 1.2, color: style.color ?? Colors.yellow))),
                child: Text(ch, style: style.copyWith(letterSpacing: -1.5)))));
        continue;
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
        CustomWidgetSpan(child: Container(height: 1, width: 8), line: line));
    return res;
  }
}
