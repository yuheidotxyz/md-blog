import 'dart:io';
import 'settings.dart' as settings;

Map<String, Function> module = {
  settings.before_compiling_sass: () async {
    (await settings.modules_scss.create(recursive: true)).writeAsString(
        '\n' +
            ((await Process.run('highlight', [
              '--stdout',
              '--print-style',
              '--config-file',
              settings.highlight_theme.path
            ]))
                .stdout
                .toString()
                .replaceAll(RegExp(r'background-color' + r'[^;]*' + r';'), '')
                .replaceAll(RegExp(r'font-size' + r'[^;]*' + r';'), '')
                .replaceAll(RegExp(r'font-family' + r'[^;]*' + r';'), '')
                .replaceAll(
                    RegExp(r'[^{;]*' + r'#654321' + r'[^;]*' + r';'), '')),
        mode: FileMode.append);
  },
  settings.after_making_html: () {}
};
