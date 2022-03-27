import 'dart:io';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/document.dart';
import 'package:editor/editor/view.dart';
import 'package:editor/services/highlight/highlighter.dart';

Offset screenToCursor(RenderObject? obj, Offset pos) {
  List<RenderParagraph> pars = <RenderParagraph>[];
  findRenderParagraphs(obj, pars);

  RenderParagraph? lastPar;
  RenderParagraph? targetPar;
  int line = -1;

  for (final par in pars) {
    if (((par.text as TextSpan).children?.length ?? 0) > 0) lastPar = par;
    TextSpan t = par.text as TextSpan;
    Rect bounds = const Offset(0, 0) & par.size;
    Offset offsetForCaret = par.localToGlobal(
        par.getOffsetForCaret(const TextPosition(offset: 0), bounds));
    Rect parBounds =
        offsetForCaret & Size(par.size.width * 100, par.size.height);
    if (parBounds.inflate(2).contains(pos)) {
      targetPar = par;
      break;
    }
  }

  if (targetPar == null && lastPar != null) {
    List<InlineSpan> children =
        (lastPar.text as TextSpan).children ?? <InlineSpan>[];
    if (children.length > 0 && children.last is CustomWidgetSpan) {
      line = (children.last as CustomWidgetSpan).line;
    }
    int textOffset = -1;
    return Offset(textOffset.toDouble(), line.toDouble());
  }
  if (targetPar == null) return Offset(-1, -1);

  Rect bounds = const Offset(0, 0) & targetPar.size;
  List<InlineSpan> children =
      (targetPar.text as TextSpan).children ?? <InlineSpan>[];
  Size fontCharSize = Size(0, 0);
  int textOffset = 0;
  bool found = false;

  int nearestOffset = 0;
  double nearest = -1;

  for (var span in children) {
    if (found) break;
    if (!(span is TextSpan)) {
      continue;
    }

    if (fontCharSize.width == 0) {
      fontCharSize = getTextExtents(' ', span.style ?? TextStyle());
    }

    String txt = (span as TextSpan).text ?? '';
    for (int i = 0; i < txt.length + 1; i++) {
      Offset offsetForCaret = targetPar.localToGlobal(targetPar
          .getOffsetForCaret(TextPosition(offset: textOffset), bounds));

      Rect charBounds = offsetForCaret & fontCharSize;
      if (charBounds.inflate(2).contains(Offset(pos.dx + 2, pos.dy + 1))) {
        found = true;
        break;
      }

      double dx = offsetForCaret.dx - pos.dx;
      double dy = offsetForCaret.dy - (pos.dy - 4);
      double dst = sqrt((dx * dx) + (dy * dy));

      if (sqrt(dy * dy) > fontCharSize.height) {
        dst += 1000;
      }

      if (nearest > dst || nearest == -1) {
        nearest = dst;
        nearestOffset = textOffset;
      }
      textOffset++;
    }
  }

  if (children.length > 0 && children.last is CustomWidgetSpan) {
    line = (children.last as CustomWidgetSpan).line;
    Block? block = (children.last as CustomWidgetSpan).block;
    line = block?.line ?? line;
  }

  if (!found) {
    textOffset = nearestOffset;
  }

  return Offset(textOffset.toDouble(), line.toDouble());
}

void findRenderParagraphs(RenderObject? obj, List<RenderParagraph> res) {
  if (obj is RenderParagraph) {
    res.add(obj);
    return;
  }
  obj?.visitChildren((child) {
    findRenderParagraphs(child, res);
  });
}

class CustomEditingController extends TextEditingController {
  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    return const TextSpan();
  }
}

class InputListener extends StatefulWidget {
  late Widget child;
  Function? onKeyDown;
  Function? onKeyUp;
  Function? onTapDown;
  Function? onDoubleTapDown;
  Function? onPanUpdate;

  bool showKeyboard = false;

  InputListener(
      {required Widget this.child,
      Function? this.onKeyDown,
      Function? this.onKeyUp,
      Function? this.onTapDown,
      Function? this.onDoubleTapDown,
      Function? this.onPanUpdate,
      bool this.showKeyboard = false});
  @override
  _InputListener createState() => _InputListener();
}

class _InputListener extends State<InputListener> {
  late FocusNode focusNode;
  late FocusNode textFocusNode;
  late TextEditingController controller;

  Offset lastTap = const Offset(0, 0);

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    textFocusNode = FocusNode();
    controller = CustomEditingController();

    controller.addListener(() {
      final t = controller.text;
      if (t.isNotEmpty) {
        widget.onKeyDown?.call(t,
            keyId: 0,
            shift: false,
            control: false,
            alt: false,
            softKeyboard: true);
      }
      controller.text = '';
    });

    // if (widget.showKeyboard) {
    //   Future.delayed(Duration(milliseconds: 50), () {
    //     textFocusNode.requestFocus();
    //   });
    // }
  }

  @override
  void dispose() {
    super.dispose();
    focusNode.dispose();
    textFocusNode.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    Document d = doc.doc;
    return Focus(
        onFocusChange: (focused) {
          // if (focused && !textFocusNode.hasFocus) {
          //   textFocusNode.requestFocus();
          // }
        },
        child: Column(children: [
          Expanded(
              child: GestureDetector(
                  child: widget.child,
                  onTapUp: (TapUpDetails details) {
                    lastTap = details.globalPosition;
                  },
                  onTapDown: (TapDownDetails details) {
                    if (!focusNode.hasFocus) {
                      focusNode.requestFocus();
                      textFocusNode.unfocus();
                      FocusScope.of(context).unfocus();
                    }
                    if (!textFocusNode.hasFocus) {
                      textFocusNode.requestFocus();
                    }
                    widget.onTapDown?.call(
                        context.findRenderObject(), details.globalPosition);
                  },
                  onDoubleTapDown: (TapDownDetails details) {
                    lastTap = details.globalPosition;
                  },
                  onDoubleTap: () {
                    widget.onDoubleTapDown
                        ?.call(context.findRenderObject(), lastTap);
                  },
                  onPanUpdate: (DragUpdateDetails details) {
                    widget.onPanUpdate?.call(
                        context.findRenderObject(), details.globalPosition);
                  },
                  onLongPressMoveUpdate: (LongPressMoveUpdateDetails details) {
                    widget.onPanUpdate?.call(
                        context.findRenderObject(), details.globalPosition);
                  })),

          // TextField(focusNode: textFocusNode, controller: controller, autofocus: true,
          // maxLines: null,
          // enableInteractiveSelection: false,)

          Container(
              width: 1,
              height: 1,
              child: !widget.showKeyboard
                  ? null
                  : TextField(
                      focusNode: textFocusNode,
                      autofocus: true,
                      maxLines: null,
                      enableInteractiveSelection: false,
                      decoration:
                          const InputDecoration(border: InputBorder.none),
                      controller: controller))
        ]),
        focusNode: focusNode,
        autofocus: true,
        onKey: (FocusNode node, RawKeyEvent event) {
          // if (textFocusNode.hasFocus) {
          //   return KeyEventResult.ignored;
          // }
          if (event.runtimeType.toString() == 'RawKeyDownEvent') {
            widget.onKeyDown?.call(event.logicalKey.keyLabel,
                keyId: event.logicalKey.keyId,
                shift: event.isShiftPressed,
                control: event.isControlPressed,
                alt: event.isAltPressed);
          }
          if (event.runtimeType.toString() == 'RawKeyUpEvent') {
            widget.onKeyUp?.call();
          }
          return KeyEventResult.handled;
        });
  }
}
