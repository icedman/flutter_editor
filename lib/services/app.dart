import 'dart:io';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as _path;
import 'package:editor/editor/document.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/keybindings.dart';

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

  void initialize() async {
    keybindings = Keybindings();
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
}
