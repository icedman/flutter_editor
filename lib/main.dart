import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor.dart';
import 'package:editor/theme.dart';
import 'package:editor/native.dart';
import 'package:editor/services/highlighter.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  FFIBridge.initialize();

  ThemeData themeData = ThemeData(
    fontFamily: 'FiraCode',
    primaryColor: theme.foreground,
    backgroundColor: theme.background,
    scaffoldBackgroundColor: theme.background,
  );

  String path = './tests/tinywl.c';
  if (Platform.isAndroid) path = '/sdcard/Developer/tests/tinywl.c';
  // String path = './tests/sqlite3.c';
  if (args.isNotEmpty) {
    path = args[0];
  }

  return runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeData,
      home: Scaffold(
          body: Column(children: [
        Expanded(
            child:
                Padding(padding: EdgeInsets.all(0), child: Editor(path: path))),
        // Expanded(
        //     child:
        //         Padding(padding: EdgeInsets.all(0), child: Editor(path: path))),
      ]))));
}
