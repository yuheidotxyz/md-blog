import 'dart:io';
import 'dart:collection' show SplayTreeSet;
import 'package:path/path.dart' as p;
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

class HtmlDir {
  SplayTreeSet<HtmlDir> dirs = SplayTreeSet<HtmlDir>((HtmlDir a, HtmlDir b) =>
      p.normalize(a.path).compareTo(p.normalize(b.path)));
  SplayTreeSet<HtmlFile> files =
      SplayTreeSet<HtmlFile>((HtmlFile a, HtmlFile b) => a.id.compareTo(b.id));
  DateTime lastmod = DateTime.fromMillisecondsSinceEpoch(0);
  String path;
  HtmlDir(this.path);
  void add_file(HtmlFile x) {
    if (p.isWithin(path, x.path())) {
      if (p.equals(path, x.directory)) {
        files.add(x);
      } else {
        String child_path = x.directory;
        while (!p.equals(path, p.dirname(child_path))) {
          child_path = p.dirname(child_path);
        }
        HtmlDir child_dir = HtmlDir(child_path);
        child_dir = dirs.lookup(child_dir) ?? child_dir;
        child_dir.add_file(x);
        dirs.remove(child_dir);
        dirs.add(child_dir);
      }
      if (x.lastmod.isAfter(lastmod)) {
        lastmod = x.lastmod;
      }
    }
  }
}

class HtmlFile {
  DateTime lastmod = DateTime.fromMillisecondsSinceEpoch(0);
  String directory = '';
  String description = '';
  String md = '';
  String id;
  HtmlFile(this.id) {
    id = esc(id, inline: true);
    Directory dir = Directory(p.join(files.articles.path, id));
    try {
      directory =
          File(p.join(dir.path, files.html_directory)).readAsStringSync();
    } finally {
      directory = p.normalize(esc(directory, inline: true));
      if (directory.startsWith('/')) {
        directory = directory.substring(1);
      }
    }
    try {
      description =
          File(p.join(dir.path, files.html_description)).readAsStringSync();
    } finally {
      description = esc(description, inline: true);
    }
    try {
      File main_md = File(p.join(dir.path, files.html_main));
      md = main_md.readAsStringSync();
      int unix_time = int.parse(Process.runSync(
          files.lastmod_out.absolute.path, [main_md.absolute.path]).stdout);
      lastmod = DateTime.fromMillisecondsSinceEpoch(unix_time * 1000);
    } finally {}
  }
  String path() => p.join(directory, "${id}.html");
}

String esc(String str, {bool inline = false}) {
  if (inline) {
    str = str.replaceAll(RegExp(r'\r?\n'), '').trim();
  }
  return str;
}

Future<void> main() async {
  compile_sass();
  HtmlDir site_map = HtmlDir('');
  await for (FileSystemEntity entity in files.articles.list()) {
    if (entity is Directory) {
      site_map.add_file(HtmlFile(p.basename(entity.path)));
    }
  }
}
