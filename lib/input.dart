import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'document.dart';
import 'view.dart';
import 'highlighter.dart';

Offset screenToCursor(RenderObject? obj, Offset pos) {
  List<RenderParagraph> pars = <RenderParagraph>[];
  findRenderParagraphs(obj, pars);

  RenderParagraph? targetPar;
  int line = -1;

  for (final par in pars) {
    TextSpan t = par.text as TextSpan;
    Rect bounds = const Offset(0, 0) & par.size;
    Offset offsetForCaret = par.localToGlobal(
        par.getOffsetForCaret(const TextPosition(offset: 0), bounds));
    Rect parBounds =
        offsetForCaret & Size(par.size.width * 10, par.size.height);
    if (parBounds.inflate(2).contains(pos)) {
      targetPar = par;
      break;
    }
  }

  if (targetPar == null) return Offset(-1, -1);

  Rect bounds = const Offset(0, 0) & targetPar.size;
  List<InlineSpan> children =
      (targetPar.text as TextSpan).children ?? <InlineSpan>[];
  Size fontCharSize = Size(0, 0);
  int textOffset = 0;
  bool found = false;
  for (var span in children) {
    if (found) break;
    if (!(span is TextSpan)) {
      continue;
    }

    if (fontCharSize.width == 0) {
      fontCharSize = getTextExtents(' ', span.style ?? TextStyle());
    }

    String txt = (span as TextSpan).text ?? '';
    for (int i = 0; i < txt.length; i++) {
      Offset offsetForCaret = targetPar.localToGlobal(targetPar
          .getOffsetForCaret(TextPosition(offset: textOffset), bounds));
      Rect charBounds = offsetForCaret & fontCharSize;
      if (charBounds.inflate(2).contains(Offset(pos.dx + 1, pos.dy + 1))) {
        found = true;
        break;
      }
      textOffset++;
    }
  }

  if (children.length > 0 && children.last is CustomWidgetSpan) {
    line = (children.last as CustomWidgetSpan).line;
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

class InputListener extends StatefulWidget {
  late Widget child;
  Function? onKeyDown;
  Function? onKeyUp;
  Function? onTapDown;
  Function? onPanUpdate;

  InputListener({required Widget this.child,
    Function? this.onKeyDown,
    Function? this.onKeyUp,
    Function? this.onTapDown,
    Function? this.onPanUpdate
    });
  @override
  _InputListener createState() => _InputListener();
}

class _InputListener extends State<InputListener> {
  late FocusNode focusNode;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
  }

  @override
  void dispose() {
    super.dispose();
    focusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }

    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    Document d = doc.doc;
    return GestureDetector(
        child: Focus(
            child: widget.child,
            focusNode: focusNode,
            autofocus: true,
            onKey: (FocusNode node, RawKeyEvent event) {
              if (event.runtimeType.toString() == 'RawKeyDownEvent') {
                widget.onKeyDown?.call(event.logicalKey.keyLabel,
                  keyId: event.logicalKey.keyId, 
                  shift: event.isShiftPressed,
                  control: event.isControlPressed);
              }
              if (event.runtimeType.toString() == 'RawKeyUpEvent') {
                widget.onKeyUp?.call();
              }
              return KeyEventResult.handled;
            }),
        onTapDown: (TapDownDetails details) {
          widget.onTapDown?.call(context.findRenderObject(), details.globalPosition);
        },
        onPanUpdate: (DragUpdateDetails details) {
          widget.onPanUpdate?.call(context.findRenderObject(), details.globalPosition);
        });
  }
}
