import 'dart:io';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:editor/services/util.dart';

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
  late FocusNode focusNode;
  late FocusNode textFocusNode;

  InputListener(
      {required Widget this.child,
      Function? this.onKeyDown,
      Function? this.onKeyUp,
      Function? this.onTapDown,
      Function? this.onDoubleTapDown,
      Function? this.onPanUpdate,
      required FocusNode this.focusNode,
      required FocusNode this.textFocusNode,
      bool this.showKeyboard = false});
  @override
  _InputListener createState() => _InputListener();
}

class _InputListener extends State<InputListener> {
  late TextEditingController controller;

  Offset lastTap = Offset.zero;

  @override
  void initState() {
    super.initState();
    controller = CustomEditingController();

    controller.addListener(() {
      final t = controller.text;
      if (t.isNotEmpty) {
        widget.onKeyDown?.call(t, keyId: 0, softKeyboard: true);
      }
      controller.text = '';
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
        onFocusChange: (focused) {
          if (focused && !widget.textFocusNode.hasFocus) {
            widget.textFocusNode.requestFocus();
          }
        },
        child: Column(children: [
          Expanded(
              child: GestureDetector(
                  child: widget.child,
                  onTapUp: (TapUpDetails details) {
                    lastTap = details.globalPosition;
                  },
                  onTapDown: (TapDownDetails details) {
                    if (!widget.focusNode.hasFocus) {
                      widget.focusNode.requestFocus();
                      widget.textFocusNode.unfocus();
                      // FocusScope.of(context).unfocus();
                    }
                    if (!widget.textFocusNode.hasFocus) {
                      Future.delayed(const Duration(microseconds: 50), () {
                        widget.textFocusNode.requestFocus();
                      });
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
                      focusNode: widget.textFocusNode,
                      autofocus: true,
                      maxLines: null,
                      enableInteractiveSelection: false,
                      decoration:
                          const InputDecoration(border: InputBorder.none),
                      controller: controller))
        ]),
        focusNode: widget.focusNode,
        autofocus: true,
        onKey: (FocusNode node, RawKeyEvent event) {
          if (event.runtimeType.toString() == 'RawKeyDownEvent') {
            String key = event.character ?? '';
            if (event.logicalKey.keyLabel.length > 1) {
              key = event.logicalKey.keyLabel;
            }
            // print(key);
            widget.onKeyDown?.call(key,
                keyId: event.logicalKey.keyId,
                shift: event.isShiftPressed,
                control: event.isControlPressed,
                alt: event.isAltPressed,
                code: event.hashCode);
          }
          if (event.runtimeType.toString() == 'RawKeyUpEvent') {
            widget.onKeyUp?.call();
          }
          return KeyEventResult.ignored;
        });
  }
}
