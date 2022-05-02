import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:editor/services/ui/status.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/decorations.dart';
import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/block.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/editor/controller.dart';
import 'package:editor/editor/view.dart';
import 'package:editor/editor/search.dart';
import 'package:editor/editor/minimap.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/input.dart';
import 'package:editor/services/ffi/bridge.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/ui/menu.dart';
import 'package:editor/services/ui/status.dart';
import 'package:editor/services/ui/modal.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';
import 'package:editor/services/indexer/indexer.dart';
import 'package:editor/services/indexer/filesearch.dart';
import 'package:editor/services/keybindings.dart';

class Editor extends StatefulWidget {
  Editor({Key? key, String this.path = '', Document? this.document})
      : super(key: key);
  String path = '';
  Document? document;

  @override
  _Editor createState() => _Editor();
}

class _Editor extends State<Editor> with WidgetsBindingObserver {
  late DocumentProvider doc;
  late CaretPulse pulse;
  late DecorInfo decor;
  late Highlighter highlighter;
  late IndexerIsolate indexer;

  late FocusNode focusNode;
  late FocusNode textFocusNode;

  bool _isKeyboardVisible =
      WidgetsBinding.instance!.window.viewInsets.bottom > 0.0;

  bool shifting = false;
  bool controlling = false;
  bool alting = false;
  int lastHashCode = 0;

  List<Block> indexingQueue = [];
  HLLanguage? lang;

