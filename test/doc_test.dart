import 'package:editor/editor/cursor.dart';
import 'package:editor/editor/document.dart';

Document docTestRun() {
  Document d = Document();
  d.insertText('hello ');
  d.insertText('world');
  d.moveCursorLeft(count: 5);
  d.insertText('flutter');
  d.show();
  d.deleteText(numberOfCharacters: 5);
  d.insertText('\n');
  d.insertText('another line');
  d.insertText('\n');
  d.begin();
  d.insertText('and another line');
  d.show();
  d.moveCursorUp();
  d.moveCursorToStartOfLine();
  d.deleteText(numberOfCharacters: 'another line'.length);
  d.moveCursorDown(count: 1);
  d.insertNewLine();
  d.insertText('and yet another line');
  d.show();
  d.moveCursorUp(count: 2);
  d.moveCursorToStartOfLine();
  d.moveCursorRight(count: 4);
  d.moveCursorDown(count: 2, keepAnchor: true);
  d.moveCursorRight(count: 4, keepAnchor: true);
  d.show();
  d.commit();
  d.undo();
  print('------');
  d.show();
  //d.moveCursorToEndOfLine(keepAnchor: true);
  // d.deleteSelectedText();
  // d.show();
  //d.deleteLine();
  //d.show();
  //d.moveCursorRight(count: 2);
  //d.moveCursorRight(count: 5, keepAnchor: true);
  //d.show();
  //d.deleteSelectedText();
  //d.show();
  Cursor cur = d.cursor().copy();
  cur.moveCursorUp();
  cur.moveCursorToStartOfLine();
  cur.moveCursorToStartOfDocument();
  Cursor? res = d.find(cur, 'l.nE', regex: true, caseSensitive: false, direction: 1);
  print('found $res');
  return d;
}

void main() {
  docTestRun();
}