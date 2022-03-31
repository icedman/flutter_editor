import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:editor/services/highlight/theme.dart';
import 'package:editor/services/explorer/filesystem.dart';
import 'package:editor/services/explorer/localfs.dart';

class ExplorerProvider extends ChangeNotifier implements ExplorerListener {
  late Explorer explorer;

  List<ExplorerItem?> tree = [];

  ExplorerProvider() {
    explorer = Explorer();
    explorer.setBackend(LocalFs());
    explorer.backend?.addListener(this);
  }

  void onLoad(dynamic items) {
    rebuild();
  }

  void rebuild() {
    tree = explorer.tree();
    notifyListeners();
  }
}

class ExplorerTreeItem {
  ExplorerTreeItem({ExplorerItem? this.item, ExplorerProvider? this.provider});

  ExplorerItem? item;
  ExplorerProvider? provider;
  
  Widget build(BuildContext context) {
    HLTheme theme = Provider.of<HLTheme>(context);
    ExplorerItem? _item = item ?? ExplorerItem('');
    bool expanded = _item.isExpanded;

    double size = 16;
    Widget icon = _item.isDirectory ? Icon((expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
      size: size, color: theme.comment)
      : Container(width: size);

    TextStyle style = TextStyle(fontSize: theme.fontSize * 0.8, fontFamily: theme.fontFamily, color: theme.comment);

    return GestureDetector(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
            height: 32,
            // color: Colors.yellow,
            child: Row(children: [ 
                Container(width: _item.depth * size / 2),
                Padding(child: icon, padding: EdgeInsets.all(2)),
                Text(' ${_item.fileName}', style: style),
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
          }
          );
  }
}

class ExplorerTree extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    ExplorerProvider exp = Provider.of<ExplorerProvider>(context);
    List<ExplorerTreeItem> tree = [
      ...exp.tree.map((item) => ExplorerTreeItem(item: item, provider: exp))
    ];
    return Container(width: 240, child: ListView.builder(
      itemCount: tree.length,
      itemBuilder: (BuildContext context, int index) {
        ExplorerTreeItem _node = tree[index];
        return _node.build(context);
      }));
  }
}

