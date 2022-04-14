import 'dart:convert';

class Command {
    Command(String this.command, { dynamic this.params });
    String command = '';
    dynamic params;
}

class Keybindings {
    Map<String, Command> commands = {
        'ctrl+q': Command(''),
        'ctrl+f': Command('search'),
        'ctrl+g': Command('jump_to_line'),
        'ctrl+z': Command('undo'),
        'ctrl+shift+z': Command('redo'),
        'ctrl+]': Command('indent'),
        'ctrl+[': Command('unindent'),
        'ctrl+/': Command('toggle_comment'),
        'ctrl+c': Command('copy'),
        'ctrl+x': Command('cut'),
        'ctrl+v': Command('paster'),
        'ctrl+a': Command('select_all'),
        'ctrl+d': Command('select_word'),
        'ctrl+l': Command('select_line'),
        'ctrl+shift+d': Command('duplicate_selection'),
        'ctrl+s': Command('save'),
        'ctrl+alt+[': Command('toggle_fold'),
        'ctrl+alt+]': Command('unfold_all'),
        
    };
    
    Command? resolve(String keys) {
        return commands[keys];
    }
}
