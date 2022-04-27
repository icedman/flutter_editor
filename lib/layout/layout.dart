import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:editor/editor/search.dart';
import 'package:editor/editor/decorations.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/layout/tabs.dart';
import 'package:editor/layout/statusbar.dart';
import 'package:editor/layout/explorer.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/indexer/filesearch.dart';
import 'package:editor/services/explorer/filesystem.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/ui/menu.dart';
import 'package:editor/services/ui/modal.dart';
import 'package:editor/services/ui/palette.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/keybindings.dart';

final int animteSidebarK = 250;

class Resizer extends StatefulWidget {
  Resizer(
      {double? this.width,
      double? this.height,
      Function? this.onStart,
      Function? this.onUpdate,
      Function? this.onEnd});

  Function? onStart;
  Function? onUpdate;
  Function? onEnd;
  double? width;
  double? height;

  @override
  _Resizer createState() => _Resizer();
}

class _Resizer extends State<Resizer> {
  Offset dragStart = Offset.zero;
  bool dragging = false;
  Size size = Size.zero;

  @override
  Widget build(BuildContext) {
    return MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
            child: Container(
                width: widget.width,
                height: widget.height,
                color: Colors.red.withOpacity(0)),
            onPanStart: (DragStartDetails details) {
              setState(() {
                dragStart = details.globalPosition;
                dragging = true;
                size = widget.onStart?.call(dragStart) ?? Size.zero;
              });
            },
            onPanUpdate: (DragUpdateDetails details) {
              Offset position = details.globalPosition;
              double dx = position.dx - dragStart.dx;
              double dy = position.dy - dragStart.dy;
              widget.onUpdate
                  ?.call(position, Size(size.width + dx, size.height + dy));
            },
            onPanEnd: (DragEndDetails details) {
              setState(() {
                dragging = false;
                widget.onEnd?.call();
              });
            }));
  }
}

class AppLayout extends StatefulWidget {
  @override
  _AppLayout createState() => _AppLayout();
}

class _AppLayout extends State<AppLayout> with WidgetsBindingObserver {
  bool _isKeyboardVisible =
      WidgetsBinding.instance!.window.viewInsets.bottom > 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    AppProvider app = Provider.of<AppProvider>(context, listen: false);
    UIProvider ui = Provider.of<UIProvider>(context, listen: false);
    final bottomInset = WidgetsBinding.instance!.window.viewInsets.bottom;
    final newValue = bottomInset > 0.0;
    if (newValue != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = newValue;
      });
    }

    app.bottomInset = bottomInset;

    double prevScreenWidth = app.screenWidth;

    app.isKeyboardVisible = _isKeyboardVisible;
    app.screenWidth = MediaQuery.of(context).size.width;
    app.screenHeight = MediaQuery.of(context).size.height;
    app.notifyListeners();

    if (prevScreenWidth != app.screenWidth) {
      if (app.sidebarWidth > app.screenWidth / 3) {
        app.openSidebar = false;
      } else {
        app.openSidebar = true;
      }
    }

    ui.clearPopups();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context);
    UIProvider ui = Provider.of<UIProvider>(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    app.screenWidth = screenWidth;
    app.screenHeight = screenHeight;
    app.isKeyboardVisible = _isKeyboardVisible;

    if (app.sidebarWidth > app.screenWidth / 3) {
      app.fixedSidebar = false;
    } else {
      app.fixedSidebar = true;
    }

    HLTheme theme = Provider.of<HLTheme>(context);
    TextStyle style = TextStyle(
        fontSize: theme.uiFontSize,
        fontFamily: theme.uiFontFamily,
        color: theme.comment);
    Size sz = getTextExtents('item', style);
    app.tabbarHeight = sz.height + 8;
    app.statusbarHeight = sz.height + 4;

    double sizerWidth = 10;
    bool showSidebar = (app.fixedSidebar && app.openSidebar) || app.openSidebar;
    // double statusbarHeight = 32;
    return DefaultTabController(
        animationDuration: Duration.zero,
        length: app.documents.length,
        child: Scaffold(
            body: Stack(children: [
          AnimatedPadding(
              curve: Curves.decelerate,
              duration: Duration(milliseconds: animteSidebarK),
              padding: EdgeInsets.only(
                  bottom: app.showStatusbar ? app.statusbarHeight : 0,
                  left: app.fixedSidebar && app.openSidebar
                      ? app.sidebarWidth
                      : 0),
              child: Column(children: [
                Container(
                  height: app.tabbarHeight,
                  child: EditorTabBar(),
                ),
                Expanded(child: EditorTabs())
              ])),

          if (!app.fixedSidebar && app.openSidebar) ...[
            GestureDetector(
                onTap: () {
                  app.openSidebar = false;
                  app.notifyListeners();
                },
                child: Container(
                    width: app.screenWidth,
                    height: app.screenHeight,
                    color: Colors.black.withOpacity(0.4))),
          ],

          // explorer
          AnimatedPositioned(
              left: showSidebar ? 0 : -app.sidebarWidth,
              curve: Curves.decelerate,
              duration: Duration(milliseconds: animteSidebarK),
              child: Padding(
                  padding: EdgeInsets.only(
                      bottom: app.showStatusbar ? app.statusbarHeight : 0),
                  child: ExplorerTree())),

          // resizer
          Padding(
              padding: EdgeInsets.only(
                  bottom: app.showStatusbar ? app.statusbarHeight : 0,
                  left: app.sidebarWidth),
              child: !showSidebar
                  ? Container()
                  : Resizer(
                      width: sizerWidth,
                      onStart: (position) {
                        return Size(app.sidebarWidth, 0);
                      },
                      onUpdate: (position, size) {
                        double w = size.width;
                        double h = size.height;
                        if (w < 100) {
                          w = 100;
                        }
                        if (w > 400) {
                          w = 400;
                        }
                        app.sidebarWidth = w;
                        app.notifyListeners();
                      },
                      onEnd: () {
                        app.saveSettings();
                      })),

          // statusbar
          if (app.showStatusbar) ...[
            Positioned(left: 0, right: 0, bottom: 0, child: Statusbar())
          ],

          // popups
          ...ui.popups.map((pop) => pop.widget ?? Container())
        ])));
  }
}

