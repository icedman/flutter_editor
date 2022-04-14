import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/highlight/theme.dart';

class UIButton extends StatelessWidget {
  UIButton({String? this.text, Function? this.onTap});

  String? text;
  Function? onTap;

  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    TextStyle style = TextStyle(
        fontFamily: theme.uiFontFamily,
        fontSize: theme.fontSize,
        letterSpacing: -0.5,
        color: theme.foreground);
    return InkWell(
        child: Padding(
            padding: EdgeInsets.all(8), child: Text('$text', style: style)),
        onTap: () {
          onTap?.call();
        });
  }
}

class UIModal extends StatefulWidget {
  UIModal({
    Key? key,
    String? this.title,
    String? this.message,
    Offset this.position = Offset.zero,
    double this.width = 220,
    List<UIButton> this.buttons = const [],
  }) : super(key: key);

  double width = 220;
  String? title;
  String? message;
  Offset position = Offset.zero;
  List<UIButton> buttons = [];

  @override
  _UIModal createState() => _UIModal();
}

class _UIModal extends State<UIModal> {
  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    AppProvider app = Provider.of<AppProvider>(context);
    UIProvider ui = Provider.of<UIProvider>(context);

    Offset position = widget.position;

    _cancel() {
      Future.delayed(const Duration(microseconds: 0), () {
        ui.clearPopups();
      });
      return Container();
    }

    TextStyle style = TextStyle(
        fontFamily: theme.uiFontFamily,
        fontSize: theme.uiFontSize,
        letterSpacing: -0.5,
        color: theme.comment);
    Color bg = darken(theme.background, sidebarDarken);

    double maxWidth = widget.width;
    double padding = 8;

    List<Widget> items = [
      if (widget.title != null) ...[
        Text('${widget.title}', style: style.copyWith(color: theme.function))
      ],
      if (widget.message != null) ...[
        Center(child: Text('${widget.message}', style: style))
      ],
    ].map((item) => Padding(padding: EdgeInsets.all(4), child: item)).toList();

    return Positioned.fill(
        // top: position.dy,
        // left: position.dx,
        child: Padding(
            padding: EdgeInsets.only(bottom: app.screenHeight > 200 ? 80 : 0),
            child: Align(
                alignment: Alignment.center,
                child: Material(
                    color: bg,
                    // borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: Container(
                        width: maxWidth,
                        decoration: BoxDecoration(
                            // color: bg,
                            border: Border.all(
                                color: darken(theme.background, 0),
                                width: 1.5)),
                        child: Padding(
                            padding: EdgeInsets.all(padding),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment
                                    .start, //Center Row contents vertically,,
                                children: [
                                  ...items,
                                  if (widget.buttons.isNotEmpty) ...[
                                    Row(
                                        children: widget.buttons,
                                        mainAxisAlignment: MainAxisAlignment
                                            .center, //Center Row contents horizontally,
                                        crossAxisAlignment: CrossAxisAlignment
                                            .center //Center Row contents vertically,
                                        )
                                  ],
                                ])))))));
  }
}
