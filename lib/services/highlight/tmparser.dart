import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

import 'package:editor/document.dart';
import 'package:editor/theme.dart';
import 'package:editor/native.dart';
import 'package:editor/services/highlight/highlighter.dart';

class TMParserLanguage extends HLLanguage {}

class TMParser extends HLEngine {
  int themeId = 0;
  int langId = 0;

  Map<int, HLLanguage> languages = {};

  TMParser() {
    FFIBridge.initHighlighter();
    themeId = FFIBridge.loadTheme(
        "/home/iceman/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json");
    langId = loadLanguage("test.c").langId;
  }

  List<LineDecoration> run(Block? block, int line, Document document) {
    List<LineDecoration> decors = [];

    Block b = block ?? Block('', document: Document());
    Block? prevBlock = b.previous;
    Block? nextBlock = b.next;

    b.prevBlockClass = prevBlock?.className ?? '';

    String text = b.text;

    final nspans = FFIBridge.runHighlighter(
        text,
        langId,
        themeId,
        b.document?.documentId ?? 0,
        b.blockId,
        prevBlock?.blockId ?? 0,
        nextBlock?.blockId ?? 0);

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
      d.italic = spn.italic > 0;
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

  int getLanguageId(String filename) {
    return 0;
  }

  int loadTheme(String filename) {
    return 0;
  }

  HLLanguage loadLanguage(String filename) {
    int langId = FFIBridge.loadLanguage("test.c");
    if (languages.containsKey(langId)) {
      return languages[langId] ?? TMParserLanguage();
    }

    String res = FFIBridge.languageDefinition(langId);
    final j = jsonDecode(res);

    HLLanguage l = TMParserLanguage();
    l.langId = langId;

    if (j['brackets'] is List) {
      List? brackets = j['brackets'];
      if (brackets != null && brackets.length > 0 && brackets[0] is List) {
        for (final p in brackets) {
          List<String> pp = [];
          for (final i in p) {
            pp.add(i as String);
          }

          l.brackets.add(pp);
        }
      }
    }

    // if (j['autoClosingPairs'] is List) {
    //   for(final p in j['autoClosingPairs'] ?? []) {
    //     print(p);
    //   }
    // }

    languages[langId] = l;
    return l;
  }
}
