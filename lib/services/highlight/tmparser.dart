import 'dart:convert';
import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

import 'package:editor/editor/document.dart';
import 'package:editor/ffi/bridge.dart';
import 'package:editor/ffi/highlighter.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

const int SCOPE_COMMENT = (1 << 1);
const int SCOPE_COMMENT_BLOCK = (1 << 2);
const int SCOPE_STRING = (1 << 3);
const int SCOPE_BRACKET = (1 << 4);
const int SCOPE_BRACKET_CURLY = (1 << 4);
const int SCOPE_BRACKET_ROUND = (1 << 5);
const int SCOPE_BRACKET_SQUARE = (1 << 6);
const int SCOPE_BEGIN = (1 << 7);
const int SCOPE_END = (1 << 8);
const int SCOPE_TAG = (1 << 9);
const int SCOPE_VARIABLE = (1 << 10);
const int SCOPE_CONSTANT = (1 << 11);
const int SCOPE_KEYWORD = (1 << 12);
const int SCOPE_ENTITY = (1 << 13);
const int SCOPE_ENTITY_CLASS = (1 << 14);
const int SCOPE_ENTITY_FUNCTION = (1 << 15);

class TMParserLanguage extends HLLanguage {}

class TMParser extends HLEngine {
  int themeId = 0;
  int langId = 0;

  Map<int, HLLanguage> languages = {};

  TMParser() {
    loadTheme(Platform.isAndroid
        ? '/sdcard/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json'
        : '/home/iceman/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json');

    loadLanguage("test.c").langId;
  }

  void loadTheme(String path) {
    themeId = FFIBridge.loadTheme(path);

    // modify global theme instance
    HLTheme theme = HLTheme.instance();

    ThemeInfo info = FFIBridge.theme_info();
    theme.foreground = Color.fromRGBO(info.r, info.g, info.b, 1);
    theme.background = Color.fromRGBO(info.bg_r, info.bg_g, info.bg_b, 1);
    theme.selection = Color.fromRGBO(info.sel_r, info.sel_g, info.sel_b, 1);

    ThemeColor clr = FFIBridge.themeColor('comment');
    theme.comment = Color.fromRGBO(clr.r, clr.g, clr.b, 1);
    clr = FFIBridge.themeColor('entity.name.function');
    theme.function = Color.fromRGBO(clr.r, clr.g, clr.b, 1);
    clr = FFIBridge.themeColor('keyword');
    theme.keyword = Color.fromRGBO(clr.r, clr.g, clr.b, 1);
    clr = FFIBridge.themeColor('string');
    theme.string = Color.fromRGBO(clr.r, clr.g, clr.b, 1);

    Future.delayed(const Duration(milliseconds: 0), () {
      theme.notifyListeners();
    });
  }

  List<LineDecoration> run(Block? block, int line, Document document) {
    List<LineDecoration> decors = [];

    Block b = block ?? Block('', document: Document());
    Block? prevBlock = b.previous;
    Block? nextBlock = b.next;

    b.prevBlockClass = prevBlock?.className ?? '';
    b.scopes = {};

    String text = b.text;
    text += ' ';

    final nspans = FFIBridge.runHighlighter(
        text,
        document.langId,
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

      if (spn.flags != 0) {
        b.scopes[s] = spn.flags;
        b.scopes[s + l + 1] = 0;
      }

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

    HLLanguage l = TMParserLanguage();
    l.langId = langId;

    try {
      String res = FFIBridge.languageDefinition(langId);
      dynamic j = jsonDecode(res);
      // comments
      if (j['comments'] != null) {
        if (j['comments']['lineComment'] != null) {
          l.lineComment = j['comments']['lineComment'];
        }
        if (j['comments']['blockComment'] != null) {
          l.blockComment = j['comments']['blockComment'];
        }
      }
    } catch (err) {
      //
    }

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
