import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/editor.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/highlight/theme.dart';

class EditorTabBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context);
    HLTheme theme = Provider.of<HLTheme>(context);
    List<Widget> tabs = [];

    int idx = 0;
    for (final doc in app.documents) {
      bool isFocused = doc.docPath == app.document?.docPath;
      if (isFocused) idx = tabs.length;

      tabs.add(Tab(
          key: ValueKey(doc.documentId),
          child: Padding(
              padding: EdgeInsets.only(left: 10, right: 0),
              child: Row(children: [
                Text('${doc.fileName}',
                    style: TextStyle(
                        fontFamily: theme.uiFontFamily,
                        fontSize: theme.uiFontSize,
                        color: isFocused ? theme.foreground : theme.comment)),
                InkWell(
                  canRequestFocus: false,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.close,
                          color: theme.comment, size: theme.uiFontSize)),
                  onTap: () {
                    app.close(doc.docPath);
                  },
                )
              ]))));
    }

    // update tab index
    if (DefaultTabController.of(context)?.index != idx) {
      Future.delayed(const Duration(milliseconds: 100), () {
        DefaultTabController.of(context)?.index = idx;
      });
    }

    List<Widget> actions = [
      if (Platform.isAndroid) ...[
        IconButton(
            onPressed: () {
              app.showKeyboard = !app.showKeyboard;
              app.notifyListeners();
            },
            icon: Icon(
                app.isKeyboardVisible ? Icons.keyboard_hide : Icons.keyboard,
                color: theme.comment,
                size: theme.fontSize))
      ],
      IconButton(
          onPressed: () {
            app.openSidebar = true;
            app.notifyListeners();
          },
          icon: Icon(Icons.more_vert,
              color: theme.comment, size: theme.uiFontSize))
    ];

    return Material(
        color: darken(theme.background, tabbarDarken),
        child: Row(children: [
          IconButton(
              onPressed: () {
                app.openSidebar = !app.openSidebar;
                app.notifyListeners();
              },
              icon: Icon(Icons.vertical_split,
                  color: theme.comment, size: theme.uiFontSize)),
          TabBar(
              indicatorSize: TabBarIndicatorSize.label,
              indicator: BoxDecoration(
                  color: theme.background,
                  border: Border(
                      top: BorderSide(color: theme.keyword, width: 1.5))),
              isScrollable: true,
              labelPadding: const EdgeInsets.only(left: 0, right: 0),
              tabs: tabs,
              onTap: (idx) {
                DefaultTabController.of(context)?.index = idx;
                app.document = app.documents[idx];
                app.notifyListeners();
              }),
          Expanded(child: Container()),
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

    return Column(children: views);
  }
}
