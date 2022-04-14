import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as _path;

import 'package:editor/explorer/layout.dart';
import 'package:editor/explorer/explorer.dart';
import 'package:editor/services/ffi/bridge.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/ui/status.dart';
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

  // todo... move theme out of the parser
  TMParser()
    ..loadTheme(Platform.isAndroid
        ? '/sdcard/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json'
        : '/home/iceman/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json')
    ..loadIcons('material-icon-theme');

  HLTheme theme = HLTheme.instance();
  AppProvider app = AppProvider();
  UIProvider ui = UIProvider();
  StatusProvider status = StatusProvider();

  app.initialize();
  app.open(path);
  // app.open('./tests/sqlite3.c');

  ExplorerProvider explorer = ExplorerProvider();
  explorer.explorer.setRootPath(_path.dirname(path)).then((files) {
    explorer.explorer.root?.isExpanded = true;
    explorer.rebuild();
  });

  explorer.onSelect = (item) {
    if (!item.isDirectory) {
      if (!app.fixedSidebar) {
        app.openSidebar = false;
      }
      app.open(item.fullPath, focus: true);
    }
  };

  return runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (context) => app),
    ChangeNotifierProvider(create: (context) => ui),
    ChangeNotifierProvider(create: (context) => theme),
    ChangeNotifierProvider(create: (context) => explorer),
    ChangeNotifierProvider(create: (context) => status),
  ], child: App()));
}

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);

    ThemeData themeData = ThemeData(
      focusColor: Color.fromRGBO(0, 0, 0, 0.1),
      brightness: isDark(theme.background) ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: toMaterialColor(theme.background),
        accentColor: toMaterialColor(theme.background),
        brightness:
            isDark(theme.background) ? Brightness.dark : Brightness.light,
      ),
      errorColor: Colors.red,
      primarySwatch: toMaterialColor(darken(theme.background, sidebarDarken)),
      primaryColor: theme.comment,
      backgroundColor: theme.background,
      scaffoldBackgroundColor: theme.background,
      fontFamily: theme.uiFontFamily,
      //fontSize: theme.uiFontSize,
      textTheme: TextTheme().apply(
        bodyColor: theme.comment,
        displayColor: theme.comment,
        fontFamily: theme.uiFontFamily,
        //fontSize: theme.fontSize
      ),
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: const Color(0xc0c0c0c0).withOpacity(0.1),
        cursorColor: theme.comment,
        selectionHandleColor: const Color(0xc0c0c0c0).withOpacity(0.1),
      ),
      // scrollbarTheme: const ScrollbarThemeData().copyWith(
      //     thumbColor:
      //         MaterialStateProperty.all(const Color.fromRGBO(255, 255, 0, 0))),
    );

    return MaterialApp(
        debugShowCheckedModeBanner: false, theme: themeData, home: AppLayout());
  }
}