  @override
  void initState() {
    super.initState();

    highlighter = Highlighter();
    indexer = IndexerIsolate();
    doc = DocumentProvider();

    if (widget.document != null) {
      doc.doc = widget.document ?? doc.doc;
    }
    doc.openFile(widget.path);

    if (doc.doc.hideGutter) {
      doc.showGutter = false;
    }
    if (doc.doc.hideMinimap) {
      doc.showMinimap = false;
    }

    doc.doc.langId = highlighter.engine.loadLanguage(widget.path).langId;
    doc.scrollToLine(doc.doc.scrollToOnLoad);
    doc.doc.scrollToOnLoad = -1;

    Document d = doc.doc;
    lang = highlighter.engine.language(d.langId);
    d.lineComment = lang?.lineComment ?? '';
    d.blockComment = lang?.blockComment ?? [];

    d.addListener('onCreate', (documentId) {
      FFIBridge.run(() => FFIBridge.create_document(documentId));
    });
    d.addListener('onDestroy', (documentId) {
      FFIBridge.run(() => FFIBridge.destroy_document(documentId));
    });
    d.addListener('onAddBlock', (documentId, blockId) {
      FFIBridge.run(() => FFIBridge.add_block(documentId, blockId));
      doc.touch();
    });
    d.addListener('onRemoveBlock', (documentId, blockId) {
      FFIBridge.run(() => FFIBridge.remove_block(documentId, blockId));
      doc.touch();
    });
    d.addListener('onInsertText', (text) {});
    d.addListener('onInsertNewLine', () {});
    d.addListener('onFocus', (int documentId) {
      if (documentId == d.documentId) {
        StatusProvider status =
            Provider.of<StatusProvider>(context, listen: false);
        status.setIndexedStatus(1, '$documentId');
      }
      print(documentId);
    });
    d.addListener('onReady', () {
      Future.delayed(const Duration(seconds: 3), () {
        indexer.indexFile(widget.path);
      });
    });

    decor = DecorInfo();
    pulse = CaretPulse();

    indexer.onResult = (res) {
      UIProvider ui = Provider.of<UIProvider>(context, listen: false);
      UIMenuData? menu = ui.menu('indexer::${d.documentId}', onSelect: (item) {
        Document d = doc.doc;
        d.begin();
        d.clearCursors();
        d.moveCursorLeft();
        d.selectWord();
        d.insertText(item.title);
        d.commit();
        doc.notifyListeners();
      });
      menu?.menuIndex = 0;

      dynamic search = res;
      if (search == null) {
        return;
      }

      String _search = search['search'] ?? '';
      dynamic _result = search['result'] ?? [];

      menu?.items.clear();
      for (final s in _result) {
        menu?.items.add(UIMenuData()..title = s);
      }
    };

    focusNode = FocusNode();
    textFocusNode = FocusNode();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    pulse.cancel();
    indexer.dispose();

    focusNode.dispose();
    textFocusNode.dispose();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding.instance!.window.viewInsets.bottom;
    final newValue = bottomInset > 0.0;
    if (newValue != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = newValue;
      });
    }
  }

  void onShortcut(String keys) {
    AppProvider app = Provider.of<AppProvider>(context, listen: false);
    Command? cmd = app.keybindings.resolve(keys, code: lastHashCode);
    command(cmd?.command ?? '', params: cmd?.params);
  }

  void _makeDirty() {
    Document d = doc.doc;

    List<Block> sel = d.selectedBlocks();
    for (final s in sel) {
      s.makeDirty();
    }
    for (final c in d.cursors) {
      c.block?.makeDirty();
      c.anchorBlock?.makeDirty();
    }

    for (final f in d.folds) {
      f.anchorBlock?.makeDirty();
    }
  }

  void _regainFocus() {
    Future.delayed(const Duration(milliseconds: 50), () {
      focusNode.requestFocus();
      textFocusNode.requestFocus();
    });
  }

  void command(String cmd, {dynamic params}) async {
    Document d = doc.doc;
    Cursor cursor = d.cursor().copy();

    AppProvider app = Provider.of<AppProvider>(context, listen: false);

    // todo.. let popups handle their input...
    UIProvider ui = Provider.of<UIProvider>(context, listen: false);
    if (ui.popups.isNotEmpty) {
      UIMenuData? menu = ui.menu('indexer::${d.documentId}');
      int idx = menu?.menuIndex ?? 0;
      int size = menu?.items.length ?? 0;
      switch (cmd) {
        case 'up':
          if (idx > 0) {
            menu?.menuIndex--;
            ui.notifyListeners();
          }
          return;
        case 'down':
          if (idx + 1 < size) {
            menu?.menuIndex++;
            ui.notifyListeners();
          }
          return;
        case 'enter':
          {
            menu?.select(menu.menuIndex);
            ui.clearPopups();
            return;
          }
          return;
      }
    }

    final onSearchInFile = (text,
        {int direction = 1,
        bool caseSensitive = false,
        bool regex = false,
        bool repeat = false,
        bool searchInFiles = false,
        String? replace}) {
      Document d = doc.doc;
      Cursor? cur = d.find(d.cursor().copy(), text,
          direction: direction,
          regex: regex,
          caseSensitive: caseSensitive,
          repeat: repeat);
      if (cur != null) {
        if (replace != null && d.hasSelection()) {
          d.begin();
          d.insertText(replace);
          d.commit();
        }
        d.clearCursors();
        d.cursor().copyFrom(cur, keepAnchor: true);
        doc.scrollToLine(cur.block?.line ?? 0);
      }
    };

    switch (cmd) {
      case 'switch_tab':
        {
          int idx = params;
          if (idx >= 0 && idx < app.documents.length) {
            app.open(app.documents[idx].docPath, focus: true);
          }
          return;
        }

      case 'toggle_pinned':
        {
          doc.pinned = !doc.pinned;
          return;
        }

      case 'search_text':
        {
          ui.setPopup(SearchPopup(onSubmit: (text,
              {int direction = 1,
              bool caseSensitive = false,
              bool regex = false,
              bool repeat = false,
              bool searchInFiles = false,
              String searchPath = '',
              String? replace}) {
            onSearchInFile.call(text,
                direction: direction,
                caseSensitive: caseSensitive,
                regex: regex,
                repeat: repeat);
          }), blur: false, shield: false, onClearPopups: _regainFocus);
          return;
        }
      case 'jump_to_line':
        {
          ui.setPopup(GotoPopup(onSubmit: (line) {
            command('cursor', params: [line, 0]);
            return;
          }), blur: false, shield: false, onClearPopups: _regainFocus);
        }
        return;
    }

    List<Block> modifiedBlocks = [];

    doc.begin();
    doc.command(cmd, params: params, modifiedBlocks: modifiedBlocks);
    if (cmd == 'enter') {
      doc.doc.autoIndent();
    }
    doc.commit();

    {
      for (final b in modifiedBlocks) {
        if (!indexingQueue.contains(b)) {
          indexingQueue.add(b);
        }
      }

      if (d.cursors.length == 1) {
        while (indexingQueue.isNotEmpty) {
          Block l = indexingQueue.last;
          if (d.cursor().block == l) break;
          indexingQueue.removeLast();
          indexer.indexWords(l.text);
          break;
        }
      }

      if (modifiedBlocks.isNotEmpty) {
        // todo janky >> debounce
        // onInputText..
        _showAutoCompleteMenu();
      } else {
        ui.clearPopups();
      }
    }

    StatusProvider status = Provider.of<StatusProvider>(context, listen: false);
    status.setIndexedStatus(0,
        'Ln ${((d.cursor().block?.line ?? 0) + 1)}, Col ${(d.cursor().column + 1)}');
  }

  Timer? debounceTimer;
  void _showAutoCompleteMenu() {
    if (debounceTimer != null) {
      debounceTimer?.cancel();
    }
    
    debounceTimer = Timer(const Duration(milliseconds: 400), () {
        Document d = doc.doc;
        AppProvider app = Provider.of<AppProvider>(context, listen: false);
        UIProvider ui = Provider.of<UIProvider>(context, listen: false);
    
        UIMenuData? menu = ui.menu('indexer::${d.documentId}');
        ui.setPopup(
            UIMenuPopup(key: ValueKey('indexer::${d.documentId}'),
              position: decor.caretPosition, alignY: 1, menu: menu),
            blur: false,
            shield: false);
            
        Cursor cur = d.cursor().copy();
        cur.moveCursorLeft();
        cur.selectWord();
        if (cur.column == d.cursor().column) {
          String t = cur.selectedText();
          if (t.length > 1) {
            indexer.find(t);
          }
        } else {
          ui.clearPopups();
        }
    });
  }
  
  void onKeyDown(String key,
      {int keyId = 0,
      bool shift = false,
      bool control = false,
      bool alt = false,
      bool softKeyboard = false,
      int code = 0}) {
    if (!softKeyboard) {
      shifting = shift;
      controlling = control;
      alting = alt;
    }

    if (key.startsWith('Arrow') || key == 'Tab') {
      _regainFocus();
    }

    Document d = doc.doc;
    lastHashCode = code;

    UIProvider ui = Provider.of<UIProvider>(context, listen: false);
    if (doc.softWrap && ui.popups.isEmpty && doc.doc.cursors.length == 1) {
      int curLine = doc.doc.cursor().block?.line ?? 0;
      switch (key) {
        case 'Arrow Up':
        case 'Arrow Down':
          {
            RenderObject? obj = context.findRenderObject();
            double move = decor.fontHeight / 2 +
                ((key == 'Arrow Up' ? -decor.fontHeight : decor.fontHeight));
            Offset pos =
                Offset(decor.caretPosition.dx, decor.caretPosition.dy + move);
            Offset o = screenToCursor(obj, pos);
            double dy = o.dy - curLine;
            if (dy * dy == 1) {
              onTapDown(obj, pos);
              return;
            }
          }
      }
    }

    switch (key) {
      case 'Insert':
        doc.overwriteMode = !doc.overwriteMode;
        doc.touch();
        break;
      case 'Escape':
      case 'Arrow Left':
      case 'Arrow Right':
      case 'Arrow Up':
      case 'Arrow Down':
      case 'Backspace':
      case 'Delete':
      case 'Tab':
      case 'Home':
      case 'End':
      case 'Enter':
      case '\n':
        command(
            buildKeys(key, control: controlling, shift: shifting, alt: alting));
        break;
      default:
        {
          int k = keyId;
          if ((k >= LogicalKeyboardKey.keyA.keyId &&
                  k <= LogicalKeyboardKey.keyZ.keyId) ||
              (k + 32 >= LogicalKeyboardKey.keyA.keyId &&
                  k + 32 <= LogicalKeyboardKey.keyZ.keyId)) {
            String ch =
                String.fromCharCode(97 + k - LogicalKeyboardKey.keyA.keyId);
            if (control || alt) {
              onShortcut(buildKeys(ch,
                  control: controlling, shift: shifting, alt: alting));
              break;
            }
            _commandInsert(ch);
            break;
          }
        }
        if (key.length == 1 || softKeyboard) {
          if (controlling || alting) {
            onShortcut(buildKeys(key,
                control: controlling, shift: shifting, alt: alting));
          } else {
            _commandInsert(key);
          }
        }
        break;
    }
  }

  void _commandInsert(String text) {
    Document d = doc.doc;
    command('insert', params: text);
    if (text.length == 1) {
      if (doc.overwriteMode) {
        d.deleteText();
      } else {
        d.autoClose(lang?.autoClose ?? {});
      }
    }
    if ((lang?.closingBrackets ?? []).indexOf(text) != -1) {
      d.eraseDuplicateClose(text);
    }
  }

  void onKeyUp() {
    if (shifting || controlling || alting) {
      setState(() {
        shifting = false;
        controlling = false;
        alting = false;
      });
    }
  }

  void onTapDown(RenderObject? obj, Offset globalPosition) {
    Offset o = screenToCursor(obj, globalPosition);
    if (shifting) {
      command('shift+cursor', params: [o.dy.toInt(), o.dx.toInt()]);
    } else {
      command('cursor', params: [o.dy.toInt(), o.dx.toInt()]);
    }
  }

  void onDoubleTapDown(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    command('cursor', params: [o.dy.toInt(), o.dx.toInt()]);
    command('select_word');
  }

  void onPanUpdate(RenderObject? obj, Offset globalPosition) {
    Document d = doc.doc;
    Offset o = screenToCursor(obj, globalPosition);
    if (o.dx == -1 || o.dy == -1) return;
    command('shift+cursor', params: [o.dy.toInt(), o.dx.toInt()]);
  }

  @override
  Widget build(BuildContext context) {
    bool hide = false;

    // todo refactor.. so editor can live outside of app
    AppProvider app = Provider.of<AppProvider>(context);
    if (!doc.pinned && widget.document != null) {
      if (app.document != doc.doc) {
        hide = true;
      }
    }

    HLTheme theme = Provider.of<HLTheme>(context);
    double buttonSize = 16.0;
    Color clr = theme.foreground;
    Color hiColor = theme.selection;

    List<Widget> buttons = !app.isKeyboardVisible
        ? []
        : <Widget>[
            IconButton(
                icon: Icon(Icons.undo, size: buttonSize, color: clr),
                onPressed: () {
                  command('undo');
                }),
            Container(
                decoration: controlling ? BoxDecoration(color: hiColor) : null,
                child: IconButton(
                    icon: Icon(Icons.south_west, size: buttonSize, color: clr),
                    onPressed: () {
                      setState(() {
                        controlling = !controlling;
                      });
                    })),
            Container(
                decoration: shifting ? BoxDecoration(color: hiColor) : null,
                child: IconButton(
                    icon: Icon(Icons.keyboard_capslock,
                        size: buttonSize, color: clr),
                    onPressed: () {
                      setState(() {
                        shifting = !shifting;
                      });
                    })),
            IconButton(
                icon: Icon(Icons.west, size: buttonSize, color: clr),
                onPressed: () {
                  command(
                      buildKeys('left', control: controlling, shift: shifting));
                }),
            IconButton(
                icon: Icon(Icons.north, size: buttonSize, color: clr),
                onPressed: () {
                  command(
                      buildKeys('up', control: controlling, shift: shifting));
                }),
            IconButton(
                icon: Icon(Icons.south, size: buttonSize, color: clr),
                onPressed: () {
                  command(
                      buildKeys('down', control: controlling, shift: shifting));
                }),
            IconButton(
                icon: Icon(Icons.east, size: buttonSize, color: clr),
                onPressed: () {
                  command(buildKeys('right',
                      control: controlling, shift: shifting));
                }),
            IconButton(
                icon: Icon(Icons.keyboard_tab, size: buttonSize, color: clr),
                onPressed: () {
                  command('tab');
                }),
            IconButton(
                icon: Icon(Icons.highlight_alt, size: buttonSize, color: clr),
                onPressed: () {
                  command('select_word');
                }),
            IconButton(
                icon: Icon(Icons.copy, size: buttonSize, color: clr),
                onPressed: () {
                  command('copy');
                }),
            IconButton(
                icon: Icon(Icons.cut, size: buttonSize, color: clr),
                onPressed: () {
                  command('cut');
                }),
            IconButton(
                icon: Icon(Icons.paste, size: buttonSize, color: clr),
                onPressed: () {
                  command('paste');
                }),
          ];

    doc.showMinimap = doc.showMinimap && app.showMinimap;
    doc.showGutter = doc.showGutter && app.showGutter;
    doc.softWrap = doc.softWrap && app.softWrap;

    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => doc),
          ChangeNotifierProvider(create: (context) => pulse),
          ChangeNotifierProvider(create: (context) => decor),
          Provider(create: (context) => highlighter),
        ],
        child: hide
            ? Container()
            : Expanded(
                child: Column(children: [
                Expanded(
                    child: Stack(children: [
                  Row(children: [
                    Expanded(
                        child: InputListener(
                            child:
                                View(key: PageStorageKey(doc.doc.documentId)),
                            focusNode: focusNode,
                            textFocusNode: textFocusNode,
                            onKeyDown: onKeyDown,
                            onKeyUp: onKeyUp,
                            onTapDown: onTapDown,
                            onDoubleTapDown: onDoubleTapDown,
                            onPanUpdate: onPanUpdate,
                            showKeyboard: app.showKeyboard)),
                    if (doc.showMinimap) ...[Minimap()]
                  ]),
                ])),

                if (Platform.isAndroid && app.isKeyboardVisible) ...[
                  Container(
                      child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: buttons)))
                ], // toolbar
              ])));
  }
}
