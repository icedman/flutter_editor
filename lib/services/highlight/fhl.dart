import 'package:flutter/material.dart';

import 'package:editor/editor/block.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/services/highlight/highlighter.dart';
import 'package:editor/services/highlight/theme.dart';

import 'package:highlight/highlight_core.dart' show highlight;
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/json.dart';

import 'package:flutter_highlight/themes/dracula.dart';

final theTheme = draculaTheme;

class FlutterHighlightLanguage extends HLLanguage {}

class FlutterHighlight extends HLEngine {
  FlutterHighlight() {
    highlight.registerLanguage('cpp', cpp);
    highlight.registerLanguage('json', json);
  }

  void loadTheme(String path) {
    //
  }

  List<LineDecoration> run(Block? block, int line, Document document) {
    HLTheme theme = HLTheme.instance();

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

    b.className = result.top?.className ?? '';
    if (nextBlock != null) {
      if (nextBlock.prevBlockClass != b.className) {
        nextBlock.makeDirty(highlight: true);
      }
    }

    result.nodes?.forEach(_traverse);

    return decors;
  }

  // int loadTheme(String filename) {
  //   return 0;
  // }

  HLLanguage loadLanguage(String filename) {
    return FlutterHighlightLanguage();
  }

  HLLanguage? language(int id) {
    return null;
  }
}
