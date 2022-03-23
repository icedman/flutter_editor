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
  @Int8()
  external int tab;
}

final DynamicLibrary nativeEditorApiLib = Platform.isMacOS || Platform.isIOS
    ? DynamicLibrary.process()
    : (DynamicLibrary.open(
        Platform.isWindows ? 'editor_api.dll' : 'libeditor_api.so'));

final _init_highlighter = nativeEditorApiLib
    .lookup<NativeFunction<Void Function()>>('init_highlighter');
final init_highlighter = _init_highlighter.asFunction<void Function()>();

final _load_theme = nativeEditorApiLib
    .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('load_theme');
final load_theme = _load_theme.asFunction<int Function(Pointer<Utf8>)>();

final _load_language = nativeEditorApiLib
    .lookup<NativeFunction<Int32 Function(Pointer<Utf8>)>>('load_language');
final load_language = _load_language.asFunction<int Function(Pointer<Utf8>)>();

final _run_highlighter = nativeEditorApiLib.lookup<
    NativeFunction<
        Pointer<TextSpanStyle> Function(Pointer<Utf8>, Int32, Int32, Int32,
            Int32, Int32)>>('run_highlighter');
final run_highlighter = _run_highlighter.asFunction<
    Pointer<TextSpanStyle> Function(Pointer<Utf8>, int, int, int, int, int)>();

final _set_block = nativeEditorApiLib
    .lookup<NativeFunction<Void Function(Int32, Pointer<Utf8>)>>('set_block');
final set_block = _set_block.asFunction<void Function(int, Pointer<Utf8>)>();

void initHighlighter() {
  init_highlighter();
}

int loadTheme(String path) {
  final _path = path.toNativeUtf8();
  int res = load_theme(_path);
  calloc.free(_path);
  return res;
}

int loadLanguage(String path) {
  final _path = path.toNativeUtf8();
  int res = load_language(_path);
  calloc.free(_path);
  return res;
}

Pointer<TextSpanStyle> _runHighlighter(
    String text, int lang, int theme, int block, int prev, int next) {
  final _text = text.toNativeUtf8();
  Pointer<TextSpanStyle> res =
      run_highlighter(_text, lang, theme, block, prev, next);

  calloc.free(_text);
  return res;
}

// re-use pointers
Pointer<Uint8> result = malloc<Uint8>(32);
int resultLength = 32;

Pointer<TextSpanStyle> runHighlighter(
    String text, int lang, int theme, int block, int prev, int next) {
  final units = utf8.encode(text);
  int l = units.length + 1;

  if (l > resultLength) {
    calloc.free(result);

    resultLength = resultLength + 32;
    result = malloc<Uint8>(resultLength);
  }

  final Uint8List nativeString = result.asTypedList(l);
  nativeString.setAll(0, units);
  nativeString[units.length] = 0;

  Pointer<TextSpanStyle> res =
      run_highlighter(result.cast<Utf8>(), lang, theme, block, prev, next);

  return res;
}

void setBlock(int blockId, String text) {
  final units = utf8.encode(text);
  int l = units.length + 1;

  if (l > resultLength) {
    calloc.free(result);

    resultLength = resultLength + 32;
    result = malloc<Uint8>(resultLength);
  }

  final Uint8List nativeString = result.asTypedList(l);
  nativeString.setAll(0, units);
  nativeString[units.length] = 0;

  set_block(blockId, result.cast<Utf8>());
}
