import 'dart:io';
import 'dart:collection' show SplayTreeSet;
import 'package:path/path.dart' as p;
import 'package:sass/sass.dart' as sass;
import 'settings.dart' as settings;

Future<void> run_modules(String state,
    [Map<Symbol, dynamic>? arguments]) async {
  await Future.forEach(settings.modules, (Map<String, Function> module) async {
    await Function.apply(module[state] ?? () {}, [], arguments);
  });
}

Future<void> compile_sass() async {
  await run_modules(settings.before_compiling_sass);
  await (await settings.main_css.create(recursive: true)).writeAsString(sass
      .compileToResult(settings.main_scss.path,
          style: sass.OutputStyle.compressed)
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
    Directory dir = Directory(p.join(settings.articles.path, id));
    try {
      directory =
          File(p.join(dir.path, settings.html_directory)).readAsStringSync();
    } finally {
      directory = p.normalize(esc(directory, inline: true));
      if (directory.startsWith('/')) {
        directory = directory.substring(1);
      }
    }
    try {
      description =
          File(p.join(dir.path, settings.html_description)).readAsStringSync();
    } finally {
      description = esc(description, inline: true);
    }
    try {
      File main_md = File(p.join(dir.path, settings.html_main));
      md = main_md.readAsStringSync();
      int unix_time = int.parse(Process.runSync(
          settings.lastmod_out.absolute.path, [main_md.absolute.path]).stdout);
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
  await for (FileSystemEntity entity in settings.articles.list()) {
    if (entity is Directory) {
      site_map.add_file(HtmlFile(p.basename(entity.path)));
    }
  }
}
