import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'editor.dart';
import 'highlighter.dart';
import 'theme.dart';

void main() async {
  ThemeData themeData = ThemeData(
    fontFamily: 'FiraCode',
    primaryColor: foreground,
    backgroundColor: background,
    scaffoldBackgroundColor: background,
  );
  return runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeData,
      home: Scaffold(body: Editor(path: './tests/tinywl.c'))));
}