class TheApp extends StatefulWidget {
  @override
  _TheApp createState() => _TheApp();
}

class _TheApp extends State<TheApp> with WidgetsBindingObserver {
  late FocusNode focusNode;
  // late Timer timer;

  @override
  initState() {
    super.initState();
    focusNode = FocusNode(debugLabel: 'app');

    // timer = Timer.periodic(Duration(milliseconds: 500), (timer) {
    // if (!focusNode.hasFocus) {
    // focusNode.requestFocus();
    // }
    // });
  }

  @override
  dispose() {
    focusNode.dispose();
    // timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context, listen: false);
    UIProvider ui = Provider.of<UIProvider>(context, listen: false);

    final onSearchInFiles = (text,
        {int direction = 1,
        bool caseSensitive = false,
        bool regex = false,
        bool repeat = false,
        bool searchInFiles = false,
        String searchPath = '',
        String? replace}) {
      Document? resultDoc = app.open(':search.txt', focus: true);

      resultDoc?.decorators['search_result'] = SearchResultDecorator()
        ..text = text
        ..regex = regex
        ..caseSensitive = caseSensitive;

      resultDoc?.title = 'Search Results';
      resultDoc?.hideGutter = true;
      resultDoc?.clear();
      FileSearchProvider search =
          Provider.of<FileSearchProvider>(context, listen: false);
      search.onResult = (res) {
        search.onResult = null;
        if (res.length == 0) {
          resultDoc?.insertText('none found');
        }
        for (final r in res) {
          resultDoc?.insertText(r['file']);
          for (final m in r['matches'] ?? []) {
            resultDoc?.insertNewLine();
            // resultDoc?.insertText('```js');
            // resultDoc?.insertNewLine();
            resultDoc?.insertText(m['text']);
            resultDoc?.insertText(' [Ln ${m['lineNumber']}]');
            // resultDoc?.insertNewLine();
            // resultDoc?.insertText('```');
          }
          resultDoc?.insertNewLine();
          resultDoc?.insertNewLine();
        }
        app.notifyListeners();
        ui.clearPopups();
      };
      search.find(text,
          caseSensitive: caseSensitive, regex: regex, path: searchPath);
      ui.clearPopups();
    };

    return RawKeyboardListener(
      focusNode: focusNode,
      child: AppLayout(),
      autofocus: true,
      // regain focus
      onKey: (RawKeyEvent event) {
        if (event.runtimeType.toString() == 'RawKeyDownEvent') {
          String keys = buildKeys(event.logicalKey.keyLabel,
              control: event.isControlPressed,
              shift: event.isShiftPressed,
              alt: event.isAltPressed);

          Command? cmd = app.keybindings.resolve(keys, code: event.hashCode);
          switch (cmd?.command ?? '') {
            case 'cancel':
              ui.clearPopups();
              break;

            case 'close':
              app.close('');
              focusNode.requestFocus();
              break;

            case 'search_files':
              {
                ExplorerProvider explorer =
                    Provider.of<ExplorerProvider>(context, listen: false);
                UIProvider ui = Provider.of<UIProvider>(context, listen: false);
                UIMenuData? menu = ui.menu('palette::files', onSelect: (item) {
                  Future.delayed(const Duration(milliseconds: 50), () {
                    app.open(item.data, focus: true);
                  });
                });
                menu?.items.clear();
                menu?.menuIndex = -1;

                List<ExplorerItem?> files = explorer.explorer.files();
                for (final item in files) {
                  if (item == null) continue;
                  String relativePath = item.fullPath.substring(
                      (explorer.explorer.root?.fullPath ?? '').length);
                  menu?.items.add(UIMenuData()
                    ..title = item.fileName
                    ..subtitle = '.$relativePath'
                    ..data = item.fullPath);
                }

                Future.delayed(const Duration(milliseconds: 50), () {
                  ui.setPopup(UIPalettePopup(menu: menu, width: 500),
                      blur: false, shield: false);
                });

                break;
              }

            case 'search_text_in_files':
              {
                Future.delayed(const Duration(milliseconds: 50), () {
                  ui.setPopup(
                    SearchPopup(
                        searchFiles: true,
                        onSubmit: (text,
                            {int direction = 1,
                            bool caseSensitive = false,
                            bool regex = false,
                            bool repeat = false,
                            bool searchInFiles = false,
                            String searchPath = '',
                            String? replace}) {
                          onSearchInFiles.call(text,
                              direction: direction,
                              caseSensitive: caseSensitive,
                              regex: regex,
                              repeat: repeat,
                              searchPath: searchPath);
                        }),
                    blur: false,
                    shield: false,
                  );
                });

                break;
              }
          }
        }
        if (event.runtimeType.toString() == 'RawKeyUpEvent') {}
        // return KeyEventResult.ignored;
      },
    );
  }
}
