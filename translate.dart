import 'dart:io';
import 'package:sass/sass.dart' as sass;
import 'files.dart' as files;

Future<void> compile_sass() async {
  await (await files.highlight_scss.create(recursive: true)).writeAsString(
      (await Process.run('highlight', [
    '--stdout',
    '--print-style',
    '--config-file',
    files.highlight_theme.path
  ]))
          .stdout
          .toString()
          .replaceAll(RegExp(r'background-color' + r'[^;]*' + r';'), '')
          .replaceAll(RegExp(r'font-size' + r'[^;]*' + r';'), '')
          .replaceAll(RegExp(r'font-family' + r'[^;]*' + r';'), '')
          .replaceAll(RegExp(r'[^{;]*' + r'#654321' + r'[^;]*' + r';'), ''));
  (await files.main_css.create(recursive: true)).writeAsString(sass
      .compileToResult(files.main_scss.path, style: sass.OutputStyle.compressed)
      .css);
}

Future<void> main() async {
  compile_sass();
}
