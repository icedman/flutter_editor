import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:editor/services/app.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

class UIMenuPopup extends StatelessWidget {
  UIMenuPopup({Key? key, this.position = Offset.zero, UIMenuData? this.menu})
      : super(key: key);

  UIMenuData? menu;

  Offset position = Offset.zero;

  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    AppProvider app = Provider.of<AppProvider>(context);
    UIProvider ui = Provider.of<UIProvider>(context);

    _cancel() {
      Future.delayed(const Duration(microseconds: 0), () {
        ui.clearPopups();
      });
      return Container();
    }

    List<UIMenuData?> items = menu?.items ?? [];
    if (items.isEmpty) {
      return _cancel();
    }

    TextStyle style = TextStyle(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
        color: theme.comment);
    Color bg = darken(theme.background, 0.04);

    const double maxWidth = 220;
    const int maxItems = 8;

    double padding = 2;
    Size size = getTextExtents('  ', style);
    double itemHeight = (size.height + 2 + (padding * 2));
    int itemsCount = items.length;
    if (itemsCount > maxItems) itemsCount = maxItems;
    double height = (itemHeight + 1.5) * itemsCount;

    double dx = position.dx;
    double dy = position.dy + itemHeight;
    if (dx + maxWidth > app.screenWidth + 8) {
      dx = app.screenWidth - 8 - maxWidth;
    }
    if (dy + height > app.screenHeight + 40) {
      dy = position.dy - height - 4;
    }

    Offset _position = Offset(dx, dy);

    Widget _item(BuildContext context, int index) {
      UIMenuData? item = items[index];
      String s = item?.title ?? '';
      return GestureDetector(
          onTap: () {
            menu?.select(index);
            ui.clearPopups();
          },
          child: Padding(
              padding: EdgeInsets.all(padding),
              child: Container(
                  color: index == menu?.menuIndex ? theme.background : null,
                  width: maxWidth,
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(' $s  ',
                          // style: index == decor.menuIndex
                          //     ? style.copyWith(color: theme.foreground)
                          //     : style,
                          style: style.copyWith(color: theme.comment),
                          softWrap: false,
                          overflow: TextOverflow.clip)))));
    }

    return Positioned(
        top: _position.dy,
        left: _position.dx,
        child: Container(
            width: maxWidth + padding,
            height: height,
            decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: theme.comment, width: 1.5)),
            child: Padding(
                padding: EdgeInsets.all(padding),
                child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemExtent: itemHeight,
                    itemBuilder: _item))));
  }
}
