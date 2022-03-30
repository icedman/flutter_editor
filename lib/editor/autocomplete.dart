import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'package:editor/editor/decorations.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

class AutoCompletePopup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    DecorInfo decor = Provider.of<DecorInfo>(context);

    Size windowSize = Size.zero;
    Offset windowPos = Offset.zero;
    RenderObject? obj = context.findRenderObject();
    if (obj != null) {
      obj = obj.parent as RenderObject;
      RenderBox? box = obj as RenderBox;
      windowSize = box.size;
      windowPos = box.localToGlobal(windowPos);
    }

    Widget _hide() {
      decor.showCaretBased = false;
      return Container();
    }

    if (!decor.showCaretBased || decor.result == null) return _hide();
    dynamic json = decor.result;

    String _search = json['search'] ?? '';
    dynamic _result = json['result']!;

    if (_search != decor.searchText) return _hide();
    if (_result == null || _result.length == 0) return _hide();

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
    double height = itemHeight * _result.length;
    double maxHeight = itemHeight * maxItems;
    if (height > maxHeight) height = maxHeight;

    Offset pos = decor.caretPosition;
    double dx = pos.dx;
    double dy = pos.dy + itemHeight;
    if (dx + maxWidth > windowSize.width && windowSize.width > 0) {
      dx = windowSize.width - maxWidth;
    }
    if (dy + height + (windowSize.height / 8) > windowSize.height &&
        windowSize.height > 0) {
      dy = pos.dy - height - padding * 2;
    }
    pos = Offset(dx, dy);

    if (decor.menuIndex >= _result.length) {
      decor.menuIndex = _result.length - 1;
    }

    Widget _item(BuildContext context, int index) {
      String s = _result[index];
      return GestureDetector(
          onTap: () {
            decor.setSearch('');
            Document d = doc.doc;
            d.begin();
            d.clearCursors();
            d.moveCursorLeft();
            d.selectWord();
            d.insertText(s); // todo.. command!
            d.commit();
            doc.notifyListeners();
          },
          child: Padding(
              padding: EdgeInsets.all(padding),
              child: Container(
                  color: index == decor.menuIndex ? theme.background : null,
                  width: maxWidth,
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(' $s ',
                          style: index == decor.menuIndex
                              ? style.copyWith(color: theme.foreground)
                              : style,
                          softWrap: false,
                          overflow: TextOverflow.clip)))));
    }

    return Positioned(
        top: pos.dy,
        left: pos.dx - size.width,
        child: Container(
            decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: theme.comment, width: 1.5)),
            width: maxWidth + padding,
            height: height + padding,
            child: Padding(
                padding: EdgeInsets.all(padding),
                child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _result.length,
                    itemExtent: itemHeight,
                    itemBuilder: _item))));
  }
}
