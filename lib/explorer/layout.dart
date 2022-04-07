import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:editor/explorer/tabbar.dart';
import 'package:editor/explorer/statusbar.dart';
import 'package:editor/explorer/explorer.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/highlight/theme.dart';

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
    return GestureDetector(
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
        });
  }
}

class AppLayout extends StatefulWidget {
  @override
  _AppLayout createState() => _AppLayout();
}

class _AppLayout extends State<AppLayout> with WidgetsBindingObserver {
  _AppLayout();

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

    app.isKeyboardVisible = _isKeyboardVisible;
    app.screenWidth = MediaQuery.of(context).size.width;
    app.screenHeight = MediaQuery.of(context).size.height;
    app.notifyListeners();

    if (app.sidebarWidth > app.screenWidth / 3) {
      app.openSidebar = false;
    } else {
      app.openSidebar = true;
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
          // main content (tabbar & tabs)
          Padding(
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
          Padding(
              padding: EdgeInsets.only(
                  bottom: app.showStatusbar ? app.statusbarHeight : 0),
              child: showSidebar ? ExplorerTree() : null),

          Padding(
              padding: EdgeInsets.only(
                  bottom: app.showStatusbar ? app.statusbarHeight : 0,
                  left: ((app.fixedSidebar && app.openSidebar)
                          ? app.sidebarWidth
                          : 0) -
                      sizerWidth / 2),
              child: Resizer(
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
                  onEnd: () {})),

          // statusbar
          if (app.showStatusbar) ...[
            Positioned(left: 0, right: 0, bottom: 0, child: Statusbar())
          ],

          // popups
          ...ui.popups
        ])));
  }
}
