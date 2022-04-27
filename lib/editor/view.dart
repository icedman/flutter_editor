import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import 'package:editor/editor/decorations.dart';
import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/timer.dart';
import 'package:editor/services/input.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

Offset screenToCursor(RenderObject? obj, Offset pos) {
  List<RenderParagraph> pars = <RenderParagraph>[];
  findRenderParagraphs(obj, pars);

  pos = Offset(pos.dx + 4, pos.dy);
  RenderParagraph? lastPar;
  RenderParagraph? targetPar;
  int line = -1;

  for (final par in pars) {
    if (((par.text as TextSpan).children?.length ?? 0) > 0) lastPar = par;
    TextSpan t = par.text as TextSpan;
    Rect bounds = Offset.zero & par.size;
    Offset offsetForCaret = par.localToGlobal(
        par.getOffsetForCaret(const TextPosition(offset: 0), bounds));
    Rect parBounds =
        offsetForCaret & Size(par.size.width * 100, par.size.height);
    if (parBounds.inflate(2).contains(pos)) {
      targetPar = par;
      break;
    }
  }

  if (targetPar == null && lastPar != null) {
    List<InlineSpan> children =
        (lastPar.text as TextSpan).children ?? <InlineSpan>[];
    if (children.isNotEmpty && children.last is CustomWidgetSpan) {
      line = (children.last as CustomWidgetSpan).line;
    }
    int textOffset = -1;
    return Offset(textOffset.toDouble(), line.toDouble());
  }
  if (targetPar == null) return Offset(-1, -1);

  Rect bounds = Offset.zero & targetPar.size;
  List<InlineSpan> children =
      (targetPar.text as TextSpan).children ?? <InlineSpan>[];
  Size fontCharSize = Size(0, 0);
  int textOffset = 0;
  bool found = false;

  int nearestOffset = 0;
  double nearest = -1;

  for (var span in children) {
    if (found) break;
    if (!(span is TextSpan)) {
      continue;
    }

    if (fontCharSize.width == 0) {
      fontCharSize = getTextExtents(' ', span.style ?? TextStyle());
    }

    String txt = (span as TextSpan).text ?? '';
    for (int i = 0; i < txt.length + 1; i++) {
      Offset offsetForCaret = targetPar.localToGlobal(targetPar
          .getOffsetForCaret(TextPosition(offset: textOffset), bounds));

      Rect charBounds = offsetForCaret & fontCharSize;
      if (charBounds.inflate(2).contains(Offset(pos.dx + 2, pos.dy + 1))) {
        found = true;
        break;
      }

      double dx = offsetForCaret.dx - pos.dx;
      double dy = offsetForCaret.dy - (pos.dy - 4);
      double dst = sqrt((dx * dx) + (dy * dy));

      if (sqrt(dy * dy) > fontCharSize.height) {
        dst += 1000;
      }

      if (nearest > dst || nearest == -1) {
        nearest = dst;
        nearestOffset = textOffset;
      }
      textOffset++;
    }
  }

  if (children.isNotEmpty && children.last is CustomWidgetSpan) {
    line = (children.last as CustomWidgetSpan).line;
    Block? block = (children.last as CustomWidgetSpan).block;
    line = block?.line ?? line;
  }

  if (!found) {
    textOffset = nearestOffset;
  }

  return Offset(textOffset.toDouble(), line.toDouble());
}

