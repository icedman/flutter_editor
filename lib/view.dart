import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'dart:ffi' hide Size;
import 'dart:convert';
import 'package:ffi/ffi.dart';

import 'dart:isolate';
import 'dart:io';
import 'dart:convert';
import 'dart:math';

import 'caret.dart';
import 'timer.dart';
import 'input.dart';
import 'document.dart';
import 'highlighter.dart';
import 'theme.dart';
import 'native.dart';

class ViewLine extends StatelessWidget {
  ViewLine({
    Key? key,
    Block? this.block,
    double this.gutterWidth = 0,
    TextStyle? this.gutterStyle,
    double this.width = 0,
    double this.height = 0,
  }) : super(key: key);

  Block? block;
  double width = 0;
  double height = 0;
  double gutterWidth = 0;
  TextStyle? gutterStyle;

  Future<List<InlineSpan>> _getSpans(Block block, Highlighter hl) async {
    return Future.delayed(Duration(milliseconds: 0), () {
      return hl.run(block, block.line, block.document ?? Document());
    });
    return hl.run(block, block.line, block.document ?? Document());
  }

  @override
  Widget build(BuildContext context) {
    // Highlighter hl = Provider.of<Highlighter>(context);
    // return FutureBuilder<List<InlineSpan>>(
    //   future: _getSpans(block ?? Block(''), hl),
    //   builder: _build
    //   );
    return _build(context, null);
  }

  Widget _build(BuildContext context, snapshot) {
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    Highlighter hl = Provider.of<Highlighter>(context);

    String text = block?.text ?? '';
    int lineNumber = block?.line ?? 0;

    // print('build ${block?.line}');
    List<InlineSpan> spans =
        block?.spans ?? []; // snapshot.hasData ? snapshot.data : [];
    // if (text.length > 0 && spans.length == 0) {
    //   spans.add(WidgetSpan(child: Text(block?.text ?? '',
    //     style: TextStyle(fontSize: fontSize, fontFamily: fontFamily, color: Colors.white))));
    // }

    bool softWrap = doc.softWrap;

    // render carets
    List<Widget> carets = [];
    if ((block?.carets ?? []).length > 0) {
      RenderObject? obj = context.findRenderObject();
      Size size = Size(0, 0);
      if (obj != null) {
        RenderBox? box = obj as RenderBox;
        size = box.size;
      }
      if (size.width > 0 && spans.length > 0 && spans[0] is TextSpan) {
        TextSpan ts = spans[0] as TextSpan;
        Size sz = getTextExtents('|', ts.style ?? TextStyle());
        final TextPainter textPainter = TextPainter(
            text: TextSpan(text: block?.text ?? '', style: ts.style),
            textDirection: TextDirection.ltr)
          ..layout(minWidth: 0, maxWidth: size.width - gutterWidth);
        for (final col in block?.carets ?? []) {
          Offset offsetForCaret = textPainter.getOffsetForCaret(
              TextPosition(offset: col.position), Offset(0, 0) & Size(0, 0));
          carets.add(Positioned(
              left: gutterWidth + offsetForCaret.dx,
              top: offsetForCaret.dy,
              child: AnimatedCaret(
                  width: 2, height: sz.height, color: col.color)));
        }
      }
    }

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

  ReceivePort? _receivePort;
  Isolate? _isolate;
  SendPort? _isolateSendPort;

  static void remoteIsolate(SendPort sendPort) {
    init_highlighter();
    int theme = loadTheme(
        "/home/iceman/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json");
    int lang = loadLanguage("test.cpp");
    ReceivePort _isolateReceivePort = ReceivePort();
    sendPort.send(_isolateReceivePort.sendPort);
    _isolateReceivePort.listen((message) {
      if (message == '?') {
        // return
      } else {
        List<String> res = [];
        List<String> s = message.split(']::[');
        if (s.length != 2) return;
        if (s[1].length == 0 || s[1][s[1].length - 1] != ']') {
          return;
        }
        if (s[0].length == 0 || s[0][0] != '[') {
          return;
        }
        int line = int.parse(s[0].substring(1));

        String text = s[1].substring(0, s[1].length - 1);

        final nspans = runHighlighter(text, lang, theme, 0, 0, 0);

        List<Object> objs = [];

        int idx = 0;
        while (idx < (2048 * 4)) {
          final spn = nspans[idx++];
          if (spn.start == 0 && spn.length == 0) break;
          int s = spn.start;
          int l = spn.length;

          // todo... cleanup these checks
          if (s < 0) continue;
          if (s - 1 >= text.length) continue;
          if (s + l >= text.length) {
            l = text.length - s;
          }
          if (l <= 0) continue;

          Color fg = Color.fromRGBO(spn.r, spn.g, spn.b, 1);
          bool hasBg = (spn.bg_r + spn.bg_g + spn.bg_b != 0);

          LineDecoration d = LineDecoration();
          d.start = s;
          d.end = s + l - 1;
          d.color = fg;
          objs.add(d.toObject());
        }

        String json = jsonEncode({'line': line, 'decors': objs});
        sendPort.send(json);
      }
    });
  }

  Future spawnIsolate() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(remoteIsolate, _receivePort!.sendPort,
        debugName: "remoteIsolate");

    _receivePort?.listen((msg) {
      if (msg is SendPort) {
        _isolateSendPort = msg;
      } else {
        DocumentProvider doc =
            Provider.of<DocumentProvider>(context, listen: false);

        final jm = jsonDecode(msg);
        List<LineDecoration> decors = [];

        int line = jm['line'] ?? 0;
        Block block = doc.doc.blockAtLine(line) ?? Block('');
        // if (block.spans != null) return;

        for (final obj in jm['decors'] ?? []) {
          LineDecoration d = LineDecoration();
          d.fromObject(obj);
          decors.add(d);
        }

        Highlighter hl = Provider.of<Highlighter>(context, listen: false);
        block.decors = decors;

        hl.run(block, block.line, block.document ?? Document());
        setState(() {
          block.waiting = false;
          // pulse
        });
      }
    });
  }

