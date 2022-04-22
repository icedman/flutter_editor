import 'dart:async';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/input.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/highlight/theme.dart';

class SearchPopup extends StatefulWidget {
  SearchPopup(
      {Function? this.onSubmit,
      bool this.ignoreCase = false,
      bool this.regex = false,
      bool this.replace = false,
      bool this.searchFiles = false});

  Function? onSubmit;
  bool regex = false;
  bool replace = false;
  bool ignoreCase = true;
  bool searchFiles = false;
  int searchDirection = 0;

  @override
  _SearchPopup createState() => _SearchPopup();
}

class _SearchPopup extends State<SearchPopup> {
  late FocusNode focusNode1;
  late FocusNode focusNode2;
  late FocusNode focusNode3;
  late TextEditingController inputEditController;
  late TextEditingController inputEditController2;
  late TextEditingController inputEditController3;

  bool regex = false;
  bool replace = false;
  bool ignoreCase = false;
  int searchDirection = 0;
  bool repeat = true;
  bool searchFiles = false;

  @override
  void initState() {
    super.initState();
    focusNode1 = FocusNode();
    inputEditController = TextEditingController();
    focusNode2 = FocusNode();
    inputEditController2 = TextEditingController();
    focusNode3 = FocusNode();
    inputEditController3 = TextEditingController();

    regex = widget.regex;
    replace = widget.replace;
    ignoreCase = widget.ignoreCase;
    searchDirection = widget.searchDirection;
    searchFiles = widget.searchFiles;

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      focusNode1.requestFocus();
    });
  }

  @override
  void dispose() {
    focusNode1.dispose();
    inputEditController.dispose();
    focusNode2.dispose();
    inputEditController2.dispose();
    focusNode3.dispose();
    inputEditController3.dispose();
    super.dispose();
  }

  void _search() {
    widget.onSubmit?.call(inputEditController.text,
        direction: searchDirection == 0 ? 1 : 0,
        caseSensitive: !ignoreCase,
        regex: regex,
        replace: inputEditController2.text.isNotEmpty
            ? inputEditController2.text
            : null,
        repeat: repeat);
  }

  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context);
    UIProvider ui = Provider.of<UIProvider>(context);
    HLTheme theme = Provider.of<HLTheme>(context);

    Widget inputText = Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: TextField(
            onSubmitted: (value) {
              _search();
              focusNode1.requestFocus();
            },
            textInputAction: TextInputAction.done,
            style: TextStyle(
                //fontFamily: app.fontFamily,
                fontSize: theme.uiFontSize,
                color: theme.foreground),
            controller: inputEditController,
            decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Find...',
                hintStyle: TextStyle(
                    //fontFamily: theme.fontFamily,
                    fontSize: theme.uiFontSize,
                    fontStyle: FontStyle.italic,
                    color: theme.comment)),
            focusNode: focusNode1,
            autofocus: true));

    Widget inputText2 = Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: TextField(
            onSubmitted: (value) {
              _search();
              focusNode2.requestFocus();
            },
            textInputAction: TextInputAction.done,
            style: TextStyle(
                //fontFamily: app.fontFamily,
                fontSize: theme.uiFontSize,
                color: theme.foreground),
            controller: inputEditController2,
            decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Replace with...',
                hintStyle: TextStyle(
                    //fontFamily: theme.fontFamily,
                    fontSize: theme.uiFontSize,
                    fontStyle: FontStyle.italic,
                    color: theme.comment)),
            focusNode: focusNode2,
            autofocus: true));

    Widget inputText3 = Padding(
        padding: const EdgeInsets.only(left: 8, right: 8),
        child: TextField(
            onSubmitted: (value) {
              _search();
              focusNode3.requestFocus();
            },
            textInputAction: TextInputAction.done,
            style: TextStyle(
                //fontFamily: app.fontFamily,
                fontSize: theme.uiFontSize,
                color: theme.foreground),
            controller: inputEditController3,
            decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Where...',
                hintStyle: TextStyle(
                    //fontFamily: theme.fontFamily,
                    fontSize: theme.uiFontSize,
                    fontStyle: FontStyle.italic,
                    color: theme.comment)),
            focusNode: focusNode3,
            autofocus: true));

    return Positioned(
        right: 0,
        top: app.tabbarHeight,
        child: Material(
            color: darken(theme.background, sidebarDarken),
            child: Container(
                width: 400,
                // decoration: BoxDecoration(
                //   color: darken(theme.background, sidebarDarken),
                //   // borderRadius:
                //   //     BorderRadius.only(bottomLeft: const Radius.circular(8.0))
                // ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(child: inputText),
                    IconButton(
                        icon: Icon(Icons.close, size: theme.uiFontSize),
                        color: theme.comment,
                        onPressed: () {
                          ui.clearPopups();
                          focusNode1.requestFocus();
                        }),
                  ]),

                  if (replace && !searchFiles) ...[inputText2],

                  if (searchFiles) ...[inputText3],

                  Row(children: [
                    if (!searchFiles) ...[
                      IconButton(
                          icon: Icon(Icons.north, size: theme.uiFontSize),
                          color: searchDirection == 1
                              ? theme.function
                              : theme.comment,
                          onPressed: () {
                            setState(() {
                              searchDirection = 1;
                            });
                            _search();
                            focusNode1.requestFocus();
                          }),
                      IconButton(
                          icon: Icon(Icons.south, size: theme.uiFontSize),
                          color: searchDirection == 0
                              ? theme.function
                              : theme.comment,
                          onPressed: () {
                            setState(() {
                              searchDirection = 0;
                            });
                            _search();
                            focusNode1.requestFocus();
                          }),
                    ],
                    IconButton(
                        icon: Text('Aa',
                            style: TextStyle(
                                fontSize: theme.uiFontSize,
                                color:
                                    ignoreCase ? theme.comment : theme.function,
                                fontWeight: FontWeight.bold)),
                        color: ignoreCase ? theme.comment : theme.function,
                        onPressed: () {
                          setState(() {
                            ignoreCase = !ignoreCase;
                          });
                          focusNode1.requestFocus();
                        }),
                    IconButton(
                        icon: Text('.*',
                            style: TextStyle(
                                fontSize: theme.uiFontSize,
                                color: regex ? theme.function : theme.comment,
                                fontWeight: FontWeight.bold)),
                        color: regex ? theme.function : theme.comment,
                        onPressed: () {
                          setState(() {
                            regex = !regex;
                          });
                          focusNode1.requestFocus();
                        }),
                    if (!searchFiles) ...[
                      IconButton(
                          icon: Icon(Icons.find_replace,
                              size: theme.uiFontSize,
                              color: replace ? theme.function : theme.comment),
                          onPressed: () {
                            if (searchFiles) return;
                            setState(() {
                              replace = !replace;
                            });
                          }),
                      IconButton(
                          icon: Icon(Icons.repeat,
                              size: theme.uiFontSize,
                              color: repeat ? theme.function : theme.comment),
                          onPressed: () {
                            setState(() {
                              repeat = !repeat;
                            });
                            focusNode1.requestFocus();
                          }),
                    ],
                    IconButton(
                        icon: Icon(Icons.folder,
                            size: theme.uiFontSize,
                            color:
                                searchFiles ? theme.function : theme.comment),
                        onPressed: () {
                          setState(() {
                            searchFiles = !searchFiles;
                          });
                          focusNode1.requestFocus();
                        }),
                    Expanded(child: Container()),
                  ]),
                  // Expanded(child: Container())
                ]))));
  }
}

