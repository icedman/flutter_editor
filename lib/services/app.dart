import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as _path;
import 'package:path_provider/path_provider.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/keybindings.dart';

const bool LIGHT_MODE = false;
const String ashlarCodeURL =
    'https://play.google.com/store/apps/details?id=com.munchyapps.ashlar';

const String appResourceRoot = '~/.editor';
const double configVersion = 1.1;
late Directory root;
String expandPath(String path) {
  String res = path.replaceAll('~', root.parent.absolute.path);
  print(res);
  return res;
}

Future<ByteData> loadFontFile(String path) async {
  try {
    File file =
        await File(expandPath('$appResourceRoot/fonts/$path'));
    Uint8List bytes = await file.readAsBytes();
    return ByteData.view(bytes.buffer);
  } catch (err, msg) {
    print('unable to load font file');
    return ByteData(0);
  }
}

Map<String, bool> fontsLoaded = Map<String, bool>();
Future<void> loadFont(String family, String path) async {
  if (fontsLoaded.containsKey(family)) {
    return;
  }
  fontsLoaded[family] = true;
  try {
    FontLoader loader = FontLoader(family);
    loader.addFont(loadFontFile(path));
    print(path);
    return loader.load();
  } catch (err, msg) {
    print('unable to load fonts');
  }
}


class AppProvider extends ChangeNotifier {
  List<Document> documents = [];
  Document? document;
  dynamic settings;

  late Keybindings keybindings;

  double bottomInset = 0;
  double screenWidth = 0;
  double screenHeight = 0;
  double sidebarWidth = 240;
  double tabbarHeight = 32;
  double statusbarHeight = 32;

  bool showStatusbar = true;
  bool showTabbar = true;
  bool fixedSidebar = true;
  bool openSidebar = true;

  bool showKeyboard = false;
  bool isKeyboardVisible = false;

  bool extracting = false;
  String extractingWhat = '';
  bool resourcesReady = false;

  void initialize() async {
    root = await getApplicationDocumentsDirectory();
    keybindings = Keybindings();
    configure();
  }

  Document? open(String path, {bool focus = false}) {
    String p = _path.normalize(Directory(path).absolute.path);
    for (final d in documents) {
      if (d.docPath == p) {
        if (focus) {
          document = d;
          notifyListeners();
        }
        return d;
      }
    }
    Document doc = Document(path: path);
    documents.add(doc);
    if (focus || documents.length == 1) {
      document = doc;
    }
    notifyListeners();
    return doc;
  }

  void close(String path) {
    String p = _path.normalize(Directory(path).absolute.path);
    document = null;
    for (final d in documents) {
      if (d.docPath == p) {
        documents.removeWhere((d) {
          if (d.docPath == p) {
            d.dispose();
            return true;
          }
          return false;
        });
        notifyListeners();
        break;
      }
      document = d;
    }
    if (document == null && documents.length > 0) {
      document = documents[0];
    }
  }

  Future<void> setupResources({bool upgrade = false}) async {
    if (upgrade) {
      print('upgrade resources');
    }

    var configPath = expandPath('$appResourceRoot/config.json');
    bool exists = File(configPath).existsSync();
    if (!exists || upgrade) {
      extracting = true;

      // ssl
      final d = Directory('$appResourceRoot/.ssh');
      if (await d.exists()) {
        try {
          d.create();
        } catch (err, msg) {}
      }

      print('extracing archive...');
      await extractArchive(
          'extensions.zip', expandPath('$appResourceRoot/'));

      print('writing default config');

      List<String> files = <String>[
        'config.default.json',
        // 'about.md',
        // 'help.md',
        // 'LICENSES',
        // 'themes.json'
      ];

      for (final f in files) {
        String contents = await getTextFileFromAsset(f);
        final target = await File(expandPath('$appResourceRoot/$f'));
        await target.writeAsString(contents);
        //extractingWhat = f;
        //notifyListeners();
      }

      if (!upgrade || !exists) {
        String config_text = await getTextFileFromAsset('config.json');
        final config =
            await File(expandPath('$appResourceRoot/config.json'));
        await config.writeAsString(config_text);
      }

      resourcesReady = true;
      extracting = false;
      extractingWhat = '';
    } else {
      resourcesReady = true;
      extracting = false;
      extractingWhat = '';
    }
  }

  Future<void> updateResources({bool force = false}) async {
    List<String> files = <String>['themes.json'];

    for (final f in files) {
      String contents = await getTextFileFromAsset(f);
      final target = await File(expandPath('$appResourceRoot/$f'));
      if (force || !target.existsSync()) {
        await target.writeAsString(contents);
      }
    }
  }

  bool isReady() {
    return resourcesReady; // && permissionStatus == PermissionStatus.granted;
  }

  void configure() async {
    bool configFound = await File('$appResourceRoot/config.json').exists();
    if (!configFound) {
      await setupResources();
      extracting = false;
      notifyListeners();
    } else {
      updateResources();
      resourcesReady = true;
      extracting = false;
    }
  }
}
