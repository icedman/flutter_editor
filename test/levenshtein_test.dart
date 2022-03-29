import 'package:editor/services/indexer/levenshtein.dart';

void main() {
    var strings = [ 'marvin', 'mark', 'michael', 'marilyn' ];
    var key = 'marivn';
    print(strings);
    print(key);
    print(rankList(strings, key));
}
