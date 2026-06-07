// ignore_for_file: avoid_print

import 'dart:io';

import 'obex_example_utils.dart';

Future<void> main(List<String> args) async {
  if (hasFlag(args, '--help') || hasFlag(args, '-h')) {
    printUsage(
      'dart run example/phonebook_sync.dart [address]',
      [
        'Connects to a Bluetooth device, creates a PBAP session, and downloads contacts to contacts.vcf.',
        '',
        '  address    The Bluetooth address (e.g. AA:BB:CC:DD:EE:FF)',
        '  --limit <number>  Max number of contacts to fetch (default: 10)',
      ],
    );
    return;
  }

  final limitStr = hasFlag(args, '--limit') ? optionValue(args, '--limit') : '10';
  final limit = int.tryParse(limitStr) ?? 10;

  final positionalArgs = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('-')) {
      if (arg == '--limit' && i + 1 < args.length) {
        i++;
      }
      continue;
    }
    positionalArgs.add(arg);
  }

  final address = positionalArgs.firstOrNull ?? kDefaultAddress;

  print('Connecting to $address...');
  final client = await createClient();

  try {
    print('Creating session for target "pbap"...');
    final session = await client.createSession(address, target: 'pbap');
    print('Session created: ${session.objectPath}');

    print('Selecting int/pb phonebook...');
    await session.phonebook.select('int', 'pb');

    final size = await session.phonebook.getSize();
    print('Phonebook size: $size');

    print('Listing entries (max $limit)...');
    final entries = await session.phonebook.list(filters: {'MaxCount': limit});
    for (final entry in entries) {
      print('  ${entry.name}');
    }

    final targetFile = 'contacts.vcf';
    print('Pulling all contacts to $targetFile...');
    final transfer = await session.phonebook.pullAll(targetFile);
    print('Transfer started: ${transfer.transferPath}');

    // Basic file existence check
    if (File(targetFile).existsSync()) {
      print('Contacts downloaded to $targetFile');
    }
  } finally {
    print('Closing client...');
    await client.dispose();
  }
}
