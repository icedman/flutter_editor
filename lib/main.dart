import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as _path;

import 'package:editor/explorer/layout.dart';
import 'package:editor/explorer/tabbar.dart';
import 'package:editor/explorer/explorer.dart';
import 'package:editor/services/ffi/bridge.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/tmparser.dart';

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
  TMParser(); // loads the theme

  HLTheme theme = HLTheme.instance();
  AppProvider app = AppProvider();
  UIProvider ui = UIProvider();

  app.open(path);
  // app.open('./tests/sqlite3.c');

  ExplorerProvider explorer = ExplorerProvider();
  explorer.explorer.setRootPath(_path.dirname(path)).then((files) {
    explorer.explorer.root?.isExpanded = true;
    explorer.rebuild();
  });

  explorer.onSelect = (item) {
    if (!item.isDirectory) {
      app.openSidebar = false;
      app.open(item.fullPath, focus: true);
    }
  };

  return runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (context) => app),
    ChangeNotifierProvider(create: (context) => ui),
    ChangeNotifierProvider(create: (context) => theme),
    ChangeNotifierProvider(create: (context) => explorer),
  ], child: App()));
}

class App extends StatelessWidget {
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
        debugShowCheckedModeBanner: false, theme: themeData, home: AppLayout());
  }
}
