import 'document.dart';

Document docTestRun() {
  Document d = Document();
  d.insertText('hello ');
  d.insertText('world');
  d.moveCursorLeft(count: 5);
  d.insertText('flutter');
  d.deleteText(numberOfCharacters: 5);
  d.insertText('\n');
  d.insertText('another line');
  d.insertText('\n');
  d.insertText('and another line');
  d.moveCursorUp();
  d.moveCursorToStartOfLine();
  d.deleteText(numberOfCharacters: 'another line'.length);
  d.moveCursorDown(count: 1);
  d.insertNewLine();
  d.insertText('and yet another line');
  d.moveCursorUp(count: 2);
  d.moveCursorToStartOfLine();
  d.moveCursorRight(count: 4);
  d.moveCursorDown(count: 2, keepAnchor: true);
  d.moveCursorRight(count: 4, keepAnchor: true);
  d.output();
  //d.moveCursorToEndOfLine(keepAnchor: true);
  d.deleteSelectedText();
  d.output();
  //d.deleteLine();
  //d.output();
  //d.moveCursorRight(count: 2);
  //d.moveCursorRight(count: 5, keepAnchor: true);
  //d.output();
  //d.deleteSelectedText();
  //d.output();
  return d;
}

void main() {
  docTestRun();
}