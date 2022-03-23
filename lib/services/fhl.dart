import 'package:flutter/material.dart';

import 'package:editor/document.dart';
import 'package:editor/theme.dart';
import 'package:editor/services/highlighter.dart';

import 'package:highlight/highlight_core.dart' show highlight;
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/json.dart';

class FlutterHighlighter extends HLEngine {
  FlutterHighlighter() {
    highlight.registerLanguage('cpp', cpp);
    highlight.registerLanguage('json', json);
  }

  List<LineDecoration> run(Block? block, int line, Document document) {
    List<LineDecoration> decors = [];

    Block b = block ?? Block('', document: Document());
    Block? prevBlock = b.previous;
    Block? nextBlock = b.next;

    b.prevBlockClass = prevBlock?.className ?? '';

    String text = b.text;

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
        d.color = style?.color ?? theme.foreground;
        decors.add(d);
      }
    }

    var continuation = prevBlock?.mode;
    var result =
        highlight.parse(text, language: 'cpp', continuation: continuation);
    block?.mode = result.top;

    b.className = b.mode?.className ?? '';
    if (nextBlock != null) {
      if (nextBlock.prevBlockClass != b.className) {
        nextBlock.makeDirty();
      }
    }

    result.nodes?.forEach(_traverse);

    return decors;
  }

  int getLanguageId(String filename) {
    return 0;
  }

  int loadTheme(String filename) {
    return 0;
  }
}