class GotoPopup extends StatefulWidget {
  GotoPopup({Function? this.onSubmit});

  Function? onSubmit;

  @override
  _GotoPopup createState() => _GotoPopup();
}

class _GotoPopup extends State<GotoPopup> {
  late FocusNode focusNode;
  late TextEditingController inputEditController;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    inputEditController = TextEditingController();

    WidgetsBinding.instance?.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    focusNode.dispose();
    inputEditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context);
    UIProvider ui = Provider.of<UIProvider>(context);
    HLTheme theme = Provider.of<HLTheme>(context);

    double sz = 20;
    return Positioned(
        right: 0,
        top: app.tabbarHeight,
        child: Container(
            width: 400,
            decoration: BoxDecoration(
              color: darken(theme.background, sidebarDarken),
              // borderRadius:
              //     BorderRadius.only(bottomLeft: const Radius.circular(8.0))
            ),
            child: Row(children: [
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 8),
                      child: TextField(
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly
                          ], // Only numbers can be entered
                          onSubmitted: (value) {
                            int line = int.tryParse(value) ?? 0;
                            widget.onSubmit?.call(line);
                            focusNode.requestFocus();
                          },
                          textInputAction: TextInputAction.done,
                          style: TextStyle(
                              //fontFamily: theme.fontFamily,
                              fontSize: theme.uiFontSize,
                              color: theme.foreground),
                          controller: inputEditController,
                          decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Line number...',
                              hintStyle: TextStyle(
                                  //fontFamily: theme.fontFamily,
                                  fontSize: theme.uiFontSize,
                                  fontStyle: FontStyle.italic,
                                  color: theme.comment)),
                          focusNode: focusNode,
                          autofocus: true))),
              IconButton(
                  icon: Icon(Icons.close, size: theme.uiFontSize),
                  color: theme.comment,
                  onPressed: () {
                    ui.clearPopups();
                  }),
            ])));
  }
}
