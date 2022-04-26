import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:editor/editor/document.dart';
import 'package:editor/editor/decorations.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';

int minimapLineSpacing = 3;
int minimapSkipX = 2;
double minimapScaleX = 0.5;

class MapPainter extends CustomPainter {
  MapPainter(
      {Document? this.doc,
      Highlighter? this.hl,
      int this.start = 0,
      int this.perPage = 10,
      int this.hash = 0})
      : super() {
    _paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
  }

  int hash = -1;
  int start = 0;
  int perPage = 0;
  Document? doc;
  Highlighter? hl;

  late Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    canvas.scale(minimapScaleX, 1);

    Block? block = doc?.blockAtLine(start * perPage) ?? Block('');
    for (int l = 0; l < perPage; l++) {
      double j = 0;
      double y = (minimapLineSpacing * l).toDouble();

      List<InlineSpan> spans = block?.spans ?? [];
      if (spans.length == 0) {
        int lineNumber = block?.line ?? 0;
        spans = hl?.run(block, lineNumber, doc ?? Document()) ?? [];
      }

      for (final span in spans) {
        if (!(span is TextSpan)) break;
        int l = (span.text ?? '').length;
        if (l > 100) l = 100;
        for (int i = 0; i < l; i += minimapSkipX) {
          if (span.text?[i] == ' ') continue;
          Offset startingPoint = Offset((j + i), y);
          Offset endingPoint = Offset((j + i + minimapSkipX / 1.5), y);
          Color clr = span.style?.color ?? Colors.yellow;
          _paint.color = clr;
          canvas.drawLine(startingPoint, endingPoint, _paint);
        }
        j += l;
      }

      block = block?.next;
      if (block == null) break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    int oldHash = (oldDelegate as MapPainter).hash;
    bool repaint = ((oldHash != hash) || hash == 0);
    return repaint;
  }
}

class MinimapPage extends StatelessWidget {
  MinimapPage({int this.start = 0, int this.perPage = 10, int this.hash = 0});

  int start = 0;
  int perPage = 10;
  int hash = 0;

  @override
  Widget build(BuildContext context) {
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    Highlighter hl = Provider.of<Highlighter>(context);
    return GestureDetector(
        child: CustomPaint(
            painter: MapPainter(
                doc: doc.doc,
                hl: hl,
                start: start,
                perPage: perPage,
                hash: hash),
            child: Container()),
        onPanUpdate: (details) {
          onTap(context, details.globalPosition);
        },
        onTapDown: (TapDownDetails details) {
          onTap(context, details.globalPosition);
        });
  }

  void onTap(context, tapPos) {
    RenderObject? obj = context.findRenderObject();
    RenderBox box = obj as RenderBox;
    Offset pos = box.localToGlobal(Offset.zero);
    double dy = tapPos.dy - pos.dy;
    double p = dy * 100 / (box.size.height + 0.001);
    int lead = p > 50 ? 8 : -8;
    int l = p.toInt() + (start * perPage);
    DocumentProvider doc =
        Provider.of<DocumentProvider>(context, listen: false);
    doc.scrollTo = l + lead;
    doc.touch();
  }
}

class Minimap extends StatefulWidget {
  @override
  _Minimap createState() => _Minimap();
}

class _Minimap extends State<Minimap> {
  late ScrollController scroller;
  Offset scrollPosition = Offset.zero;
  double target = 0;
  bool showIndicator = true;

  @override
  void initState() {
    scroller = ScrollController();

    scroller.addListener(() {
      setState(() {
        showIndicator = false;
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    scroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    HLTheme theme = Provider.of<HLTheme>(context);
    DecorInfo decor = Provider.of<DecorInfo>(context);
    int viewPortHeight = (decor.visibleEnd - decor.visibleStart);

    if (!doc.showMinimap || !doc.ready) {
      return Container();
    }

    int perPage = 100;
    int pages = doc.doc.blocks.length ~/ perPage;
    if (pages <= 0) pages = 1;

    if (decor.scrollPosition != scrollPosition) {
      scrollPosition = decor.scrollPosition;
      if (!scroller.positions.isEmpty) {
        double p = 0;
        if (doc.doc.blocks.length > viewPortHeight) {
          p = decor.visibleStart / (doc.doc.blocks.length - viewPortHeight);
        }
        if (p >= 0) {
          target = p * scroller.position.maxScrollExtent;
          if (target > scroller.position.maxScrollExtent) {
            target = scroller.position.maxScrollExtent;
          }
          scroller.jumpTo(target);
          showIndicator = true;
        }
      }
    }

    double currentScroll =
        scroller.positions.isEmpty ? 0 : scroller.position.pixels;

    double mapWidth = Platform.isAndroid ? 60 : 80;
    return Container(
        width: mapWidth,
        child: Stack(children: [
          Positioned(
              top: ((decor.visibleStart - viewPortHeight / 4) *
                          minimapLineSpacing)
                      .toDouble() -
                  currentScroll,
              child: !showIndicator
                  ? Container()
                  : Container(
                      width: mapWidth,
                      height: (viewPortHeight * minimapLineSpacing).toDouble(),
                      color: colorCombine(theme.selection, theme.background,
                          aw: 1, bw: 4))),
          ListView.builder(
              controller: scroller,
              itemCount: pages,
              itemExtent: (perPage * minimapLineSpacing).toDouble(),
              itemBuilder: (context, index) {
                int hash = 0;
                Block? block =
                    doc.doc.blockAtLine((index * perPage)) ?? Block('');
                for (int i = 0; i < perPage; i++) {
                  hash += ((block?.text ?? '').length); // improve
                  hash += ((block?.spans ?? []).length) << 4;
                  block = block?.next;
                  if (block == null) break;
                }
                return MinimapPage(start: index, perPage: perPage, hash: hash);
              }),
        ]));
  }
}
