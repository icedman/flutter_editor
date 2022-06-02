import 'dart:ffi';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

import './highlighter.dart';

class FFIBridge {
  static late final DynamicLibrary nativeEditorApiLib;
  static late Function _initialize;
  static late Function load_theme;
  static late Function load_language;
  static late Function run_highlighter;
  static late Function create_document;
  static late Function destroy_document;
  static late Function add_block;
  static late Function remove_block;
  static late Function set_block;
  static late Function language_definition;
  static late Function theme_color;
  static late Function theme_info;
  static late Function load_icons;
  static late Function icon_for_filename;
  static late Function run_tree_sitter;
  static late Function has_running_threads;

  static bool initialized = false;

  static void load() {
    DynamicLibrary nativeEditorApiLib = Platform.isMacOS || Platform.isIOS
        ? DynamicLibrary.process()
        : (DynamicLibrary.open(
            Platform.isWindows ? 'editor_api.dll' : 'libeditor_api.so'));

    final _init_highlighter = nativeEditorApiLib
        .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('initialize');
    _initialize = _init_highlighter.asFunction<void Function(Pointer<Utf8>)>();

    final _load_theme = nativeEditorApiLib
        .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('load_theme');
    load_theme = _load_theme.asFunction<int Function(Pointer<Utf8>)>();

    final _load_icons = nativeEditorApiLib
        .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('load_icons');
    load_icons = _load_icons.asFunction<int Function(Pointer<Utf8>)>();

    final _icon_for_filename = nativeEditorApiLib
        .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>)>>(
            'icon_for_filename');
    icon_for_filename =
        _icon_for_filename.asFunction<Pointer<Utf8> Function(Pointer<Utf8>)>();

    final _thm_color = nativeEditorApiLib.lookup<
        NativeFunction<ThemeColor Function(Pointer<Utf8>)>>('theme_color');
    theme_color = _thm_color.asFunction<ThemeColor Function(Pointer<Utf8>)>();

    final _theme_info = nativeEditorApiLib
        .lookup<NativeFunction<ThemeInfo Function()>>('theme_info');
    theme_info = _theme_info.asFunction<ThemeInfo Function()>();

    final _load_language = nativeEditorApiLib
        .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('load_language');
    load_language = _load_language.asFunction<int Function(Pointer<Utf8>)>();

    final _run_highlighter = nativeEditorApiLib.lookup<
        NativeFunction<
            Pointer<TextSpanStyle> Function(Pointer<Utf8>, Int32, Int32, Int32,
                Int32, Int32, Int32, Int32)>>('run_highlighter');
    run_highlighter = _run_highlighter.asFunction<
        Pointer<TextSpanStyle> Function(
            Pointer<Utf8>, int, int, int, int, int, int, int)>();

    final _create_document = nativeEditorApiLib.lookup<
        NativeFunction<Void Function(Int32, Pointer<Utf8>)>>('create_document');
    create_document =
        _create_document.asFunction<void Function(int, Pointer<Utf8>)>();

    final _run_tree_sitter = nativeEditorApiLib.lookup<
        NativeFunction<Void Function(Int32, Pointer<Utf8>)>>('run_tree_sitter');
    run_tree_sitter =
        _run_tree_sitter.asFunction<void Function(int, Pointer<Utf8>)>();

    final _destroy_document = nativeEditorApiLib
        .lookup<NativeFunction<Void Function(Int32)>>('destroy_document');
    destroy_document = _destroy_document.asFunction<void Function(int)>();

    final _add_block = nativeEditorApiLib.lookup<
        NativeFunction<Void Function(Int32, Int32, Int32)>>('add_block');
    add_block = _add_block.asFunction<void Function(int, int, int)>();

    final _remove_block = nativeEditorApiLib.lookup<
        NativeFunction<Void Function(Int32, Int32, Int32)>>('remove_block');
    remove_block = _remove_block.asFunction<void Function(int, int, int)>();

    final _set_block = nativeEditorApiLib.lookup<
            NativeFunction<Void Function(Int32, Int32, Int32, Pointer<Utf8>)>>(
        'set_block');
    set_block =
        _set_block.asFunction<void Function(int, int, int, Pointer<Utf8>)>();

    final _language_definition = nativeEditorApiLib.lookup<
        NativeFunction<Pointer<Utf8> Function(Int32)>>('language_definition');
    language_definition =
        _language_definition.asFunction<Pointer<Utf8> Function(int)>();

    final _has_running_threads = nativeEditorApiLib
        .lookup<NativeFunction<Int32 Function()>>('has_running_threads');
    has_running_threads = _has_running_threads.asFunction<int Function()>();

    initialized = true;
  }

  static void initialize(String path) {
    final _path = path.toNativeUtf8();
    _initialize(_path);
    calloc.free(_path);
  }

  static void createDocument(int id, String path) {
    final _path = path.toNativeUtf8();
    create_document(id, _path);
    calloc.free(_path);
  }

  static void runTreeSitter(int id, String path) {
    final _path = path.toNativeUtf8();
    run_tree_sitter(id, _path);
    calloc.free(_path);
  }

  static int loadTheme(String path) {
    final _path = path.toNativeUtf8();
    int res = load_theme(_path);
    calloc.free(_path);
    return res;
  }

  static int loadIcons(String path) {
    final _path = path.toNativeUtf8();
    int res = load_icons(_path);
    calloc.free(_path);
    return res;
  }

  static String iconForFileName(String path) {
    final _path = path.toNativeUtf8();
    Pointer<Utf8> res = icon_for_filename(_path);
    calloc.free(_path);
    return res.toDartString();
  }

  static int loadLanguage(String path) {
    final _path = path.toNativeUtf8();
    int res = load_language(_path);
    calloc.free(_path);
    return res;
  }

  static String languageDefinition(int id) {
    Pointer<Utf8> res = language_definition(id);
    return res.toDartString();
  }

  // re-use pointers
  static Pointer<Uint8> result = malloc<Uint8>(1024);
  static Pointer<TextSpanStyle> runHighlighter(String text, int lang, int theme,
      int document, int block, int line, int prev, int next) {
    if (text.length > 1024 - 32) {
      return _runHighlighter(
          text, lang, theme, document, block, line, prev, next);
    }

    final units = utf8.encode(text);
    int l = units.length + 1;
    final Uint8List nativeString = result.asTypedList(l);
    nativeString.setAll(0, units);
    nativeString[units.length] = 0;

    Pointer<TextSpanStyle> res = run_highlighter(
        result.cast<Utf8>(), lang, theme, document, block, line, prev, next);

    return res;
  }

  static Pointer<TextSpanStyle> _runHighlighter(String text, int lang,
      int theme, int document, int block, int line, int prev, int next) {
    Pointer<Utf8> _t = text.toNativeUtf8();
    Pointer<TextSpanStyle> res =
        run_highlighter(_t, lang, theme, document, block, line, prev, next);
    calloc.free(_t);
    return res;
  }

  static void setBlock(int document, int block, int line, String text) {
    Pointer<Utf8> _t = text.toNativeUtf8();
    set_block(document, block, line, _t);
    calloc.free(_t);
  }

  static ThemeColor themeColor(String scope) {
    final _scope = scope.toNativeUtf8();
    ThemeColor res = theme_color(_scope);
    calloc.free(_scope);
    return res;
  }

  static void run(Function f) {
    if (!initialized) return;
    f.call();
  }
}
