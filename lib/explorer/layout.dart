import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:editor/explorer/tabbar.dart';
import 'package:editor/explorer/explorer.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/highlight/theme.dart';

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
        fontSize: theme.fontSize,
        fontFamily: theme.fontFamily,
        color: theme.comment);
    Size sz = getTextExtents('item', style);
    app.tabbarHeight = sz.height + 8;

    bool showSidebar = (app.fixedSidebar && app.openSidebar) || app.openSidebar;

    return DefaultTabController(
        animationDuration: Duration.zero,
        length: app.documents.length,
        child: Scaffold(
            body: Stack(children: [
          Padding(
              padding: EdgeInsets.only(
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
          Container(child: showSidebar ? ExplorerTree() : null),
          ...ui.popups
        ])));
  }
}
