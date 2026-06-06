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
        '  --simulated  Use the simulated OBEX endpoint instead of a physical device',
      ],
    );
    return;
  }

  final address = args.where((arg) => !arg.startsWith('-')).firstOrNull ?? kDefaultAddress;
  final simulated = hasFlag(args, '--simulated');

  print('Connecting to $address (simulated: $simulated)...');
  final client = await createClient(simulated: simulated);

  try {
    print('Creating session for target "pbap"...');
    final session = await client.createSession(address, target: 'pbap');
    print('Session created: ${session.objectPath}');

    print('Selecting telecom/pb phonebook...');
    await session.phonebook.select('telecom', 'pb');

    final size = await session.phonebook.getSize();
    print('Phonebook size: $size');

    print('Listing entries (max 50)...');
    final entries = await session.phonebook.list(filters: {'MaxCount': 50});
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
