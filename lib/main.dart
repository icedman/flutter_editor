import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as _path;

import 'package:editor/layout/layout.dart';
import 'package:editor/layout/explorer.dart';
import 'package:editor/services/ffi/bridge.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/input.dart';
import 'package:editor/services/indexer/filesearch.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/ui/status.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/tmparser.dart';
import 'package:editor/services/keybindings.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  AppProvider app = AppProvider.instance();
  await app.initialize();
  await app.loadSettings();

  FFIBridge.load();

  String extPath = '/home/iceman/.editor/extensions/';
  String path = './';

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
    ..loadTheme(
        '/home/iceman/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json')
    // ..loadTheme('/home/iceman/.editor//extensions/theme-monokai/themes/monokai-color-theme.json')
    ..loadIcons('material-icon-theme');

  HLTheme theme = HLTheme.instance();
  UIProvider ui = UIProvider();
  StatusProvider status = StatusProvider();
  FileSearchProvider fileSearch = FileSearchProvider();

  String dirPath = path;
  if (!(await FileSystemEntity.isDirectory(path))) {
    app.open(path);
    app.openSidebar = false;
    dirPath = _path.dirname(path);
  }

  FocusNode focusNode = FocusNode();
  ExplorerProvider explorer = ExplorerProvider();
  explorer.explorer.setRootPath(dirPath).then((files) {
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
    Provider(create: (context) => fileSearch)
  ], child: App()));
}

class App extends StatelessWidget {
  App({FocusNode? this.focusNode});
  FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context, listen: false);
    UIProvider ui = Provider.of<UIProvider>(context, listen: false);
    HLTheme theme = Provider.of<HLTheme>(context);

    Brightness scheme = Brightness.light; // isDark(theme.background) ? Brightness.dark : Brightness.light;
    
    ThemeData themeData = ThemeData(
      focusColor: Color.fromRGBO(0, 0, 0, 0.1),
      brightness: scheme,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: toMaterialColor(theme.background),
        accentColor: toMaterialColor(theme.background),
        brightness: scheme,
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
        debugShowCheckedModeBanner: false,
        theme: themeData,
        home: Focus(
          focusNode: focusNode ?? FocusNode(),
          child: AppLayout(),
          autofocus: true,
          onKey: (FocusNode node, RawKeyEvent event) {
            if (event.runtimeType.toString() == 'RawKeyDownEvent') {
              String keys = buildKeys(event.logicalKey.keyLabel, 
                  control: event.isControlPressed,
                  shift: event.isShiftPressed,
                  alt: event.isAltPressed);
              
              switch (keys) {
                case 'cancel':
                  ui.clearPopups();
                  break;
              }

              // Command? cmd = app.keybindings.resolve(keys, code: event.hashCode);
              // print(cmd?.command);
            }
            if (event.runtimeType.toString() == 'RawKeyUpEvent') {}
            return KeyEventResult.handled;
          },
        ));
  }
}
