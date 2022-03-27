import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/editor.dart';
import 'package:editor/ffi/bridge.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  FFIBridge.load();

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

  return runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (context) => HLTheme.instance()),
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
            body: Column(children: [
          Expanded(
              child: Padding(
                  padding: EdgeInsets.all(0), child: Editor(path: path))),
        ])));
  }
}
