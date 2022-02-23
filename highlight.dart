import 'dart:io';
import 'package:html/dom.dart' show Element, Document;
import 'settings.dart' as settings;

List<String> arguments_common = [
  '--config-file',
  settings.highlight_theme.path,
  '--class-name',
  settings.highlight_class,
  '--tab=2',
  '--out-format=html',
  '--enclose-pre',
  '--fragment',
  '--stdout',
  '--force'
];
Map<String, Function> module = {
  settings.before_compiling_sass: () async {
    (await settings.modules_scss.create(recursive: true)).writeAsString(
        '\n' +
            ((await Process.run(
                    'highlight', arguments_common + ['--print-style']))
                .stdout
                .toString()
                .replaceAll(RegExp(r'background-color' + r'[^;]*' + r';'), '')
                .replaceAll(RegExp(r'font-size' + r'[^;]*' + r';'), '')
                .replaceAll(RegExp(r'font-family' + r'[^;]*' + r';'), '')
                .replaceAll(
                    RegExp(r'[^{;]*' + r'#654321' + r'[^;]*' + r';'), '')) +
            '''
            span.${settings.highlight_class}.${settings.highlight_filename_class} {
                color: white;
                background-color: black;
            }
            pre.${settings.highlight_class} {
                margin: 0;
                display: inline-block;
                padding: 0.3em;
                border: {
                    style: solid;
                }
            }
            .${settings.highlight_class} {
                font-weight: bolder;
            }''',
        mode: FileMode.append);
  },
  settings.after_making_html: (String html) {
    Document src = Document.html(html);
    src.getElementsByTagName('pre').forEach((Element pre) {
      if (pre.children.isEmpty) return;
      Element code = pre.children.first;
      if (code.localName == null || code.localName!.toLowerCase() != 'code')
        return;
      String? type, filename;
      code.classes.forEach((String c) {
        RegExpMatch? x = RegExp(r'^language-([^:]+):(.+)$').firstMatch(c) ??
            RegExp(r'^language-([^:]+)$').firstMatch(c);
        if (x != null) {
          type = filename = null;
          if (x.groupCount >= 1) {
            type = x.group(1);
          }
          if (x.groupCount >= 2) {
            filename = x.group(2);
          }
        }
      });
      if (type == null) return;
      Element div = Element.tag('div');
      if (filename != null) {
        Element span = Element.tag('span');
        span.className =
            '${settings.highlight_class} ${settings.highlight_filename_class}';
        span.text = filename;
        div.append(span);
        div.append(Element.tag('br'));
      }
      File tmp = File(Process.runSync('mktemp', []).stdout.toString().trim());
      tmp.writeAsStringSync(code.text);
      div.append(Element.html(Process.runSync('highlight',
              arguments_common + ['--syntax', type!, tmp.absolute.path])
          .stdout));
      html = html.replaceFirst(pre.outerHtml, div.innerHtml);
    });
    return html;
  }
};
