import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/ui/menu.dart';
import 'package:editor/services/highlight/theme.dart';

class UIPalettePopup extends StatefulWidget {
  UIPalettePopup(
      {Key? key,
      double this.width = 300,
      int this.visibleItems = 6,
      UIMenuData? this.menu})
      : super(key: key);

  double width = 220;
  int visibleItems = 6;
  UIMenuData? menu;

  @override
  _UIPalettePopup createState() => _UIPalettePopup();
}

class _UIPalettePopup extends State<UIPalettePopup> {
  late ScrollController scroller;
  late FocusNode focusNode;
  late TextEditingController inputEditController;

  UIMenuData? filteredMenu;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    scroller = ScrollController();
    inputEditController = TextEditingController();

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    scroller.dispose();
    focusNode.dispose();
    inputEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    AppProvider app = Provider.of<AppProvider>(context);
    UIProvider ui = Provider.of<UIProvider>(context);

    UIMenuData? menu = widget.menu;
    filteredMenu = menu;

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
        fontFamily: theme.uiFontFamily,
        fontSize: theme.uiFontSize,
        letterSpacing: -0.5,
        color: theme.comment);
    Color bg = darken(theme.background, sidebarDarken);

    double maxWidth = widget.width;
    int maxItems = widget.visibleItems;

    double padding = 2;
    Size extents = getTextExtents(' ', style);
    double itemHeight = (((extents.height + 4) * 2) + (padding * 2));
    int itemsCount = items.length;
    if (itemsCount > maxItems) itemsCount = maxItems;
    double height = 8 + (itemHeight + 1.5) * itemsCount;

    double textFieldHeight = 32;
    height += textFieldHeight;

    if (scroller.positions.isNotEmpty) {
      double start = scroller.position.pixels / itemHeight;
      double end = start + maxItems;
      int index = menu?.menuIndex ?? 0;
      if (index < start || index >= end) {
        double target = index * itemHeight - (height / 2.5);
        if (target < 0) {
          target = 0;
        }
        if (target > scroller.position.maxScrollExtent) {
          target = scroller.position.maxScrollExtent;
        }
        scroller.jumpTo(target);
      }
    }

    Widget _item(BuildContext context, int index) {
      UIMenuData? item = items[index];
      String title = item?.title ?? '';
      String subtitle = item?.subtitle ?? '';
      return InkWell(
          onTap: () {
            menu?.select(index);
            ui.clearPopups();
          },
          child: Padding(
              padding: EdgeInsets.all(padding),
              child: Container(
                  color: index == menu?.menuIndex ? theme.background : null,
                  width: maxWidth,
                  child: ListTile(
                      title: Text(title,
                          style: style.copyWith(color: theme.function)),
                      subtitle: ScrollableText(subtitle,
                          style: style.copyWith(color: theme.comment))))));
    }

    return Align(
        alignment: Alignment.topCenter,
        child: Padding(
            padding: EdgeInsets.only(top: app.tabbarHeight),
            child: Material(
                color: bg,
                child: Container(
                    width: maxWidth + padding,
                    height: height,
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: darken(theme.background, 0), width: 1.5)),
                    child: Padding(
                        padding: EdgeInsets.all(padding),
                        child: Column(children: [
                          Container(
                              height: textFieldHeight,
                              // color: theme.comment,
                              child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: TextField(
                                      onSubmitted: (value) {
                                        focusNode.requestFocus();
                                      },
                                      textInputAction: TextInputAction.done,
                                      style: TextStyle(
                                          //fontFamily: app.fontFamily,
                                          fontSize: theme.uiFontSize,
                                          color: theme.foreground),
                                      controller: inputEditController,
                                      decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: 'Find...',
                                          hintStyle: TextStyle(
                                              //fontFamily: theme.fontFamily,
                                              fontSize: theme.uiFontSize,
                                              fontStyle: FontStyle.italic,
                                              color: theme.comment)),
                                      focusNode: focusNode,
                                      autofocus: true))),
                          Expanded(
                              child: ListView.builder(
                                  controller: scroller,
                                  padding: EdgeInsets.zero,
                                  itemCount: items.length,
                                  itemExtent: itemHeight,
                                  itemBuilder: _item))
                        ]))))));
  }
}
