import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';

import 'document.dart';
import 'highlighter.dart';
import 'theme.dart';

class DocumentProvider extends ChangeNotifier {
  Document doc = Document();

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
  ViewLine({this.lineNumber = 0, Block? this.block});

  int lineNumber = 0;
  Block? block;

  @override
  Widget build(BuildContext context) {
    String text = block?.text ?? '';
    DocumentProvider doc = Provider.of<DocumentProvider>(context);
    Highlighter hl = Provider.of<Highlighter>(context);
    List<InlineSpan> spans = hl.run(text, lineNumber, doc.doc);

    final gutterStyle = TextStyle(
        fontFamily: 'FiraCode', fontSize: gutterFontSize, color: comment);
    double gutterWidth =
        getTextExtents(' ${doc.doc.blocks.length} ', gutterStyle).width;

    return Stack(children: [
      Padding(
          padding: EdgeInsets.only(left: gutterWidth),
          child: RichText(text: TextSpan(children: spans), softWrap: true)),
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

  @override
  void initState() {
    scroller = ScrollController();
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
    return ListView.builder(
        controller: scroller,
        itemCount: doc.doc.blocks.length,
        itemBuilder: (BuildContext context, int index) {
          doc.doc.blocks[index].line = index;
          return ViewLine(lineNumber: index, block: doc.doc.blocks[index]);
        });
  }
}
