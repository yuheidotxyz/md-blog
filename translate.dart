import 'dart:io';
import 'dart:collection' show SplayTreeSet, LinkedHashMap;
import 'dart:convert' show HtmlEscape;
import 'package:html/dom.dart' show Element, Document;
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart' show DateFormat;
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:sass/sass.dart' as sass;
import 'package:markdown/markdown.dart' as markdown;
import 'settings.dart' as settings;

Future<void> compile_sass() async {
  await (await settings.modules_scss.create(recursive: true)).writeAsString('');
  await Future.forEach(settings.modules, (Map<String, Function> module) async {
    await Function.apply(module[settings.before_compiling_sass] ?? () {}, []);
  });
  await (await settings.main_css.create(recursive: true)).writeAsString(sass
      .compileToResult(settings.main_scss.path,
          style: sass.OutputStyle.compressed)
      .css);
}

class HtmlDir {
  SplayTreeSet<HtmlDir> dirs = SplayTreeSet<HtmlDir>((HtmlDir a, HtmlDir b) =>
      p.normalize(a.path).compareTo(p.normalize(b.path)));
  SplayTreeSet<HtmlFile> files =
      SplayTreeSet<HtmlFile>((HtmlFile a, HtmlFile b) {
    RegExp num_start = RegExp(r'^[1-9][0-9]*');
    RegExpMatch? a_pre = num_start.firstMatch(a.id),
        b_pre = num_start.firstMatch(b.id);
    if (a_pre != null && b_pre != null && a_pre.group(0) != b_pre.group(0)) {
      return int.parse(a_pre.group(0)!).compareTo(int.parse(b_pre.group(0)!));
    }
    return a.id.compareTo(b.id);
  });
  DateTime lastmod = DateTime.fromMillisecondsSinceEpoch(0);
  String path;
  HtmlDir? parent;
  HtmlDir(this.path);
  void add_file(HtmlFile x) {
    if (p.isWithin(path, x.path)) {
      if (p.equals(path, x.directory)) {
        files.add(x);
      } else {
        String child_path = x.directory;
        while (!p.equals(path, p.dirname(child_path))) {
          child_path = p.dirname(child_path);
        }
        HtmlDir child_dir = HtmlDir(child_path);
        child_dir.parent = this;
        child_dir = dirs.lookup(child_dir) ?? child_dir;
        child_dir.add_file(x);
        dirs.add(child_dir);
      }
      if (x.lastmod.isAfter(lastmod)) {
        lastmod = x.lastmod;
      }
    }
  }

  String html() {
    List<Element> parts([dynamic c]) {
      List<Element> res = [];

      String type, title, href;
      DateTime? lastmod;

      if (c is HtmlFile) {
        type = 'file';
        title = c.title;
        href = p.basename(c.path);
        lastmod = c.lastmod;
      } else if (c is HtmlDir) {
        type = 'dir';
        title = href = p.basename(c.path) + '/';
        lastmod = c.lastmod;
      } else {
        type = 'dir';
        title = href = '../';
        if (parent != null) {
          lastmod = parent!.lastmod;
        }
      }
      res.add(Element.html(
          '<p><a href="${esc(href, inline: true, htmlesc: true)}" class="${esc(type, inline: true, htmlesc: true)}">${esc(title, inline: true, htmlesc: true)}</a></p>'));
      if (lastmod != null) {
        lastmod =
            lastmod.toUtc().add(Duration(microseconds: -lastmod.microsecond));
        res.add(Element.html(
            '<ul><li>更新日時: <time datetime="${lastmod.toIso8601String()}">${DateFormat('yyyy年MM月dd日 ahh時mm分', 'ja').format(lastmod.add(Duration(hours: 9)))}</time></li></ul>'));
      }
      return res;
    }

    Element content = Element.html('<div class="index"></div>');
    content.append(Element.tag('hr'));
    parts().forEach((Element e) {
      content.append(e);
    });
    dirs.forEach((HtmlDir dir) {
      parts(dir).forEach((Element e) {
        content.append(e);
      });
    });
    content.append(Element.tag('hr'));
    files.forEach((HtmlFile file) {
      parts(file).forEach((Element e) {
        content.append(e);
      });
    });

    return replace_template(settings.html_template, {
      'lang': 'ja',
      'title': '記事一覧',
      'description': esc('Index of /${path}/', inline: true, htmlesc: true),
      'header': '<h1>${esc('/${path}/', inline: true, htmlesc: true)}</h1>',
      'content': content.outerHtml
    });
  }
}

String footer_contact = '';

