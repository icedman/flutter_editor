import 'package:diff_match_patch/diff_match_patch.dart';

void diff(String t1, String t2) {
    print('-------');
    print('[$t1] [$t2]');
    print('-------');
    DiffMatchPatch p = DiffMatchPatch();
    List<Diff> diffs = p.diff(t1, t2);
    for(var d in diffs) {
        print(d);
    }
}

void diffTestRun() {
    diff('the brown', 'the quick brown');
    diff('abc', 'abcd');
    diff('1245', '12345');
    diff('xyz', '1xyz');

    diff('the quick brown', 'the brown');
    diff('abcd', 'abc');
    diff('12345', '1245');
    diff('1xyz', 'xyz');
}

void main() {
  diffTestRun();
}
