import 'dart:convert';
import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

import 'package:editor/document.dart';
import 'package:editor/native.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

const int SCOPE_COMMENT = (1 << 1);
const int SCOPE_COMMENT_BLOCK = (1 << 2);
const int SCOPE_STRING = (1 << 3);
const int SCOPE_BRACKET = (1 << 4);
const int SCOPE_TAG = (1 << 5);
const int SCOPE_BEGIN = (1 << 6);
const int SCOPE_END = (1 << 7);

class TMParserLanguage extends HLLanguage {}

class TMParser extends HLEngine {
  int themeId = 0;
  int langId = 0;

  Map<int, HLLanguage> languages = {};

  TMParser() {
    themeId = FFIBridge.loadTheme(
      Platform.isAndroid ?
      '/sdcard/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json'
       : '/home/iceman/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json');
    loadLanguage("test.c").langId;
  }

  List<LineDecoration> run(Block? block, int line, Document document) {
    List<LineDecoration> decors = [];

    Block b = block ?? Block('', document: Document());
    Block? prevBlock = b.previous;
    Block? nextBlock = b.next;

    b.prevBlockClass = prevBlock?.className ?? '';

    String text = b.text;
    text += ' ';

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

      d.bracket = (spn.flags & SCOPE_BRACKET) == SCOPE_BRACKET;
      d.open = (spn.flags & SCOPE_BEGIN) == SCOPE_BEGIN;

      decors.add(d);

      comment = (spn.flags & SCOPE_COMMENT_BLOCK) == SCOPE_COMMENT_BLOCK;
      string = (spn.flags & SCOPE_STRING) == SCOPE_STRING;

      // print('$s $l ${spn.r}, ${spn.g}, ${spn.b}');
    }

    b.decors = decors;
    b.className = comment ? 'comment' : (string ? 'string' : '');

    if (nextBlock != null) {
      if (nextBlock.prevBlockClass != b.className) {
        nextBlock.makeDirty(highlight: true);
      }
    }

    return decors;
  }

  HLLanguage? language(int id) {
    return languages[id != 0 ? id : langId];
  }

  HLLanguage loadLanguage(String filename) {
    langId = FFIBridge.loadLanguage(filename);
    if (languages.containsKey(langId)) {
      return languages[langId] ?? TMParserLanguage();
    }

    String res = FFIBridge.languageDefinition(langId);
    final j = jsonDecode(res);

    HLLanguage l = TMParserLanguage();
    l.langId = langId;

    /*
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
    */

    // if (j['autoClosingPairs'] is List) {
    //   for(final p in j['autoClosingPairs'] ?? []) {
    //     print(p);
    //   }
    // }

    languages[langId] = l;
    return l;
  }
}
