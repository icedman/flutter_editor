import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/editor.dart';
import 'package:editor/explorer/explorer.dart';
import 'package:editor/ffi/bridge.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/tmparser.dart';
import 'package:editor/services/highlight/highlighter.dart';
import 'package:editor/services/explorer/filesystem.dart';
import 'package:editor/services/explorer/localfs.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  FFIBridge.load();

  AppProvider app = AppProvider();

  String extPath = '/home/iceman/.editor/extensions/';
  String path = './tests/tinywl.c';
  // path = './tests/sqlite3.c';

  if (Platform.isAndroid) {
    extPath = '/sdcard/.editor/extensions/';
    path = '/sdcard/Developer/tests/tinywl.c';
  }

  if (args.isNotEmpty) {
    path = args[0];
  }

  FFIBridge.initialize(extPath);
  TMParser(); // loads the theme

  HLTheme theme = HLTheme.instance();

  ExplorerProvider explorer = ExplorerProvider();
  explorer.explorer.setRootPath('./').then((files) {
    explorer.explorer.root?.isExpanded = true;
    explorer.rebuild();
  });

  return runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (context) => app),
    ChangeNotifierProvider(create: (context) => theme),
    ChangeNotifierProvider(create: (context) => explorer),
  ], child: App(path: path)));
}

class App extends StatelessWidget {
  App({String this.path = ''});

  String path = '';

  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);

    ThemeData themeData = ThemeData(
      fontFamily: 'FiraCode',
      primaryColor: theme.foreground,
      backgroundColor: theme.background,
      scaffoldBackgroundColor: theme.background,
    );

    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: themeData,
        home: Scaffold(
            body: Row(children: [
          ExplorerTree(),
          Expanded(
              child: Column(children: [
            Expanded(
                child: Padding(
                    padding: EdgeInsets.all(0), child: Editor(path: path))),
            // Expanded(
            //     child: Padding(
            //         padding: EdgeInsets.all(0), child: Editor(path: path))),
          ]))
        ])));
  }
}
