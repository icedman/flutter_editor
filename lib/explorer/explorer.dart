import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';
import 'package:editor/services/explorer/filesystem.dart';
import 'package:editor/services/explorer/localfs.dart';

const int animateK = 55;

class ExplorerProvider extends ChangeNotifier implements ExplorerListener {
  late Explorer explorer;

  List<ExplorerItem?> tree = [];
  ExplorerItem? selected;
  bool animate = false;

  Function? onSelect;

  ExplorerProvider() {
    explorer = Explorer();
    explorer.setBackend(LocalFs());
    explorer.backend?.addListener(this);
  }

  void onLoad(dynamic items) {
    rebuild();
  }

  void onDelete(dynamic item) {
    rebuild();
  }

  void onError(dynamic error) {}

  void select(ExplorerItem? item) {
    selected = item;
    onSelect?.call(item);
  }

  void rebuild() {
    List<ExplorerItem?> _previous = [...tree];
    tree = explorer.tree();

    if (!animate) {
      for (final i in tree) {
        i?.height = 1;
      }
      notifyListeners();
      return;
    }

    Map<ExplorerItem?, List<bool>> hash = {};
    _previous.forEach((item) {
      hash[item] = hash[item] ?? [false, false];
      hash[item]?[0] = true;
    });
    tree.forEach((item) {
      hash[item] = hash[item] ?? [false, false];
      hash[item]?[1] = true;
    });

    List<ExplorerItem?> added = [];
    List<ExplorerItem?> removed = [];

    int interval = animateK;

    for (final k in hash.keys) {
      if (hash[k]?[0] == true && hash[k]?[1] == true) continue;
      if (hash[k]?[0] == true) {
        k?.height = 0;
        removed.add(k);

        Future.delayed(Duration(milliseconds: removed.length * interval), () {
          k?.height = 0;
          k?.duration = removed.length * interval;
          notifyListeners();
        });
      }
      if (hash[k]?[1] == true) {
        added.add(k);
        Future.delayed(Duration(milliseconds: added.length * interval), () {
          k?.height = 1;
          k?.duration = added.length * interval;
          notifyListeners();
        });

        interval -= 2;
        if (interval < 0) interval = 0;
      }
    }

    // if (removed.isNotEmpty) {
    //   List<ExplorerItem?> newTree = [...tree];
    //   tree = _previous;
    //   Future.delayed(Duration(milliseconds: removed.length * interval), () {
    //       tree = newTree;
    //       notifyListeners();
    //     });
    // }

    notifyListeners();
  }
}

class ExplorerTreeItem {
  ExplorerTreeItem(
      {ExplorerItem? this.item,
      ExplorerProvider? this.provider,
      TextStyle? this.style});

  ExplorerItem? item;
  ExplorerProvider? provider;
  TextStyle? style;

  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    ExplorerItem? _item = item ?? ExplorerItem('');
    bool expanded = _item.isExpanded;

    double size = 16;
    Widget icon = _item.isDirectory
        ? Icon((expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
            size: size, color: theme.comment)
        : Container(width: size);

    return InkWell(
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
                height: 32,
                // color: Colors.yellow,
                child: Row(children: [
                  Container(width: _item.depth * size / 2),
                  Padding(child: icon, padding: EdgeInsets.all(2)),
                  Text(
                    ' ${_item.fileName}',
                    style: style,
                    maxLines: 1,
                  ),
                  // IconButton(icon: Icon(Icons.close), onPressed:() {}),
                ]))),
        onTap: () {
          if (_item.isDirectory) {
            _item.isExpanded = !expanded;
            if (_item.isExpanded) {
              provider?.explorer.loadPath(_item.fullPath);
            }
            provider?.rebuild();
          }
          provider?.select(_item);
        });
  }
}

class ExplorerTree extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context);
    ExplorerProvider exp = Provider.of<ExplorerProvider>(context);

    HLTheme theme = Provider.of<HLTheme>(context);
    TextStyle style = TextStyle(
        fontSize: theme.fontSize,
        fontFamily: theme.fontFamily,
        color: theme.comment);

    Size sz = getTextExtents('item', style);
    double itemHeight = sz.height + 8;

    List<ExplorerTreeItem> tree = [
      ...exp.tree.map(
          (item) => ExplorerTreeItem(item: item, provider: exp, style: style))
    ];

    Widget _animate(
        {Key? key,
        Widget? child,
        double height = 0,
        double opacity = 0,
        bool animate = true}) {
      if (!animate) {
        return Container(height: height, child: child);
      }

      return AnimatedOpacity(
          key: ValueKey(key),
          curve: Curves.decelerate,
          duration: Duration(milliseconds: animateK * 3),
          opacity: opacity,
          child: AnimatedSize(
              clipBehavior: Clip.hardEdge,
              curve: Curves.decelerate,
              duration: Duration(milliseconds: animateK * 2),
              child: AnimatedPadding(
                  padding: EdgeInsets.only(left: (itemHeight - height) * 4 * 0),
                  curve: Curves.decelerate,
                  duration: Duration(milliseconds: animateK * 2),
                  child: Container(height: height, child: child))));
    }

    return Material(
        color: darken(theme.background, 0.04),
        child: Container(
            height: app.screenHeight,
            width: app.sidebarWidth,
            child: ListView.builder(
                itemCount: tree.length,
                itemBuilder: (BuildContext context, int index) {
                  ExplorerTreeItem _node = tree[index];
                  double h = itemHeight * (_node.item?.height ?? 0);
                  double o = 1 * (_node.item?.height ?? 0);
                  return _animate(
                      key: ValueKey(_node.item),
                      child: _node.build(context),
                      height: h,
                      opacity: o,
                      animate: false);
                })));
  }
}
