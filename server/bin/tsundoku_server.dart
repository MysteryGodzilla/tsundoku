/// tsundoku_server serve [--db tsundoku.db] [--host 127.0.0.1] [--port 8797]
library;

import 'dart:io';

import 'package:shelf/shelf_io.dart' as io;
import 'package:tsundoku_server/tsundoku_server.dart';

Future<void> main(List<String> args) async {
  String opt(String name, String fallback) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? args[i + 1] : fallback;
  }

  if (args.isEmpty || args.first != 'serve') {
    stderr.writeln('Usage: tsundoku_server serve [--db tsundoku.db] [--host 127.0.0.1] [--port 8797]');
    exit(64);
  }
  final store = Store.open(opt('db', 'tsundoku.db'));
  final api = TsundokuApi(store);
  final server = await io.serve(api.handler, opt('host', '127.0.0.1'), int.parse(opt('port', '8797')));
  stdout.writeln('Tsundoku server $serverVersion on http://${server.address.host}:${server.port}');
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    store.close();
    exit(0);
  });
}