class HtmlFile {
  DateTime lastmod = DateTime.fromMillisecondsSinceEpoch(0);
  String id;
  String directory = '';
  String path = '';
  String html = '';
  String title = '';
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
      path = p.join(directory, "${id}.html");
    }

    String md = '';
    try {
      File main_md = File(p.join(dir.path, settings.html_main));
      md = main_md.readAsStringSync();
      int unix_time = int.parse(Process.runSync(
          settings.lastmod_out.absolute.path, [main_md.absolute.path]).stdout);
      lastmod = DateTime.fromMillisecondsSinceEpoch(unix_time * 1000);
    } finally {}

    Document src = Document.html(markdown.markdownToHtml(md,
        extensionSet: markdown.ExtensionSet.gitHubWeb));

    String lang = settings.default_lang;

    title = '${id}.html';
    try {
      title = src.getElementsByTagName('h1').first.text;
    } finally {}

    String description = '';
    try {
      description =
          File(p.join(dir.path, settings.html_description)).readAsStringSync();
    } finally {}

    String header = '';
    try {
      if (directory.isNotEmpty) {
        Element nav = Element.tag('nav');
        Element a = Element.tag('a');
        a.text = p.basename(directory) + '/';
        a.attributes = LinkedHashMap.from({'href': '.'});
        nav.append(a);
        header += nav.outerHtml;
      }
      header += '<h1>${esc(title, inline: true, htmlesc: true)}</h1>';
      if (settings.article_id.hasMatch(id)) {
        try {
          Element p = Element.tag('p'), time = Element.tag('time');
          p.id = 'lastmod';
          time.attributes = LinkedHashMap.from({
            'datetime': lastmod
                .toUtc()
                .add(Duration(microseconds: -lastmod.microsecond))
                .toIso8601String()
          });
          if (lang == 'ja') {
            time.text = DateFormat('yyyy年MM月dd日 ahh時mm分', 'ja')
                .format(lastmod.toUtc().add(Duration(hours: 9)));
          } else {
            time.text = DateFormat.yMMMd()
                .add_jm()
                .format(lastmod.toUtc().add(Duration(hours: 9)));
          }
          p.append(time);
          header += p.outerHtml;
        } finally {}
        try {
          List<List<Element>> toc = [[], [], [], [], [], [], []];
          int prev_level = -1;
          src
              .querySelectorAll('h1, h2, h3, h4, h5, h6')
              .reversed
              .forEach((Element heading) {
            int now_level = int.parse(heading.localName![1]);

            toc[now_level].add(Element.tag('li'));
            toc[now_level].last.text = heading.text;

            if (prev_level > now_level) {
              if (prev_level - now_level != 1) throw Exception();

              Element ol = Element.tag('ol');
              while (toc[prev_level].isNotEmpty) {
                ol.append(toc[prev_level].removeLast());
              }

              toc[now_level].last.append(ol);
            }

            prev_level = now_level;
          });
          if (toc[1].isNotEmpty && toc[1].first.children.isNotEmpty) {
            Element nav = Element.html('<nav id="toc"><h2>目次</h2></nav>');
            nav.append(toc[1].first.children.first);
            header += nav.outerHtml;
          }
        } finally {}
      }
    } finally {}

    String content = '';
    try {
      content = src.body!.innerHtml;
      src.getElementsByTagName('h1').forEach((Element h1) {
        content = content.replaceFirst(h1.outerHtml, '');
      });
    } finally {}

    String footer = '';
    if (settings.article_id.hasMatch(id)) {
      footer += '<hr>';
      footer += '<h2>更新履歴</h2>';
      String href = p.join(
          settings.github_url,
          'commits/main/',
          settings.articles.path.substring(settings.blog_root.path.length),
          id,
          settings.html_main);
      footer +=
          '<p><a href="${esc(href, inline: true, htmlesc: true)}">GitHub リポジトリ</a></p>';
      footer += '<hr>';
      footer += footer_contact;
    }
    html = replace_template(settings.html_template, {
      'lang': esc(lang, inline: true, htmlesc: true),
      'title': esc(title, inline: true, htmlesc: true),
      'description': esc(description, inline: true, htmlesc: true),
      'header': header,
      'content': content,
      'footer': footer
    });
    settings.modules.forEach((Map<String, Function> module) {
      html = Function.apply(
          module[settings.after_making_html] ?? (x) => x, [html]);
    });
  }
}

String esc(String str, {bool inline = false, bool htmlesc = false}) {
  if (inline) {
    str = str.replaceAll(RegExp(r'\r?\n'), '').trim();
  }
  if (htmlesc) {
    str = HtmlEscape().convert(str);
  }
  return str;
}

String replace_template(String template, Map<String, String> replacement) {
  return template.replaceAllMapped(RegExp(r'\$' + r'\{' + r'([^\}]+)' + r'\}'),
      (Match match) => replacement[match.group(1)] ?? '');
}

Future<void> put_html(HtmlDir dir) async {
  (await File(p.join(settings.document_root.path, dir.path, 'index.html'))
          .create(recursive: true))
      .writeAsStringSync(dir.html());

  dir.files.forEach((HtmlFile file) async {
    (await File(p.join(settings.document_root.path, file.path))
            .create(recursive: true))
        .writeAsString(file.html);
  });
  dir.dirs.forEach((HtmlDir next_dir) {
    put_html(next_dir);
  });
}

Future<void> main() async {
  await initializeDateFormatting('ja');

  compile_sass();

  Document contact = Document.html(markdown.markdownToHtml(
      File(p.join(settings.articles.path, settings.contact, settings.html_main))
          .readAsStringSync()));
  footer_contact = contact.body!.innerHtml;
  for (int i = 6; i >= 1; i--) {
    List<Element> from_s = contact.getElementsByTagName('h${i}');
    if (i == 6 && from_s.isNotEmpty) throw Exception();
    Element to = Element.tag('h${i + 1}');
    from_s.forEach((Element from) {
      to.innerHtml = from.innerHtml;
      footer_contact =
          footer_contact.replaceFirst(from.outerHtml, to.outerHtml);
    });
  }

  HtmlDir site_map = HtmlDir('');
  String id_redirect = '';
  await for (FileSystemEntity entity in settings.articles.list()) {
    if (entity is Directory) {
      HtmlFile file = HtmlFile(p.basename(entity.path));
      site_map.add_file(file);
      id_redirect += '\n';
      id_redirect += '''
        if (\$uri ~ ${RegExp.escape('/${p.basename(file.path)}')}\$) {
          return 301 /${file.path};
        }''';
    }
  }

  put_html(site_map);
  (await settings.config_out.create(recursive: true)).writeAsString(
      replace_template(settings.config_template, {'id_redirect': id_redirect}));
}
