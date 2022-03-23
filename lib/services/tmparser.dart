import 'package:flutter/material.dart';

import 'package:editor/document.dart';
import 'package:editor/theme.dart';
import 'package:editor/native.dart';
import 'package:editor/services/highlighter.dart';

import 'dart:ffi';
import 'package:ffi/ffi.dart';

class TMParser extends HLEngine {

    int themeId = 0;
    int langId = 0;

  TMParser() {
    init_highlighter();
    themeId = loadTheme(
        "/home/iceman/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json");
    langId = loadLanguage("test.c");
  }

  List<LineDecoration> run(Block? block, int line, Document document) {
    List<LineDecoration> decors = [];

    Block b = block ?? Block('', document: Document());
    Block? prevBlock = b.previous;
    Block? nextBlock = b.next;

    b.prevBlockClass = prevBlock?.className ?? '';

    String text = b.text;

    final nspans = runHighlighter(text, langId, themeId, b.document?.documentId ?? 0, b.blockId,
        prevBlock?.blockId ?? 0, nextBlock?.blockId ?? 0);

    bool comment = false;
    bool string = false;

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

      if (l > 1) {
          comment = spn.comment != 0;
          string = spn.string != 0;
      }

      // print('$s $l ${spn.r}, ${spn.g}, ${spn.b}');
    }

    b.decors = decors;
    b.className = comment ? 'comment' : (string ? 'string' : '');

    if (nextBlock != null) {
      if (nextBlock.prevBlockClass != b.className) {
        nextBlock.makeDirty();
      }
    }

    return decors;
  }
}
