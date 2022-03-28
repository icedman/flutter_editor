import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';

class Action {
  String type = '';
  String text = '';
  Block? block;
}

class HistoryEntry {
  List<Cursor> cursors = [];
  List<Action> actions = [];
}

class History {
  List<HistoryEntry> entries = [];
  List<Cursor> cursors = [];
  List<Action> actions = [];

  void begin(Document doc) {
    cursors = [];
    for (final c in doc.cursors) {
      cursors.add(c.copy());
    }
    actions = [];
  }

  void commit() {
    if (actions.length > 0) {
      HistoryEntry entry = HistoryEntry();
      entry.cursors = cursors;
      entry.actions = actions;
      entries.add(entry);
    }
  }

  void add(Block? block) {
    // actions.add('add ${block?.text}');
    Action action = Action();
    action.type = 'add';
    action.block = block;
    actions.add(action);
  }

  void remove(Block? block) {
    // actions.add('remove ${block?.text}');
    Action action = Action();
    action.type = 'remove';
    action.block = block;
    actions.add(action);
  }

  void update(Block? block) {
    // actions.add('update ${block?.text}');
    Action action = Action();
    action.type = 'update';
    action.block = block;
    action.text = block?.text ?? '';
    actions.add(action);
  }

  void _reinsert(Block? block) {
    List<Block> blocks = block?.document?.blocks ?? [];
    Block? prev = block?.previous;
    int index = prev?.line ?? 0;
    if (block != null) {
      blocks.insert(index + 1, block);
    }
    block?.makeDirty(highlight: true);
    block?.document?.updateLineNumbers(index);
  }

  void _remove(Block? block) {
    List<Block> blocks = block?.document?.blocks ?? [];
    int index = block?.line ?? 0;
    blocks.removeAt(index);
    block?.document?.updateLineNumbers(index);
  }

  void undo(Document doc) {
    if (entries.length == 0) return;

    HistoryEntry last = entries.removeLast();
    for (final a in last.actions.reversed) {
      switch (a.type) {
        case 'update':
          a.block?.text = a.text;
          a.block?.makeDirty(highlight: true);
          break;

        case 'remove':
          _reinsert(a.block);
          break;

        case 'add':
          _remove(a.block);
          break;
      }
    }

    doc.cursors = [];
    for (final c in last.cursors) {
      doc.cursors.add(c.copy());
    }
  }
}
