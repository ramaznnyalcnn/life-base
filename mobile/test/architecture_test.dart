import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Modules are independent "apps": they share `core/` but never import each
/// other. Cross-module navigation goes through route paths.
void main() {
  test('modules do not import one another', () {
    final modules = Directory('lib/modules').listSync().whereType<Directory>().map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last);
    final violations = <String>[];
    for (final module in modules) {
      final files = Directory('lib/modules/$module').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
      for (final file in files) {
        for (final line in file.readAsLinesSync().where((l) => l.startsWith('import '))) {
          final match = RegExp(r'modules/(\w+)/').firstMatch(line) ?? RegExp(r"'\.\./\.\./(\w+)/").firstMatch(line);
          if (match != null && match.group(1) != module) violations.add('${file.path}: $line');
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('core does not depend on modules or the shell', () {
    final files = Directory('lib/core').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
    final violations = [
      for (final file in files)
        for (final line in file.readAsLinesSync())
          if (line.startsWith('import ') && (line.contains('modules/') || line.contains('shell/'))) '${file.path}: $line',
    ];
    expect(violations, isEmpty);
  });
}
