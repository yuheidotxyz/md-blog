import 'dart:io';
import 'package:path/path.dart' as p;

final Directory articles = Directory('data/articles').absolute;
final File highlight_theme = File('data/highlight.theme').absolute;
final File main_scss = File('data/main.scss').absolute;

final Directory document_root = Directory('html').absolute;
final File highlight_scss = File('data/_code.scss').absolute;
final File main_css = File(p.join(document_root.path, 'main.css')).absolute;
