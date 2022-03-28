import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'dart:ffi' hide Size;
import 'dart:convert';
import 'package:ffi/ffi.dart';

import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'package:editor/editor/decorations.dart';
import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/services/timer.dart';
import 'package:editor/services/input.dart';
import 'package:editor/ffi/bridge.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

class GutterLine extends StatelessWidget {
  GutterLine(
      {Block? this.block,
      TextStyle? this.style,
      String this.text = '',
      double this.width = 0,
      double this.height = 0,
      Color? this.color});

  TextStyle? style;
  Block? block;
  String text = '';
  double width = 0;
  double height = 0;
  Color? color;

  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    return Container(
        color: (block?.carets ?? []).length > 0
            ? theme.selection.withOpacity(0.7)
            : theme.background,
        height: height,
        width: width,
        alignment: Alignment.centerRight,
        child: Text(text, style: style));
  }
}

class ViewLine extends StatelessWidget {
  ViewLine({
    Key? key,
    Block? this.block,
    int this.line = 0,
    double this.gutterWidth = 0,
    TextStyle? this.gutterStyle,
    double this.width = 0,
    double this.height = 0,
  }) : super(key: key);

  Block? block;
  int line = 0;
  double width = 0;
  double height = 0;
  double gutterWidth = 0;
  TextStyle? gutterStyle;

  @override
  Widget build(BuildContext context) {
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    Highlighter hl = Provider.of<Highlighter>(context);

    int lineNumber = block?.line ?? 0;

    Block b = block ?? Block('', document: doc.doc);
    if (b.spans == null) {
      Highlighter hl = Provider.of<Highlighter>(context, listen: false);
      hl.run(b, b.line, b.document ?? Document(), onTap: (text) {
        if (text == ':unfold') {
          doc.doc.unfold(b);
          b.makeDirty();
          doc.touch();
        }
      });
    }

    List<InlineSpan> spans = block?.spans ?? [];
    bool softWrap = doc.softWrap;

    Offset pos = const Offset(0, 0);
    Size extents = Size(0, 0);
    Size size = Size(0, 0);
    RenderObject? obj = context.findRenderObject();
    if (obj != null) {
      RenderBox? box = obj as RenderBox;
      size = box.size;
      pos = box.localToGlobal(pos);
    }

    TextPainter? textPainter;
    TextPainter? painter() {
      if (size.width > 0 && !spans.isEmpty && spans[0] is TextSpan) {
        TextSpan ts = spans[0] as TextSpan;
        extents = getTextExtents('|', ts.style ?? TextStyle());
        return TextPainter(
            text: TextSpan(text: block?.text ?? '', style: ts.style),
            textDirection: TextDirection.ltr)
          ..layout(minWidth: 0, maxWidth: size.width - gutterWidth);
      }
      return null;
    }

    // render carets
    List<Widget> carets = [];
    if (!(block?.carets ?? []).isEmpty) {
      if (textPainter == null) {
        textPainter = painter();
      }

      // position selection thumbs
      Cursor cur = doc.doc.cursor();
      if (textPainter != null && cur.hasSelection()) {
        if (cur.block == block) {
          Offset offsetForCaret = textPainter.getOffsetForCaret(
              TextPosition(offset: cur.column), Offset(0, 0) & Size(0, 0));
          double left = gutterWidth + offsetForCaret.dx;
          double top = offsetForCaret.dy;

          doc.cursorOffset = Offset(pos.dx + left, pos.dy + top);
        }
        if (cur.anchorBlock == block) {
          Offset offsetForCaret = textPainter.getOffsetForCaret(
              TextPosition(offset: cur.anchorColumn),
              Offset(0, 0) & Size(0, 0));
          double left = gutterWidth + offsetForCaret.dx;
          double top = offsetForCaret.dy;

          doc.anchorOffset = Offset(pos.dx + left, pos.dy + top);
        }
      }

      if (textPainter != null) {
        for (final col in block?.carets ?? []) {
          Offset offsetForCaret = textPainter.getOffsetForCaret(
              TextPosition(offset: col.position), Offset(0, 0) & Size(0, 0));

          double left = gutterWidth + offsetForCaret.dx;
          double top = offsetForCaret.dy;
          carets.add(Positioned(
              left: left,
              top: top,
              child: AnimatedCaret(
                  width: 2, height: extents.height, color: col.color)));
        }
      }
    }

    List<Cursor> extras = [...doc.doc.extraCursors, ...doc.doc.sectionCursors];
    if (!extras.isEmpty) {
      for (final e in extras) {
        if (e.block != block) continue;
        if (textPainter == null) {
          textPainter = painter();
        }
        if (textPainter != null) {
          Offset offsetForCaret = textPainter.getOffsetForCaret(
              TextPosition(offset: e.column), Offset(0, 0) & Size(0, 0));
          carets.add(Positioned(
              left: gutterWidth + offsetForCaret.dx,
              top: offsetForCaret.dy,
              child: BracketMatch(
                  width: extents.width,
                  height: extents.height,
                  color: e.color)));
        }
      }
    }

    return Stack(children: [
      Padding(
          padding: EdgeInsets.only(left: gutterWidth),
          child: RichText(text: TextSpan(children: spans), softWrap: softWrap)),
      GutterLine(
          block: block,
          height: height,
          width: gutterWidth,
          text: '${lineNumber + 1} ',
          style: gutterStyle),
      ...carets,
    ]);
  }
}

