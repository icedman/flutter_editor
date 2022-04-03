import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/editor.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

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
                Text('${doc.fileName}', style: TextStyle(color: Colors.white)),
                InkWell(
                  canRequestFocus: false,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.close,
                          color: theme.comment, size: theme.fontSize)),
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

    return Material(
        color: darken(theme.background, 0.02),
        child: Row(children: [
          if (!app.fixedSidebar) ...[
            Container(
                height: app.tabbarHeight,
                child: IconButton(
                    onPressed: () {
                      app.openSidebar = true;
                      app.notifyListeners();
                    },
                    icon: Icon(Icons.vertical_split,
                        color: theme.comment, size: theme.fontSize)))
          ],
          TabBar(
              indicatorSize: TabBarIndicatorSize.label,
              indicator: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: theme.keyword, width: 1.5))),
              isScrollable: true,
              labelPadding: const EdgeInsets.only(left: 0, right: 0),
              tabs: tabs,
              onTap: (idx) {
                DefaultTabController.of(context)?.index = idx;
                app.document = app.documents[idx];
                app.notifyListeners();
              })
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