void findRenderParagraphs(RenderObject? obj, List<RenderParagraph> res) {
  if (obj is RenderParagraph) {
    res.add(obj);
    return;
  }
  obj?.visitChildren((child) {
    findRenderParagraphs(child, res);
  });
}

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
        color: (block?.carets ?? []).isNotEmpty
            ? colorCombine(theme.selection, theme.background, aw: 2, bw: 3)
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
    Key? this.caretKey,
    Block? this.block,
    int this.line = 0,
    double this.gutterWidth = 0,
    TextStyle? this.gutterStyle,
    double this.width = 0,
    double this.height = 0,
  }) : super(key: key);

  Key? caretKey;
  Block? block;
  int line = 0;
  double width = 0;
  double height = 0;
  double gutterWidth = 0;
  TextStyle? gutterStyle;

  @override
  Widget build(BuildContext context) {
    int lineNumber = block?.line ?? 0;
    // print('rebuild $lineNumber');
    block?.renderedId = (block ?? Block('')).notifier.value;
    return ValueListenableBuilder(
      valueListenable: (block ?? Block('')).notifier,
      builder: (context, value, child) {
        return _ViewLine(
            line: line,
            block: block,
            width: width,
            height: height,
            gutterWidth: gutterWidth,
            gutterStyle: gutterStyle);
      },
    );
  }
}

class _ViewLine extends StatelessWidget {
  _ViewLine({
    Key? key,
    Key? this.caretKey,
    Block? this.block,
    int this.line = 0,
    double this.gutterWidth = 0,
    TextStyle? this.gutterStyle,
    double this.width = 0,
    double this.height = 0,
  }) : super(key: key);

  Key? caretKey;
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
    DecorInfo decor = Provider.of<DecorInfo>(context, listen: false);

    int lineNumber = block?.line ?? 0;
    // print('rebuild renderer $lineNumber');

    Block b = block ?? Block('', document: doc.doc);
    if (b.spans == null) {
      Highlighter hl = Provider.of<Highlighter>(context, listen: false);
      // todo > create link decoration
      hl.run(b, b.line, b.document ?? Document(), onTap: (command) {
        switch (command) {
          case ':unfold':
            doc.doc.unfold(b);
            b.makeDirty();
            doc.touch();
            break;
          case ':open_search_result':
            {
              Cursor cur = doc.doc.cursor();
              cur.block = b;
              cur.moveCursorToStartOfLine();
              String t = (cur.block?.text ?? '');
              int idx = t.indexOf('[Ln');
              String lns = t.substring(idx + 4);
              lns = lns.substring(0, lns.length - 1);
              int ln = int.parse(lns);
              while ((cur.block?.text ?? '').indexOf('[Ln') != -1) {
                cur.moveCursorUp();
              }
              AppProvider.instance()
                  .open(cur.block?.text ?? '', focus: true, scrollTo: ln);
              break;
            }
          default:
            break;
        }
      });
    }

    List<InlineSpan> spans = block?.spans ?? [];
    bool softWrap = doc.softWrap;

    Offset pos = Offset.zero;
    Size extents = Size.zero;
    Size size = Size.zero;
    RenderObject? obj = context.findRenderObject();
    RenderBox? box;
    if (obj != null) {
      box = obj as RenderBox;
      size = box.size;
      pos = box.localToGlobal(pos);
    }

    TextPainter? textPainter;
    TextPainter? painter() {
      if (size.width > 0 && spans.isNotEmpty && spans[0] is TextSpan) {
        TextSpan ts = spans[0] as TextSpan;
        extents = getTextExtents('|', ts.style ?? TextStyle());
        return TextPainter(
            text: TextSpan(text: block?.text ?? '', style: ts.style),
            textDirection: TextDirection.ltr)
          ..layout(minWidth: 0, maxWidth: size.width - gutterWidth);
      }
      return null;
    }

    Size scrollAreaSize = Size.zero;

    if (obj != null) {
      // traverse the render tree (todo! must be changed with widget tree configuration)
      obj = obj.parent?.parent as RenderObject;
      RenderBox? scrollAreaBox = obj as RenderBox;
      scrollAreaSize = scrollAreaBox.size;
    }

