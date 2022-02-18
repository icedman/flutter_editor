import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'scroller.dart';
import 'input.dart';
import 'document.dart';
import 'highlighter.dart';
import 'theme.dart';

class DocumentProvider extends ChangeNotifier {
  Document doc = Document();

  int scrollTo = -1;

  Future<bool> openFile(String path) async {
    bool res = await doc.openFile(path);
    touch();
    return res;
  }

  void touch() {
    notifyListeners();
  }
}

class ViewLine extends StatelessWidget {
  ViewLine({Block? this.block, bool this.softWrap = true});

  Block? block;
  bool softWrap = false;

  @override
  Widget build(BuildContext context) {
    String text = block?.text ?? '';
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    Highlighter hl = Provider.of<Highlighter>(context);

    int lineNumber = block?.line ?? 0;
    List<InlineSpan> spans = hl.run(text, lineNumber, doc.doc);

    final gutterStyle = TextStyle(
        fontFamily: fontFamily, fontSize: gutterFontSize, color: comment);
    double gutterWidth =
        getTextExtents(' ${doc.doc.blocks.length} ', gutterStyle).width;

    return Stack(children: [
      Padding(
          padding: EdgeInsets.only(left: gutterWidth),
          child: RichText(text: TextSpan(children: spans), softWrap: softWrap)),
      Container(
          width: gutterWidth,
          alignment: Alignment.centerRight,
          child: Text('${lineNumber + 1} ', style: gutterStyle)),
    ]);
  }
}

class View extends StatefulWidget {
  View({Key? key, String this.path = ''}) : super(key: key);

  String path = '';

  @override
  _View createState() => _View();
}

class _View extends State<View> {
  late ScrollController scroller;
  late Scroller scrollTo;

  int visibleStart = -1;
  int visibleEnd = -1;

  @override
  void initState() {
    scroller = ScrollController();
    scrollTo = Scroller();
    super.initState();
  }

  @override
  void dispose() {
    scroller.dispose();
    super.dispose();
  }

  void updateVisibleRange(BuildContext context) {
    RenderObject? obj = context.findRenderObject();
    RenderBox? box = obj as RenderBox;
    Offset offset = box.localToGlobal(Offset(0, 0));
    Rect bounds = obj.paintBounds;
    Rect globalBounds = offset & bounds.size;

    List<RenderParagraph> pars = <RenderParagraph>[];
    findRenderParagraphs(obj, pars);

    int min = -1;
    int max = -1;

    pars.forEach((p) {
      RenderBox? pBox = p as RenderBox;
      Offset pOffset = pBox.localToGlobal(Offset(0, 0));
      Rect globalPBox = pOffset & pBox.size;
      if (globalBounds.contains(pOffset) &&
          globalBounds.contains(pOffset.translate(0, pBox.size.height))) {
        TextSpan t = p.text as TextSpan;
        List<InlineSpan> children = (t as TextSpan).children ?? <InlineSpan>[];

        if (children.length > 0 && children.last is CustomWidgetSpan) {
          int line = (children.last as CustomWidgetSpan).line;
          if (min == -1 || min > line) {
            min = line;
          }
          if (max == -1 || max < line) {
            max = line;
          }
        }

        visibleStart = min;
        visibleEnd = max;
      }
    });
  }

  bool isLineVisible(int line) {
    int start = visibleStart;
    int end = visibleEnd;
    return (line >= visibleStart && line <= visibleEnd);
  }

  @override
  Widget build(BuildContext context) {
    DocumentProvider doc = Provider.of<DocumentProvider>(context);

    if (doc.scrollTo != -1) {
      updateVisibleRange(context);
      if (!isLineVisible(doc.scrollTo)) {
        scrollTo.start(
            scrollController: scroller,
            onUpdate: () {
              updateVisibleRange(context);
              int docSize = doc.doc.blocks.length;
              double position = scroller.position.pixels;
              double max = scroller.position.maxScrollExtent;

              double speed = 10;
              double estimatedExtents = max / docSize;
              double estimateTarget = doc.scrollTo * estimatedExtents;

              double dv = estimateTarget - position;
              double ds = sqrt(dv * dv);
              if (ds > 100) {
                speed = (ds / 4);
              }
              if (ds > 5000) {
                speed = (ds / 2);
              }

              double target = -1;
              if (visibleStart + 2 >= doc.scrollTo) {
                target = position - speed;
              }
              if (visibleEnd - 2 <= doc.scrollTo) {
                target = position + speed;
              }
              if (target != -1) {
                if (target < 0) {
                  target = 0;
                }
                if (target > max) target = max;
                scroller.jumpTo(target);
              }

              // print('${doc.scrollTo} $visibleStart $visibleEnd');
              return !(isLineVisible(doc.scrollTo));
            },
            onDone: () {
              doc.scrollTo = -1;
            });
      }
    }
    double? extent;

    bool softWrap = true;
    if (doc.doc.blocks.length > 10000) {
      softWrap = false;
    }
    if (!softWrap) {
      extent = getTextExtents('X', TextStyle(fontFamily: fontFamily, fontSize: fontSize)).height;
    }

    return ListView.builder(
        controller: scroller,
        itemCount: doc.doc.blocks.length,
        itemExtent: extent,
        itemBuilder: (BuildContext context, int index) {
          Block block = doc.doc.blockAtLine(index) ?? Block('');
          block.line = index;
          return ViewLine(block: block, softWrap: softWrap);
        });
  }
}