  int themeId = 0;
  int langId = 0;

  @override
  void initState() {
    // spawnIsolate();

    init_highlighter();
    themeId = loadTheme(
        "/home/iceman/.editor/extensions/dracula-theme.theme-dracula-2.24.2/theme/dracula.json");
    langId = loadLanguage("test.cpp");

    // print('$themeId $langId');

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
    if (_isolate != null) {
      _isolate!.kill();
    }
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

    int docSize = doc.doc.blocks.length;

    // highlight run
    // Highlighter hl = Provider.of<Highlighter>(context);
    // for (int i = 0; i < count; i++) {
    //   int line = visibleLine + i;
    //   if (line >= docSize) {
    //     break;
    //   }
    //   Block block = doc.doc.blockAtLine(line) ?? Block('');
    //   // block.line = line;
    //   // String text = block.text;
    //   // int lineNumber = block.line;

    //   // print('build ${block?.line}');
    //   // List<InlineSpan> spans = hl.run(block, lineNumber, doc.doc);
    //   if (_isolateSendPort != null)
    //   if (block.spans == null) {
    //     _isolateSendPort!.send('[$line]::[${block.text}]');
    //   }
    // }

    if ((!largeDoc && softWrap) || !softWrap) {
      return ListView.builder(
          controller: scroller,
          itemCount: doc.doc.blocks.length,
          itemExtent: softWrap ? null : fontHeight,
          itemBuilder: (BuildContext context, int line) {
            Block block = doc.doc.blockAtLine(line) ?? Block('');
            block.line = line;

            // if (_isolateSendPort != null) {
            //   if (block.spans == null && !block.waiting) {
            //     block.waiting = true;
            //     _isolateSendPort!.send('[$line]::[${block.text}]');
            //   }
            // }

            if (block.spans == null) {
              Highlighter hl = Provider.of<Highlighter>(context, listen: false);

              List<LineDecoration> decors = [];

              Block? prevBlock = block.previous;
              Block? nextBlock = block.next;

              String text = block.text;
              final nspans = runHighlighter(
                  text,
                  langId,
                  themeId,
                  block.blockId,
                  prevBlock?.blockId ?? 0,
                  nextBlock?.blockId ?? 0);

              int idx = 0;
              while (idx < (2048 * 4)) {
                final spn = nspans[idx++];
                if (spn.start == 0 && spn.length == 0) break;
                int s = spn.start;
                int l = spn.length;

                // todo... cleanup these checks
                if (s < 0) continue;
                if (s - 1 >= text.length) continue;
                if (s + l >= text.length) {
                  l = text.length - s;
                }
                if (l <= 0) continue;

                Color fg = Color.fromRGBO(spn.r, spn.g, spn.b, 1);
                bool hasBg = (spn.bg_r + spn.bg_g + spn.bg_b != 0);

                LineDecoration d = LineDecoration();
                d.start = s;
                d.end = s + l - 1;
                d.color = fg;
                decors.add(d);

                // print('$s $l ${spn.r}, ${spn.g}, ${spn.b}');
              }

              block.decors = decors;
              hl.run(block, block.line, block.document ?? Document());
            }

            return ViewLine(
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
      Block block = doc.doc.blockAtLine(line) ?? Block('');
      block.line = line;

      children.add(ViewLine(
          block: block,
          width: size.width - gutterWidth,
          height: fontHeight,
          gutterWidth: gutterWidth,
          gutterStyle: gutterStyle));

      if (!softWrap && gutterWidth > 0) {
        gutters.add(Container(
            color: theme.background,
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
