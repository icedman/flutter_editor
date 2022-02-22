import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'timer.dart';
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
  ViewLine(
      {Key? key,
      Block? this.block,
      bool this.softWrap = false,
      double this.gutterWidth = 0,
      TextStyle? this.gutterStyle,
      double this.width = 0,
      double this.height = 0})
      : super(key: key);

  Block? block;
  bool softWrap = false;
  double width = 0;
  double height = 0;
  double gutterWidth = 0;
  TextStyle? gutterStyle;

  @override
  Widget build(BuildContext context) {
    String text = block?.text ?? '';

    // print('build ${block?.line}');

    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    Highlighter hl = Provider.of<Highlighter>(context);

    int lineNumber = block?.line ?? 0;
    List<InlineSpan> spans = hl.run(block, lineNumber, doc.doc);

    // if (spans.length > 0 && spans[0] is TextSpan) {
    //   TextSpan ts = spans[0] as TextSpan;

    //   Size singleLine = getTextExtents('X', ts.style ?? TextStyle());
    //   Size sz = getTextExtents(block?.text ?? '', ts.style ?? TextStyle(),
    //       maxWidth: width > 0 ? width : double.infinity, maxLines: 100);
    //   block?.lineCount = (sz.height / singleLine.height).toInt();
    //   // block?.lineCount = 1;
    //   // print('${block?.line} $width $sz');
    // }

    return Stack(children: [
      Padding(
          padding: EdgeInsets.only(left: gutterWidth),
          child: RichText(text: TextSpan(children: spans), softWrap: softWrap)),
      Container(
          height: height,
          width: gutterWidth,
          alignment: Alignment.centerRight,
          child:
              softWrap ? Text('${lineNumber + 1} ', style: gutterStyle) : null),
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
  late ScrollController hscroller;
  late PeriodicTimer scrollTo;

  int visibleStart = -1;
  int visibleEnd = -1;
  bool softWrap = false;
  bool largeDoc = false;

  int visibleLine = 0;
  double fontHeight = 0;

  @override
  void initState() {
    scroller = ScrollController();
    hscroller = ScrollController();
    scrollTo = PeriodicTimer();

    scroller.addListener(() {
      DocumentProvider doc =
          Provider.of<DocumentProvider>(context, listen: false);

      int docSize = doc.doc.blocks.length;
      double totalHeight = docSize * fontHeight;

      if (!scroller.positions.isEmpty) {
        double p = scroller.position.pixels / scroller.position.maxScrollExtent;
        int line = (p * docSize).toInt();
        updateVisibleRange(context);
        if (visibleLine != line) {
          setState(() {
            visibleLine = line;
            // print('!$visibleLine');
          });
        } else {
          // print('---$line');
        }
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    scroller.dispose();
    hscroller.dispose();
    scrollTo.cancel();
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

    for (final p in pars) {
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
    }
  }

  bool isLineVisible(int line) {
    bool res = (line >= visibleStart && line <= visibleEnd);
    // print('$line $visibleStart $visibleEnd $res');
    return res;
  }

  void scrollToLine(int line) {
    DocumentProvider doc =
        Provider.of<DocumentProvider>(context, listen: false);
    updateVisibleRange(context);
    double speedScale = 1.0;
    if (!isLineVisible(line)) {
      scrollTo.start(
          scale: speedScale,
          onUpdate: () {
            updateVisibleRange(context);
            int docSize = doc.doc.blocks.length;
            double position = scroller.position.pixels;
            double max = scroller.position.maxScrollExtent;

            double speed = 10;
            double estimatedExtents = max / docSize;
            double estimateTarget = line * estimatedExtents;

            double dv = estimateTarget - position;
            double ds = sqrt(dv * dv);
            if (ds > 500) {
              speed = (ds / 10);
            }
            if (ds > 1000) {
              speed = (ds / 4);
            }
            if (ds > 5000) {
              speed = (ds / 2);
            }
            if (speed > 1000 && !largeDoc) {
              speed = 1000;
            }
            speed *= speedScale;

            double target = -1;
            if (visibleStart + 2 >= line) {
              target = position - speed;
            }
            if (visibleEnd - 2 <= line) {
              target = position + speed;
            }
            if (target != -1) {
              if (target < 0) {
                target = 0;
              }
              if (target > max) target = max;
              scroller.jumpTo(target);
              double dst = target - position;
              if (dst * dst < 25) {
                return false;
              }
            }

            // print('${line} $visibleStart $visibleEnd');
            return !(isLineVisible(line));
          },
          onDone: () {
            print('done');
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    DocumentProvider doc = Provider.of<DocumentProvider>(context);

    final TextStyle style = TextStyle(
        fontFamily: fontFamily, fontSize: fontSize, color: Colors.white);
    final TextStyle gutterStyle = TextStyle(
        fontFamily: fontFamily, fontSize: gutterFontSize, color: comment);

    double gutterWidth =
        getTextExtents(' ${doc.doc.blocks.length} ', gutterStyle).width;

    if (fontHeight == 0) {
      fontHeight = getTextExtents(
              'X', TextStyle(fontFamily: fontFamily, fontSize: fontSize))
          .height;
    }

    double? extent;
    largeDoc = (doc.doc.blocks.length > 10000);
    if (!softWrap) {
      extent = fontHeight;
    }

    if (doc.scrollTo != -1) {
      scrollToLine(doc.scrollTo);
      doc.scrollTo = -1;
    }

    RenderObject? obj = context.findRenderObject();
    Size? size;
    if (obj != null) {
      RenderBox? box = obj as RenderBox;
      size = box.size;
    }

    int count = 100;
    if (size != null && size.height > fontHeight * 4) {
      count = ((size.height / fontHeight) * 2.0).toInt();
    }

    int docSize = doc.doc.blocks.length;
    double totalHeight = docSize * fontHeight;

    int pageLines = 32;
    double top = fontHeight * visibleLine;
    top -= (fontHeight * pageLines);
    if (top < 0) top = 0;

    List<Widget> gutters = [];
    List<Widget> children = [];
    double offset = top;
    for (int i = 0; i < count; i++) {
      int line = visibleLine + i;
      if (line > docSize) {
        break;
      }
      Block block = doc.doc.blockAtLine(line) ?? Block('');
      block.line = line;

      children.add(ViewLine(
          block: block,
          softWrap: softWrap,
          width: (size?.width ?? 0) - gutterWidth,
          height: fontHeight,
          gutterWidth: gutterWidth,
          gutterStyle: gutterStyle));

      if (!softWrap) {
        gutters.add(Container(
            color: background,
            height: fontHeight,
            width: gutterWidth,
            alignment: Alignment.centerRight,
            child: Text('${block.line + 1} ', style: gutterStyle)));
      }
    }

    Widget viewLines = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Container(height: top), ...children]);

    Widget gutterLines = softWrap
        ? Container()
        : Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Container(height: top), ...gutters]);

    Widget viewLinesContainer = softWrap
        ? viewLines
        : SingleChildScrollView(
            controller: hscroller,
            scrollDirection: Axis.horizontal,
            child: viewLines);

    return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        controller: scroller,
        child: Stack(children: [
          Container(height: totalHeight),
          viewLinesContainer,
          if (gutterWidth > 0) ...[gutterLines]
        ]));
  }
}
