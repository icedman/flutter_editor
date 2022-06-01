import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

class ThemeColor extends Struct {
  @Int16()
  external int r;
  @Int16()
  external int g;
  @Int16()
  external int b;
  @Int16()
  external int a;
}

class ThemeInfo extends Struct {
  @Int16()
  external int r;
  @Int16()
  external int g;
  @Int16()
  external int b;
  @Int16()
  external int a;
  @Int16()
  external int bg_r;
  @Int16()
  external int bg_g;
  @Int16()
  external int bg_b;
  @Int16()
  external int bg_a;
  @Int16()
  external int sel_r;
  @Int16()
  external int sel_g;
  @Int16()
  external int sel_b;
  @Int16()
  external int sel_a;
  @Int16()
  external int cmt_r;
  @Int16()
  external int cmt_g;
  @Int16()
  external int cmt_b;
  @Int16()
  external int cmt_a;
  @Int16()
  external int fn_r;
  @Int16()
  external int fn_g;
  @Int16()
  external int fn_b;
  @Int16()
  external int fn_a;
  @Int16()
  external int kw_r;
  @Int16()
  external int kw_g;
  @Int16()
  external int kw_b;
  @Int16()
  external int kw_a;
  @Int16()
  external int var_r;
  @Int16()
  external int var_g;
  @Int16()
  external int var_b;
  @Int16()
  external int var_a;
}

class TextSpanStyle extends Struct {
  @Int32()
  external int start;
  @Int32()
  external int length;
  @Int32()
  external int flags;
  @Int16()
  external int r;
  @Int16()
  external int g;
  @Int16()
  external int b;
  @Int16()
  external int a;
  @Int16()
  external int bg_r;
  @Int16()
  external int bg_g;
  @Int16()
  external int bg_b;
  @Int16()
  external int bg_a;
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
