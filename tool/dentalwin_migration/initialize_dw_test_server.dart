import 'dart:io';

import 'package:apexo/utils/init_pocketbase.dart';
import 'package:pocketbase/pocketbase.dart';

Never _usage() => throw ArgumentError(
      'Usage: dart run initialize_dw_test_server.dart '
      '<http://127.0.0.1:port> <superuser-email> <password-file>',
    );

Future<void> main(List<String> args) async {
  if (args.length != 3) _usage();

  final server = Uri.parse(args[0]);
  if (server.scheme != 'http' ||
      server.host != '127.0.0.1' ||
      !server.hasPort ||
      (server.path.isNotEmpty && server.path != '/')) {
    throw StateError(
      'Safety lock: Phase 4 initialization accepts only an explicit '
      'http://127.0.0.1:<port> server root.',
    );
  }

  final passwordFile = File(args[2]);
  if (!passwordFile.existsSync()) {
    throw StateError('The separate test-server password file was not found.');
  }
  final storedSecret = passwordFile.readAsStringSync().trim();
  if (storedSecret.length < 16) {
    throw StateError('The test-server password file is invalid.');
  }
  final password = storedSecret.substring(
    0,
    storedSecret.length > 64 ? 64 : storedSecret.length,
  );

  final pb = PocketBase(server.toString());
  await pb.collection('_superusers').authWithPassword(args[1], password);

  var existingRows = 0;
  try {
    existingRows = (await pb.collection('data').getList(perPage: 1)).totalItems;
  } on ClientException catch (error) {
    if (error.statusCode != 404) rethrow;
  }
  if (existingRows != 0) {
    throw StateError(
      'Safety lock: the test server already contains data records.',
    );
  }

  await initializePocketbase(pb);
  final after = await pb.collection('data').getList(perPage: 1);
  if (after.totalItems != 0) {
    throw StateError('Test-server initialization produced unexpected rows.');
  }

  stdout.writeln('Isolated Apexo test schema initialized.');
  stdout.writeln('Data rows: 0');
  stdout.writeln('Server host: 127.0.0.1');
}
