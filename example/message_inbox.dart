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
        '  --limit <number>  Max number of messages to fetch (default: all)',
      ],
    );
    return;
  }

  final limitStr = hasFlag(args, '--limit') ? optionValue(args, '--limit') : null;
  final limit = limitStr != null ? int.tryParse(limitStr) : null;

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

  final address = positionalArgs.isNotEmpty
      ? positionalArgs[0]
      : kDefaultAddress;
  final action = positionalArgs.length > 1 ? positionalArgs[1] : 'list';
  final messagePath = positionalArgs.length > 2 ? positionalArgs[2] : null;

  print('Connecting to $address...');
  final client = await createClient();

  try {
    print('Creating session for target "map"...');
    // PBAP is target: 'pbap', MAP is target: 'map'
    final session = await client.createSession(address, target: 'map');
    print('Session created: ${session.objectPath}');

    if (action == 'list') {
      print('Listing messages...');
      final filters = <String, dynamic>{'SubjectLength': 120};
      if (limit != null) {
        filters['MaxCount'] = limit;
      }
      final messages = await session.messageAccess.listMessages(
        'telecom/msg/inbox',
        filters: filters,
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
      // Message paths are session-scoped: /org/bluez/obex/client/sessionN/messageHANDLE
      // The session number changes each run, so we resolve the handle against the
      // current session by listing messages and matching by the final path segment
      // (the MAP message handle, which is stable across sessions for the same device).
      final requestedHandle = messagePath.split('/').last;
      print('Resolving message handle "$requestedHandle" in current session...');
      final allMessages = await session.messageAccess.listMessages(
        'telecom/msg/inbox',
        filters: {},
      );
      final matched = allMessages.where(
        (m) => m.objectPath.split('/').last == requestedHandle ||
               m.objectPath == messagePath,
      );
      if (matched.isEmpty) {
        print('Error: Message "$requestedHandle" not found in inbox.');
        print('Tip: Run with action "list" to see available message paths.');
        return;
      }
      final message = matched.first;
      print('Found message at: ${message.objectPath}');
      final targetFile = 'message.bmsg';
      final absoluteTargetFile = File(targetFile).absolute.path;
      print('Downloading message to $absoluteTargetFile...');
      final transfer = await message.get(absoluteTargetFile, attachment: false);
      print('Transfer started: ${transfer.transferPath}');

      print('Marking as read...');
      await message.setRead(true);

      if (File(targetFile).existsSync()) {
        print('Message downloaded to $absoluteTargetFile');
      } else {
        print('Transfer complete. Note: If the file is not in the current directory, check the BlueZ OBEX daemon path.');
      }
    } else {
      print('Unknown action: $action');
    }
  } finally {
    print('Closing client...');
    await client.dispose();
  }
}
