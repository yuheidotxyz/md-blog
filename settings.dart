import 'dart:io';
import 'package:path/path.dart' as p;
import 'highlight.dart' as highlight;

final File lastmod_out = File('lastmod.out').absolute;

final String default_lang = 'ja';
final String contact = 'contact';
final String github_url = 'https://github.com/yuheidotxyz/my-blog/';

final Directory blog_root = Directory('data/').absolute;
final Directory articles = Directory('data/articles/').absolute;
final File main_scss = File('data/main.scss').absolute;
final String html_template = File('data/template.html').readAsStringSync();
final String html_main = "main.md";
final String html_description = "description.txt";
final String html_directory = "directory.txt";
final Directory document_root = Directory('html/').absolute;
final File main_css = File(p.join(document_root.path, 'main.css')).absolute;

final RegExp article_id = RegExp(r'^[0-9]+$');

final List<Map<String, Function>> modules = [highlight.module];
final File modules_scss = File('data/_code.scss').absolute;
final String before_compiling_sass = 'before_compiling_sass';
final String after_making_html = 'after_making_html';

final File highlight_theme = File('data/highlight.theme').absolute;
final String highlight_class = 'h';
final String highlight_filename_class = 'hf';
