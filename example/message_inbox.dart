// ignore_for_file: avoid_print

import 'dart:io';

import 'obex_example_utils.dart';

Future<void> main(List<String> args) async {
  if (hasFlag(args, '--help') || hasFlag(args, '-h')) {
    printUsage(
      'dart run example/message_inbox.dart [address] [action] [messagePath]',
      [
        'Connects to a Bluetooth device, creates a MAP session, and lists or downloads messages.',
        '',
        'Actions:',
        '  list                     List all messages in the inbox (default)',
        '  download <message_path>  Download a specific message to message.bmsg',
        '',
        '  address    The Bluetooth address (e.g. AA:BB:CC:DD:EE:FF)',
        '  --simulated  Use the simulated OBEX endpoint',
      ],
    );
    return;
  }

  final positionalArgs = args.where((arg) => !arg.startsWith('-')).toList();
  final address = positionalArgs.isNotEmpty
      ? positionalArgs[0]
      : kDefaultAddress;
  final action = positionalArgs.length > 1 ? positionalArgs[1] : 'list';
  final messagePath = positionalArgs.length > 2 ? positionalArgs[2] : null;
  final simulated = hasFlag(args, '--simulated');

  print('Connecting to $address (simulated: $simulated)...');
  final client = await createClient(simulated: simulated);

  try {
    print('Creating session for target "map"...');
    // PBAP is target: 'pbap', MAP is target: 'map'
    final session = await client.createSession(address, target: 'map');
    print('Session created: ${session.objectPath}');

    if (action == 'list') {
      print('Listing messages...');
      final messages = await session.messageAccess.listMessages(
        'telecom/msg/inbox',
        filters: {'MaxCount': 50, 'SubjectLength': 120},
      );
      if (messages.isEmpty) {
        print('  (No messages)');
      }
      for (final message in messages) {
        final props = message.lastProperties;
        print(
          '  ${message.objectPath}: ${props?.subject ?? "(No Subject)"} from ${props?.sender ?? "(Unknown)"}',
        );
      }
    } else if (action == 'download') {
      if (messagePath == null) {
        print('Error: Missing message path to download.');
        return;
      }
      final message = client.message(messagePath);
      final targetFile = 'message.bmsg';
      print('Downloading message to $targetFile...');
      final transfer = await message.get(targetFile, attachment: false);
      print('Transfer started: ${transfer.transferPath}');

      print('Marking as read...');
      await message.setRead(true);

      if (File(targetFile).existsSync()) {
        print('Message downloaded to $targetFile');
      }
    } else {
      print('Unknown action: $action');
    }
  } finally {
    print('Closing client...');
    await client.dispose();
  }
}
