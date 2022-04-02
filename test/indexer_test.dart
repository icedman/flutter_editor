import 'package:editor/services/indexer/indexer.dart';

void indexerTestRun() async {
  Indexer idx = Indexer();
  idx.indexWords('the quick brown fox over jumped');
  idx.indexWords('the quickest brownied browni fox then jumped');
  await idx.file('./test/tinywl.c');
  idx.dump();

  idx.find('qui').then((res) {
    print(res);
  });
  idx.find('BROW').then((res) {
    print(res);
  });
}

void main() {
  indexerTestRun();
}
