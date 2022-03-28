import 'package:editor/services/indexer/indexer.dart';

void indexerTestRun() {
  Indexer idx = Indexer();
  idx.indexWords('the quick brown fox over jumped');
  idx.indexWords('the quickest brownied browni fox then jumped');
  // idx.dump();

  // idx.find('qui');
  
}

void main() {
  indexerTestRun();
}