class View extends StatefulWidget {
  View({Key? key}) : super(key: key);

  @override
  _View createState() => _View();
}

class _View extends State<View> {
  late ScrollController scroller;
  late ScrollController hscroller;
  late PeriodicTimer scrollTo;

  int visibleStart = -1;
  int visibleEnd = -1;
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
          });
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
    Offset offset = box.localToGlobal(const Offset(0, 0));
    Rect bounds = obj.paintBounds;
    Rect globalBounds = offset & bounds.size;

    List<RenderParagraph> pars = <RenderParagraph>[];
    findRenderParagraphs(obj, pars);

    int min = -1;
    int max = -1;

    for (final p in pars) {
      RenderBox? pBox = p as RenderBox;
      Offset pOffset = pBox.localToGlobal(const Offset(0, 0));
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
            if (ds > 250) {
              speed = (ds / 6);
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

            return !(isLineVisible(line));
          },
          onDone: () {});
    }
  }

  @override
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    DocumentProvider doc = Provider.of<DocumentProvider>(context);

    final TextStyle style = TextStyle(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
        color: Colors.white);
    final TextStyle gutterStyle = TextStyle(
        fontFamily: theme.fontFamily,
        fontSize: theme.gutterFontSize,
        color: theme.comment);

    double gutterWidth = 0;
    if (doc.showGutters) {
      gutterWidth =
          getTextExtents(' ${doc.doc.blocks.length} ', gutterStyle).width;
    }

    if (fontHeight == 0) {
      fontHeight = getTextExtents('X',
              TextStyle(fontFamily: theme.fontFamily, fontSize: theme.fontSize))
          .height;
    }

    bool softWrap = doc.softWrap;

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
    Size size = Size(0, 0);
    if (obj != null) {
      RenderBox? box = obj as RenderBox;
      size = box.size;
    }

    int count = 100;
    if (size != null) {
      count = ((size.height / fontHeight) * 2.0).toInt();
    }

    int docSize = doc.doc.computedSize();

    if ((!largeDoc && softWrap)) {
      return ListView.builder(
          controller: scroller,
          itemCount: docSize,
          itemExtent: softWrap ? null : fontHeight,
          itemBuilder: (BuildContext context, int line) {
            line = doc.doc.computedLine(line);
            Block block = doc.doc.blockAtLine(line) ?? Block('');
            return ViewLine(
                line: line,
                block: block,
                width: size.width - gutterWidth,
                height: fontHeight,
                gutterWidth: gutterWidth,
                gutterStyle: gutterStyle);
          });
    }

    // use a custom ListView - default ListView.builder doesn't work well where:
    // 1. document is large - thumbscrolling is too slow
    // 2. not softWrap - vertical + horizontal scroller is not available
    // drawback - slow scrolling has a jerkiness effect when softWrap is on

    double totalHeight = docSize * fontHeight;

    double top = fontHeight * visibleLine;
    top -= (fontHeight * count / 2);
    if (top < 0) top = 0;

    // print('count: $count top: $top visible: $visibleLine');

    List<Widget> gutters = [];
    List<Widget> children = [];
    double offset = top;
    for (int i = 0; i < count; i++) {
      int line = visibleLine + i;
      if (line >= docSize) {
        break;
      }
      line = doc.doc.computedLine(line);
      Block block = doc.doc.blockAtLine(line) ?? Block('');
      children.add(ViewLine(
          line: line,
          block: block,
          width: size.width - gutterWidth,
          height: fontHeight,
          gutterWidth: gutterWidth,
          gutterStyle: gutterStyle));

      if (!softWrap && gutterWidth > 0) {
        gutters.add(GutterLine(
            block: block,
            width: gutterWidth,
            height: fontHeight,
            text: '${block.line + 1} ',
            style: gutterStyle));
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
