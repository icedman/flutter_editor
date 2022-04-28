import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/editor.dart';
import 'package:editor/layout/explorer.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/ui/menu.dart';
import 'package:editor/services/ui/status.dart';
import 'package:editor/services/ffi/bridge.dart';
import 'package:editor/services/highlight/theme.dart';

class TabIconButton extends StatelessWidget {
  TabIconButton({Widget? this.icon, Function? this.onPressed}) : super();

  Widget? icon;
  Function? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
        canRequestFocus: false,
        child: Padding(
            padding: EdgeInsets.all(4),
            child: Container(width: 32, height: 32, child: icon)),
        onTap: () {
          onPressed?.call();
        });
  }
}

class EditorTabBar extends StatefulWidget {
  @override
  _EditorTabBar createState() => _EditorTabBar();
}

class _EditorTabBar extends State<EditorTabBar> {
  late ScrollController scroller;
  @override
  void initState() {
    super.initState();
    scroller = ScrollController();
  }

  @override
  void dispose() {
    scroller.dispose();
    super.dispose();
  }

  void showContextMenu(BuildContext context) {
    RenderObject? obj = context.findRenderObject();
    if (obj != null) {
      RenderBox? box = obj as RenderBox;
      Offset position = box.localToGlobal(Offset(box.size.width, 0));
      UIProvider ui = Provider.of<UIProvider>(context, listen: false);
      UIMenuData? menu = ui.menu('explorer::context');
      menu?.items.clear();
      menu?.menuIndex = -1;
      for (final s in ['New Folder', 'New File']) {
        menu?.items.add(UIMenuData()..title = s);
      }
      ui.setPopup(
          UIMenuPopup(position: position, alignX: 0, alignY: 1, menu: menu),
          blur: false,
          shield: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context);
    HLTheme theme = Provider.of<HLTheme>(context);
    List<Widget> tabs = [];

    int idx = 0;
    for (final doc in app.documents) {
      bool isFocused = doc.docPath == app.document?.docPath;
      if (isFocused) idx = tabs.length;

      String iconPath = FFIBridge.iconForFileName(doc.fileName);
      Widget fileIcon = FileIcon(path: iconPath, size: theme.uiFontSize + 2);

      String title = doc.title.length > 0 ? doc.title : doc.fileName;
      tabs.add(Tab(
          key: ValueKey(doc.documentId),
          child: Padding(
              padding: EdgeInsets.only(left: 10, right: 0),
              child: Row(children: [
                fileIcon,
                Text(' $title',
                    style: TextStyle(
                        fontFamily: theme.uiFontFamily,
                        fontSize: theme.uiFontSize,
                        letterSpacing: -0.5,
                        color: isFocused ? theme.foreground : theme.comment)),
                InkWell(
                  canRequestFocus: false,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.close,
                          color: isFocused ? theme.foreground : theme.comment,
                          size: theme.uiFontSize)),
                  onTap: () {
                    app.close(doc.docPath);
                  },
                )
              ]))));
    }

    // update tab index
    if (DefaultTabController.of(context)?.index != idx || tabs.length == 0) {
      Future.delayed(const Duration(milliseconds: 100), () {
        DefaultTabController.of(context)?.index = idx;
        StatusProvider status =
            Provider.of<StatusProvider>(context, listen: false);
        status.setIndexedStatus(0, '');
      });
    }

    List<Widget> actions = [
      if (Platform.isAndroid) ...[
        TabIconButton(
            onPressed: () {
              app.showKeyboard = !app.showKeyboard;
              app.notifyListeners();
            },
            icon: Icon(
                app.isKeyboardVisible ? Icons.keyboard_hide : Icons.keyboard,
                color: theme.comment,
                size: theme.fontSize))
      ],
      TabIconButton(
          onPressed: () {
            showContextMenu(context);
          },
          icon: Icon(Icons.more_vert,
              color: theme.comment, size: theme.uiFontSize))
    ];

    return Material(
        color: darken(theme.background, tabbarDarken),
        child: Row(children: [
          TabIconButton(
              onPressed: () {
                app.openSidebar = !app.openSidebar;
                app.notifyListeners();
              },
              icon: Icon(Icons.vertical_split,
                  color: theme.comment, size: theme.uiFontSize)),
          Expanded(
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                      indicatorSize: TabBarIndicatorSize.label,
                      indicator: BoxDecoration(
                          color: theme.background,
                          border: Border(
                              top: BorderSide(
                                  color: theme.keyword, width: 1.5))),
                      isScrollable: true,
                      labelPadding: const EdgeInsets.only(left: 0, right: 0),
                      tabs: tabs,
                      onTap: (idx) {
                        DefaultTabController.of(context)?.index = idx;
                        app.document = app.documents[idx];
                        app.notifyListeners();
                        StatusProvider status =
                            Provider.of<StatusProvider>(context, listen: false);
                        status.setIndexedStatus(0, '');
                      }))),
          ...actions
        ]));
  }
}

class EditorTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context);
    List<Widget> views = [];

    for (final doc in app.documents) {
      String path = doc.docPath;
      views.add(Editor(
          key: PageStorageKey(doc.documentId), path: path, document: doc));
    }

    if (views.length == 0) {
      return Container();
    }

    return Row(children: views);
  }
}
