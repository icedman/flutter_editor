import 'dart:ffi';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';

class TextSpanStyle extends Struct {
  @Int32()
  external int start;
  @Int32()
  external int length;
  @Int32()
  external int flags;
  @Int8()
  external int r;
  @Int8()
  external int g;
  @Int8()
  external int b;
  @Int8()
  external int bg_r;
  @Int8()
  external int bg_g;
  @Int8()
  external int bg_b;
  @Int8()
  external int caret;
  @Int8()
  external int bold;
  @Int8()
  external int italic;
  @Int8()
  external int underline;
  @Int8()
  external int strike;
}

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
  static late Function language_definition;

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

    final _load_language = nativeEditorApiLib
        .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('load_language');
    load_language = _load_language.asFunction<int Function(Pointer<Utf8>)>();

    final _run_highlighter = nativeEditorApiLib.lookup<
        NativeFunction<
            Pointer<TextSpanStyle> Function(Pointer<Utf8>, Int32, Int32, Int32,
                Int32, Int32, Int32)>>('run_highlighter');
    run_highlighter = _run_highlighter.asFunction<
        Pointer<TextSpanStyle> Function(
            Pointer<Utf8>, int, int, int, int, int, int)>();

    final _create_document = nativeEditorApiLib
        .lookup<NativeFunction<Void Function(Int32)>>('create_document');
    create_document = _create_document.asFunction<void Function(int)>();

    final _destroy_document = nativeEditorApiLib
        .lookup<NativeFunction<Void Function(Int32)>>('destroy_document');
    destroy_document = _destroy_document.asFunction<void Function(int)>();

    final _add_block = nativeEditorApiLib
        .lookup<NativeFunction<Void Function(Int32, Int32)>>('add_block');
    add_block = _add_block.asFunction<void Function(int, int)>();

    final _remove_block = nativeEditorApiLib
        .lookup<NativeFunction<Void Function(Int32, Int32)>>('remove_block');
    remove_block = _remove_block.asFunction<void Function(int, int)>();

    final _language_definition = nativeEditorApiLib.lookup<
        NativeFunction<Pointer<Utf8> Function(Int32)>>('language_definition');
    language_definition =
        _language_definition.asFunction<Pointer<Utf8> Function(int)>();
  }

  static void initialize(String path) {
    final _path = path.toNativeUtf8();
    _initialize(_path);
    calloc.free(_path);
  }

  static int loadTheme(String path) {
    final _path = path.toNativeUtf8();
    int res = load_theme(_path);
    calloc.free(_path);
    return res;
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
      int document, int block, int prev, int next) {
    if (text.length > 1024 - 32) {
      return _runHighlighter(text, lang, theme, document, block, prev, next);
    }

    final units = utf8.encode(text);
    int l = units.length + 1;
    final Uint8List nativeString = result.asTypedList(l);
    nativeString.setAll(0, units);
    nativeString[units.length] = 0;

    Pointer<TextSpanStyle> res = run_highlighter(
        result.cast<Utf8>(), lang, theme, document, block, prev, next);

    return res;
  }

  static Pointer<TextSpanStyle> _runHighlighter(String text, int lang,
      int theme, int document, int block, int prev, int next) {
    Pointer<Utf8> _t = text.toNativeUtf8();
    Pointer<TextSpanStyle> res =
        run_highlighter(_t, lang, theme, document, block, prev, next);
    calloc.free(_t);
    return res;
  }
}
