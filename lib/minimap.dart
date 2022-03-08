import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'document.dart';
import 'highlighter.dart';

int minimapLineSpacing = 3;
int minimapSkipX = 1;

class MapPainter extends CustomPainter {
  MapPainter(
      {Document? this.doc,
      Highlighter? this.hl,
      int this.start = 0,
      int this.perPage = 10,
      int this.hash = 0})
      : super();

  int hash = -1;
  int start = 0;
  int perPage = 0;
  Document? doc;
  Highlighter? hl;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    canvas.scale(0.5, 1);

    var paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;

    Block? block = doc?.blockAtLine(start * perPage) ?? Block('');
    for (int l = 0; l < perPage; l++) {
      double j = 0;
      double y = (minimapLineSpacing * l).toDouble();

      List<InlineSpan> spans = block?.spans ?? [];
      if (spans.length == 0) {
        int lineNumber = block?.line ?? 0;
        spans = hl?.run(block, lineNumber, doc ?? Document()) ?? [];
      }

      bool inSelection = spans.length > 0 && (block?.spans ?? []).length == 0;

      for (final span in spans) {
        if (!(span is TextSpan)) break;
        int l = (span.text ?? '').length;
        if (l > 100) l = 100;
        for (int i = 0; i < l; i += minimapSkipX) {
          if (span.text?[i] == ' ') continue;
          Offset startingPoint = Offset((j + i), y);
          Offset endingPoint = Offset((j + i + minimapSkipX), y);
          Color clr = span.style?.color ?? Colors.yellow;
          paint.color = clr;
          if (inSelection) {
            paint.color = clr.withOpacity(0.5);
          }
          canvas.drawLine(startingPoint, endingPoint, paint);
          j++;
        }
      }

      block = block?.next;
      if (block == null) break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // int oldHash = (oldDelegate as MapPainter).hash;
    // return ((oldHash != hash) || hash == 0);
    return true;
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
    return CustomPaint(
        painter: MapPainter(
            doc: doc.doc, hl: hl, start: start, perPage: perPage, hash: hash),
        child: Container());
  }
}

class Minimap extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    DocumentProvider doc = Provider.of<DocumentProvider>(context);

    int perPage = 100;
    int pages = doc.doc.blocks.length ~/ perPage;
    if (pages <= 0) pages = 1;

    return ListView.builder(
        itemCount: pages,
        itemExtent: (perPage * minimapLineSpacing).toDouble(),
        itemBuilder: (context, index) {
          int hash = 0;
          Block? block = doc.doc.blockAtLine((index * perPage)) ?? Block('');
          for (int i = 0; i < perPage; i++) {
            hash += ((block?.text ?? '').length); // improve
            hash += ((block?.spans ?? []).length) << 4;

            block = block?.next;
            if (block == null) break;
          }

          return MinimapPage(start: index, perPage: perPage, hash: hash);
        });
  }
}
