import 'dart:io';
import 'package:editor/services/ffi/bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/svg.dart';
import 'package:editor/services/app.dart';
import 'package:editor/services/util.dart';
import 'package:editor/services/ffi/bridge.dart';
import 'package:editor/services/ui/ui.dart';
import 'package:editor/services/ui/menu.dart';
import 'package:editor/services/ui/modal.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/highlight/highlighter.dart';
import 'package:editor/services/explorer/filesystem.dart';
import 'package:editor/services/explorer/localfs.dart';

const int animateK = 55;

class FileIcon extends StatefulWidget {
  FileIcon({String this.path = '', double this.size = 20});

  String path = '';
  double size = 20;

  @override
  _FileIcon createState() => _FileIcon();
}

class _FileIcon extends State<FileIcon> {
  Widget? icon;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      File iconFile = File(widget.path);
      icon = SvgPicture.file(iconFile, width: widget.size, height: widget.size);
    }
    return icon ?? Container();
  }
}

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

    notifyListeners();
  }
}

class ExplorerTreeItem extends StatelessWidget {
  ExplorerTreeItem(
      {ExplorerItem? this.item,
      ExplorerProvider? this.provider,
      TextStyle? this.style});

  ExplorerItem? item;
  ExplorerProvider? provider;
  TextStyle? style;

  void showContextMenu(BuildContext context) {
    RenderObject? obj = context.findRenderObject();
    if (obj != null) {
      RenderBox? box = obj as RenderBox;
      Offset position = box.localToGlobal(Offset(box.size.width, 0));
      UIProvider ui = Provider.of<UIProvider>(context, listen: false);
      UIMenuData? menu = ui.menu('explorer::context', onSelect: (item) {
        Future.delayed(const Duration(milliseconds: 50), () {
          ui.setPopup(UIModal(message: 'Delete?'));
        });
      });
      menu?.items.clear();
      menu?.menuIndex = -1;
      for (final s in ['New Folder', 'New File']) {
        menu?.items.add(UIMenuData()..title = s);
      }
      ui.setPopup(
          UIMenuPopup(
            position: position,
            alignX: -2,
            alignY: 0,
            menu: menu,
          ),
          blur: false,
          shield: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    AppProvider app = Provider.of<AppProvider>(context);
    UIProvider ui = Provider.of<UIProvider>(context);
    HLTheme theme = Provider.of<HLTheme>(context);
    ExplorerItem? _item = item ?? ExplorerItem('');
    bool expanded = _item.isExpanded;

    double size = 16;
    Widget icon = _item.isDirectory
        ? Icon((expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
            size: size, color: theme.comment)
        : Container(width: size);

    bool isFocused = item?.fullPath == app.document?.docPath;
    // TextStyle? _style = style?.copyWith(color: isFocused ? theme.foreground : theme.comment);

    String iconPath = FFIBridge.iconForFileName(item?.fileName ?? '');
    Widget? fileIcon;

    if (_item.isDirectory) {
      fileIcon =
          Icon(Icons.folder, size: theme.uiFontSize + 2, color: theme.comment);
    } else {
      fileIcon = Padding(
          padding: EdgeInsets.only(left: 0 * theme.uiFontSize / 2),
          child: FileIcon(path: iconPath, size: theme.uiFontSize + 2));
    }

    return InkWell(
        child: GestureDetector(
            onSecondaryTapDown: (details) {
              showContextMenu(context);
            },
            child: Container(
                color: isFocused ? theme.selection.withOpacity(0.2) : null,
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                        height: 32,
                        child: Row(children: [
                          Container(width: _item.depth * size / 2),
                          Padding(
                              child: icon, padding: const EdgeInsets.all(2)),
                          fileIcon,
                          Text(
                            ' ${_item.fileName}',
                            style: style,
                            maxLines: 1,
                          ),
                          // IconButton(icon: Icon(Icons.close), onPressed:() {}),
                        ]))))),
        onTap: () {
          ui.clearPopups();
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
        fontSize: theme.uiFontSize,
        fontFamily: theme.uiFontFamily,
        letterSpacing: -0.5,
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
          duration: Duration(milliseconds: animateK * 4), //animateK * 3),
          opacity: opacity,
          // child: AnimatedSize(
          //     clipBehavior: Clip.hardEdge,
          //     curve: Curves.decelerate,
          //     duration: Duration(milliseconds: animateK * 2),
          //     child: AnimatedPadding(
          //         padding: EdgeInsets.only(left: (itemHeight - height) * 4 * 0),
          //         curve: Curves.decelerate,
          //         duration: Duration(milliseconds: animateK * 2),
          child: Container(height: height, child: child)
          // ))
          );
    }

    return Material(
        color: darken(theme.background, sidebarDarken),
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
                      child: _node, //.build(context),
                      height: h,
                      opacity: o,
                      animate: exp.animate);
                })));
  }
}
