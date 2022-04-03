import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

class ThemeColor extends Struct {
  @Int8()
  external int r;
  @Int8()
  external int g;
  @Int8()
  external int b;
}

class ThemeInfo extends Struct {
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
  external int sel_r;
  @Int8()
  external int sel_g;
  @Int8()
  external int sel_b;
}

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
