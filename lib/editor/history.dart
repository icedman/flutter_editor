import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';

class Action {
  String type = '';
  String text = '';
  String redoText = '';
  String inserted = '';
  Block? block;
}

class HistoryEntry {
  List<Cursor> cursors = [];
  List<Action> actions = [];
  List<Cursor> redoCursors = [];
}

class History {
  List<HistoryEntry> entries = [];
  List<HistoryEntry> redoEntries = [];
  List<Cursor> cursors = [];
  List<Action> actions = [];

  void begin(Document doc) {
    cursors = doc.cursors.map((c) => c.copy()).toList();
    actions = [];
  }

  void commit() {
    if (actions.isNotEmpty) {
      HistoryEntry entry = HistoryEntry();
      entry.cursors = cursors;
      entry.actions = actions;

      if (entries.length > 1 && entry.actions.length == 1) {
        HistoryEntry prev = entries.last;
        if (prev.actions.length == 1) {
          if (entry.actions[0].inserted != ' ' &&
              prev.actions[0].type == entry.actions[0].type &&
              prev.actions[0].block == entry.actions[0].block) {
            // prev.actions[0].text = actions[0].text;
            // prev.cursors = cursors;
            return;
          }
        }
      }

      for (final a in entry.actions) {
        a.redoText = a.block?.text ?? '';
      }

      entries.add(entry);
      redoEntries.clear();
    }
  }

  void add(Block? block) {
    // print('add ${block?.text}');
    Action action = Action();
    action.type = 'add';
    action.block = block;
    actions.add(action);
  }

  void remove(Block? block) {
    // print('remove ${block?.text}');
    Action action = Action();
    action.type = 'remove';
    action.block = block;
    actions.add(action);
  }

  void update(Block? block, {String type = 'update', String inserted = ''}) {
    // print('update ${block?.text}');
    Action action = Action();
    action.type = type;
    action.block = block;
    action.text = block?.text ?? '';
    action.inserted = inserted;
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

  void redo(Document doc) {
    if (redoEntries.length == 0) {
      return;
    }
    
    bool update = false;

    HistoryEntry last = redoEntries.removeLast();
    entries.add(last);
    for (final a in last.actions.reversed) {
      switch (a.type) {
        case 'insert':
        case 'update':
          a.block?.text = a.redoText;
          a.block?.makeDirty(highlight: true);
          break;

        case 'add':
          _reinsert(a.block);
          update = true;
          a.block?.text = a.redoText;
          break;

        case 'remove':
          update = true;
          _remove(a.block);
          break;
      }
    }

    doc.cursors = [];
    for (final c in last.redoCursors) {
      doc.cursors.add(c.copy());
    }
    
    if (update) {
      doc.updateLineNumbers(0);
    }
  }

  void undo(Document doc) {
    if (entries.length == 0) {
      return;
    }
    
    bool update = false;

    HistoryEntry last = entries.removeLast();
    redoEntries.add(last);
    for (final a in last.actions.reversed) {
      switch (a.type) {
        case 'insert':
        case 'update':
          a.redoText = a.block?.text ?? a.text;
          a.block?.text = a.text;
          a.block?.makeDirty(highlight: true);
          break;

        case 'remove':
          update = true;
          _reinsert(a.block);
          break;

        case 'add':
          update = true;
          _remove(a.block);
          break;
      }
    }
    last.redoCursors = doc.cursors.map((c) => c.copy()).toList();

    doc.cursors = [];
    for (final c in last.cursors) {
      doc.cursors.add(c.copy());
    }
    
    if (update) {
      doc.updateLineNumbers(0);
    }
  }
}
