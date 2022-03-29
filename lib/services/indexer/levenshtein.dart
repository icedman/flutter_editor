// https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance
final MIN3 = (a, b, c) =>
    ((a) < (b) ? ((a) < (c) ? (a) : (c)) : ((b) < (c) ? (b) : (c)));
final MIN2 = (a, b) => (a < b ? a : b);
final MAX2 = (a, b) => (a > b ? a : b);

int levenshtein_distance(String _s1, String _s2) {
  String s1 = _s1.toLowerCase();
  String s2 = _s2.toLowerCase();
  int s1len = 0;
  int s2len = 0;
  int x = 0;
  int y = 0;
  int lastdiag = 0;
  int olddiag = 0;
  s1len = s1.length;
  s2len = s2.length;
  List<int> column = List.generate(512, (_) => 0);
  for (y = 1; y <= s1len; y++) {
    column[y] = y;
  }
  for (x = 1; x <= s2len; x++) {
    column[0] = x;
    lastdiag = x - 1;
    for (y = 1; y <= s1len; y++) {
      olddiag = column[y];
      column[y] = MIN3(column[y] + 1, column[y - 1] + 1,
          lastdiag + (s1[y - 1] == s2[x - 1] ? 0 : 1));
      lastdiag = olddiag;
    }
  }
  return (column[s1len]);
}

class Item {
  Item(this.string, this.score);
  String string = '';
  int score = 0;
}

List<String> rankList(List<String> list, String key) {
  List<Item> items = list.map((i) {
    return Item(i, levenshtein_distance(i, key));
  }).toList();

  items.sort((a, b) => a.score.compareTo(b.score));
  return items.map((i) => i.string).toList();
}
