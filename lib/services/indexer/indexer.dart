import 'dart:async';

RegExp _wordRegExp = new RegExp(
      r'[a-z_0-9]*',
      caseSensitive: false,
      multiLine: false,
    );


int _nodeId = 0;

class IndexNode {
    IndexNode({ String this.text = '', int this.level = 0}) {
        id = _nodeId++;
    }

    int id = 0;
    int level = 0;
    String text = '';
    bool word = false;

    Map<String, IndexNode> nodes = {};

    IndexNode? push(String text) {
        if (text.length < level) {
            return null;
        }
        String prefix = text.substring(0, level);
        if (!nodes.containsKey(prefix)) {
            nodes[prefix] = IndexNode(text: prefix, level: level+1);
        }
        if (prefix != text) {
            nodes[prefix]?.push(text);
        } else {
            nodes[prefix]?.word = true;
        }

        return nodes[prefix];
    }

    void dump({String pad = ''}) {
        print('-$pad ${word ? text : '.'}');
        pad += '  ';
        for(final t in nodes.keys) {
            print('>$level $pad $t');
            nodes[t]?.dump(pad: pad);
        }
    }

    void collect({List<String>? result}) {
        if (word && result != null) {
            result.add(text);
        }
        for(final t in nodes.keys) {
            nodes[t]?.collect(result: result);
        }
    }

    void find(String text, { List<String>? result }) {
        if (text.length < level) {
            return;
        }
        String prefix = text.substring(0, level);
        if (nodes.containsKey(prefix)) {
            if (prefix == text) {
                nodes[prefix]?.collect(result: result);
                return;
            }
             nodes[prefix]?.find(text, result: result);
        }
    }
}

class Indexer {
    Indexer();
    
    IndexNode root = IndexNode(text: '', level: 0);

    Future<void> indexWords(String text) async {
        final words = _wordRegExp.allMatches(text);
        for (final m in words) {
            var g = m.groups([0]);
            var t = g[0] ?? '';
            root.push(t);
        }
    }

    Future<List<String>> find(String text) async {
        List<String> result = [];
        root.find(text, result: result);
        return result;
    }

    void dump() {
        print('dump');
        root.dump();
    }
}