    // render carets
    List<Widget> carets = [];
    // move to separate widget
    if ((block?.carets ?? []).isNotEmpty) {
      if (textPainter == null) {
        textPainter = painter();
      }

      if (textPainter != null) {
        for (final col in block?.carets ?? []) {
          Offset offsetForCaret = textPainter.getOffsetForCaret(
              TextPosition(offset: col.position), Offset(0, 0) & Size.zero);

          double left = gutterWidth + offsetForCaret.dx;
          double top = offsetForCaret.dy;

          double w = extents.width;
          double h = extents.height;
          if (doc.overwriteMode) {
            h = 1.75;
            top += extents.height - 2;
          } else {
            w = 2;
          }
          carets.add(Positioned(
              left: left,
              top: top,
              child: AnimatedCaret(width: w, height: h, color: col.color)));

          Offset cursorOffset =
              box?.localToGlobal(Offset(left, top)) ?? Offset.zero;
          decor.setCaret(cursorOffset, doc.doc.cursor());

          // doc.offsetForCaret = offsetForCaret.dy;
          doc.offsetForCaret = Offset(left, top);
          doc.scrollAreaSize = scrollAreaSize;
        }
      }
    }

    List<Cursor> extras = [...doc.doc.extraCursors, ...doc.doc.sectionCursors];
    // move to separate widget
    if (extras.isNotEmpty) {
      for (final e in extras) {
        if (e.block != block) continue;
        if (textPainter == null) {
          textPainter = painter();
        }
        if (textPainter != null) {
          Offset offsetForCaret = textPainter.getOffsetForCaret(
              TextPosition(offset: e.column), Offset(0, 0) & Size.zero);
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
    // return RichText(text: TextSpan(children: spans), softWrap: softWrap);
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
  double fontWidth = 0;
  double fontHeight = 0;
  double gutterWidth = 0;
  int scrollingTo = -1;

  @override
  void initState() {
    scroller = ScrollController();
    hscroller = ScrollController();
    scrollTo = PeriodicTimer();

    // hack - to recalculate layout on tab change
    // Future.delayed(const Duration(milliseconds: 0), () {
    // DocumentProvider doc =
    // Provider.of<DocumentProvider>(context, listen: false);
    // doc.touch();
    // });

    scroller.addListener(() {
      DocumentProvider doc =
          Provider.of<DocumentProvider>(context, listen: false);

      int docSize = doc.doc.blocks.length;
      double totalHeight = docSize * fontHeight;

      if (scroller.positions.isNotEmpty) {
        updateVisibleRange(context);
        double p = scroller.position.pixels / scroller.position.maxScrollExtent;
        visibleLine = (p * docSize).toInt();

        Offset scroll = Offset(0, scroller.position.pixels);
        DecorInfo decor = Provider.of<DecorInfo>(context, listen: false);
        decor.setVisibleRange(visibleStart, visibleEnd);
        decor.onScroll(scroll);

        UIProvider ui = Provider.of<UIProvider>(context, listen: false);
        ui.clearMenus();
      }
    });

    hscroller.addListener(() {
      if (hscroller.positions.isNotEmpty) {
        Offset scroll = Offset(0, hscroller.position.pixels);
        DecorInfo decor = Provider.of<DecorInfo>(context, listen: false);
        decor.onScroll(scroll);

        UIProvider ui = Provider.of<UIProvider>(context, listen: false);
        ui.clearPopups();
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
    Offset offset = box.localToGlobal(Offset.zero);
    Rect bounds = obj.paintBounds;
    Rect globalBounds = offset & bounds.size;

    List<RenderParagraph> pars = <RenderParagraph>[];
    findRenderParagraphs(obj, pars);

    int min = -1;
    int max = -1;

    for (final p in pars) {
      RenderBox? pBox = p as RenderBox;
      Offset pOffset = pBox.localToGlobal(Offset.zero);
      pOffset = Offset(globalBounds.left, pOffset.dy);
      Rect globalPBox = pOffset & pBox.size;
      if (globalBounds.contains(pOffset) &&
          globalBounds.contains(pOffset.translate(0, pBox.size.height))) {
        TextSpan t = p.text as TextSpan;
        List<InlineSpan> children = (t as TextSpan).children ?? <InlineSpan>[];

        if (children.isNotEmpty && children.last is CustomWidgetSpan) {
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

    DocumentProvider doc =
        Provider.of<DocumentProvider>(context, listen: false);
    doc.visibleStart = visibleStart;
    doc.visibleEnd = visibleEnd;
    // print('$visibleStart $visibleEnd');
  }

  bool isLineVisible(int line) {
    bool res = (line >= visibleStart && line <= visibleEnd);
    if (visibleStart == -1 || visibleEnd == -1) {
      print('visible range error: $visibleStart $visibleEnd');
      return true;
    }
    return res;
  }

  void scrollToCursor() {
    DocumentProvider doc =
        Provider.of<DocumentProvider>(context, listen: false);
    if (doc.softWrap) return;

    if (hscroller.positions.isNotEmpty && doc.scrollAreaSize.width > 0) {
      int col = doc.doc.cursor().column;
      double offsetForCaret = doc.offsetForCaret.dx - hscroller.position.pixels;
      // double offsetForCaret = (col * fontWidth).toDouble() - hscroller.position.pixels;

      double sw = doc.scrollAreaSize.width - gutterWidth;

      final _jump = (target) {
        // if (doc.doc.hasSelection()) {
        hscroller.jumpTo(target);
        // } else {
        //   hscroller.animateTo(target,
        //       duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
        // }
      };

      double back = offsetForCaret - (fontWidth * 8);
      if (back < 0) {
        double target = hscroller.position.pixels + back;
        if (target < 0) {
          target = 0;
        }
        _jump(target);
      } else {
        double fwd = offsetForCaret - sw + (fontWidth * 8);
        if (fwd > 0) {
          double target = hscroller.position.pixels + fwd;
          if (target > hscroller.position.maxScrollExtent) {
            target = hscroller.position.maxScrollExtent;
          }
          _jump(target);
        }
      }
    }
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

    if (!doc.ready) return Container();

    final TextStyle style = TextStyle(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
        color: Colors.white);
    final TextStyle gutterStyle = TextStyle(
        fontFamily: theme.fontFamily,
        fontSize: theme.gutterFontSize,
        color: theme.comment);

    gutterWidth = 0;
    if (doc.showGutter) {
      gutterWidth =
          getTextExtents(' ${doc.doc.blocks.length} ', gutterStyle).width;
    }

    if (fontHeight == 0) {
      Size sz = getTextExtents('X',
          TextStyle(fontFamily: theme.fontFamily, fontSize: theme.fontSize));
      fontWidth = sz.width * 0.9;
      fontHeight = sz.height;

      DecorInfo decor = Provider.of<DecorInfo>(context, listen: false);
      decor.fontHeight = fontHeight;
    }

    bool softWrap = doc.softWrap;

    double? extent;
    largeDoc = (doc.doc.blocks.length > 10000);
    if (!softWrap) {
      extent = fontHeight;
    } else {
      if (hscroller.positions.isNotEmpty) {
        hscroller.jumpTo(0);
      }
    }

    if (doc.scrollTo != -1 && doc.scrollTo != scrollingTo) {
      scrollingTo = doc.scrollTo;
      Future.delayed(const Duration(milliseconds: 0), () {
        scrollToLine(scrollingTo);
      });
      Future.delayed(const Duration(milliseconds: 0), scrollToCursor);
    }

    RenderObject? obj = context.findRenderObject();
    Size size = Size.zero;
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
    for (int i = -8; i < count + 8; i++) {
      int line = visibleLine + i;
      if (line < 0) continue;
      if (line >= docSize) {
        break;
      }
      line = doc.doc.computedLine(line);
      Block block = doc.doc.blockAtLine(line) ?? Block('');
      children.add(ViewLine(
          key: ValueKey(block.blockId),
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
