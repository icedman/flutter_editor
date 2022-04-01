import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:editor/editor/decorations.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/services/ui.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

class AutoCompletePopup extends StatelessWidget {
  AutoCompletePopup({Key? key, this.position = Offset.zero, DocumentProvider? this.doc, 
    dynamic this.search}) : super(key: key);
    
  Offset position = Offset.zero;
  DocumentProvider? doc;
  dynamic search;

  @override
  Widget build(BuildContext context) {
    UIProvider ui = Provider.of<UIProvider>(context);
    HLTheme theme = Provider.of<HLTheme>(context);

    _cancel() {
      Future.delayed(const Duration(microseconds: 0), () {
        ui.clearPopups();
      });
      return Container();
    }

    if (search == null) {
      return _cancel();
    }

    String _search = search['search'] ?? '';
    dynamic _result = search['result']!;

    if (_search == '' || _result == null) {
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
    int itemsCount = _result.length;
    if (itemsCount > maxItems) itemsCount = maxItems;
    double height = (itemHeight + 1.5) * itemsCount;

    Widget _item(BuildContext context, int index) {
      String s = _result[index];
      return GestureDetector(
          onTap: () {
            ui.clearPopups();
            Document d = doc?.doc ?? Document();
            d.begin();
            d.clearCursors();
            d.moveCursorLeft();
            d.selectWord();
            d.insertText(s); // todo.. command!
            d.commit();
            doc?.notifyListeners();
            _cancel();
          },
          child: Padding(
              padding: EdgeInsets.all(padding),
              child: Container(
                  // color: index == decor.menuIndex ? theme.background : null,
                  width: maxWidth,
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(' $s ',
                          // style: index == decor.menuIndex
                          //     ? style.copyWith(color: theme.foreground)
                          //     : style,
                          style: style.copyWith(color: theme.comment),
                          softWrap: false,
                          overflow: TextOverflow.clip)))));
    }

    return Positioned(top: position.dy + itemHeight, left: position.dx, child: Container(
      width: maxWidth + padding, height: height, 
      decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: theme.comment, width: 1.5)),
      child: 
        // Text('hello ${position}', style: TextStyle(color: Colors.white))

              Padding(
                padding: EdgeInsets.all(padding),
                child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _result.length,
                    itemExtent: itemHeight,
                    itemBuilder: _item))

      ));
  }
}
