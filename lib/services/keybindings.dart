import 'dart:convert';

class Command {
  Command(String this.command, [dynamic this.params]);
  String command = '';
  dynamic params;
}

class Keybindings {
  Map<String, Command> commands = {
    'ctrl+q': Command('quit'),
    'ctrl+f': Command('search'),
    'ctrl+shift+f': Command('search_in_files'),
    'ctrl+g': Command('jump_to_line'),
    'ctrl+z': Command('undo'),
    'ctrl+shift+z': Command('redo'),
    'ctrl+]': Command('indent'),
    'ctrl+[': Command('unindent'),
    'ctrl+/': Command('toggle_comment'),
    'ctrl+c': Command('copy'),
    'ctrl+x': Command('cut'),
    'ctrl+v': Command('paste'),
    'ctrl+a': Command('select_all'),
    'ctrl+d': Command('select_word'),
    'ctrl+l': Command('select_line'),
    'ctrl+shift+d': Command('duplicate_selection'),
    'ctrl+alt+[': Command('toggle_fold'),
    'ctrl+alt+]': Command('unfold_all'),
    'ctrl+s': Command('save'),
    'ctrl+w': Command('close'),
    'ctrl+1': Command('switch_tab', 0),
    'ctrl+2': Command('switch_tab', 1),
    'ctrl+3': Command('switch_tab', 2),
    'ctrl+4': Command('switch_tab', 3),
    'ctrl+5': Command('switch_tab', 4),
    'ctrl+6': Command('switch_tab', 5),
    'ctrl+7': Command('switch_tab', 6),
    'ctrl+8': Command('switch_tab', 7),
    'ctrl+9': Command('switch_tab', 8),
    'ctrl+0': Command('switch_tab', 9),
    'ctrl+shift+|': Command('toggle_pinned'),
  };

  Command? resolve(String keys) {
    // print(keys);
    return commands[keys];
  }
}
