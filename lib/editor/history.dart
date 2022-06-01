import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/block.dart';
import 'package:editor/editor/document.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

class Action {
  String type = '';
  String redoText = '';
  // String inserted = '';
  String insertedText = '';
  String deletedText = '';
  int column = 0;
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

      /*
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
      */

      // for (final a in entry.actions) {
      //   if (a.block?.originalText == null) {
      //     a.block?.originalText = a.block?.text ?? '';
      //   }
      // }

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

  void diff(Action action, String t1, String t2) {
    DiffMatchPatch p = DiffMatchPatch();
    List<Diff> diffs = p.diff(t1, t2);
    action.column = 0;
    if (diffs.length > 1) {
      if (diffs[0].operation == 0) {
        action.column = diffs[0].text.length;
      }
      if (diffs[1].operation == 1) {
        action.insertedText = diffs[1].text;
      }
      if (diffs[1].operation == -1) {
        action.deletedText = diffs[1].text;
      }
    }
  }

  void update(Block? block, {String type = 'update', String newText = ''}) {
    // print('update ${block?.text} [$newText]');
    Action action = Action();
    action.type = type;
    action.block = block;
    diff(action, block?.text ?? '', newText);
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
    for (final a in last.actions) {
      // print('redo ${a.type} ${a.text} ${a.redoText}<<');
      switch (a.type) {
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
          a.block?.text = a.redoText;
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
      // print('undo ${a.type} ${a.text}<<');
      switch (a.type) {
        case 'update':
          {
            a.redoText = a.block?.text ?? '';
            // a.block?.text = a.text;

            Cursor cur = doc.cursor().copy();
            cur.block = a.block;
            cur.column = a.column;
            cur.clearSelection();

            if (a.insertedText.length > 0) {
              cur.deleteText(numberOfCharacters: a.insertedText.length);
            } else if (a.deletedText.length > 0) {
              cur.insertText(a.deletedText);
            }

            a.block?.makeDirty(highlight: true);
            break;
          }

        case 'remove':
          update = true;
          a.redoText = a.block?.text ?? '';
          _reinsert(a.block);
          break;

        case 'add':
          update = true;
          a.redoText = a.block?.text ?? '';
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
