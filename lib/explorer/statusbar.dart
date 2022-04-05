import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/ui/status.dart';
import 'package:editor/services/highlight/theme.dart';

class Statusbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context);
    HLTheme theme = Provider.of<HLTheme>(context);
    StatusProvider status = Provider.of<StatusProvider>(context);

    TextStyle style = TextStyle(
        fontFamily: theme.uiFontFamily,
        fontSize: theme.uiFontSize,
        color: theme.comment);

    List<Widget> statuses = <Widget>[];
    status.statuses.forEach((idx, value) {
      statuses.add(Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(value, style: style)));
    });

    return Material(
        color: darken(theme.background, statusbarDarken),
        child: Container(
            alignment: Alignment.centerLeft,
            height: app.statusbarHeight,
            child: Row(children: [
              Text('status', style: style),
              Text(status.status, style: style),
              Expanded(child: Container()),
              ...statuses
            ])));
  }
}
