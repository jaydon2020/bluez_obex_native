import 'package:flutter/material.dart';

import 'package:bluez_obex_native/bluez_obex_native.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<BlueZObexManagedObjects> objects;
  BlueZObexClient? client;

  @override
  void initState() {
    super.initState();
    objects = _loadObjects();
  }

  Future<BlueZObexManagedObjects> _loadObjects() async {
    final connected = await BlueZObexClient.connect();
    client = connected;
    return connected.getManagedObjects();
  }

  @override
  void dispose() {
    client?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(fontSize: 25);
    const spacerSmall = SizedBox(height: 10);
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('BlueZ OBEX Native')),
        body: SingleChildScrollView(
          child: Container(
            padding: const .all(10),
            child: Column(
              children: [
                const Text(
                  'BlueZ OBEX objects discovered through the native FFI bridge.',
                  style: textStyle,
                  textAlign: .center,
                ),
                spacerSmall,
                FutureBuilder<BlueZObexManagedObjects>(
                  future: objects,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        '${snapshot.error}',
                        style: textStyle,
                        textAlign: .center,
                      );
                    }
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final data = snapshot.data!;
                    return Text(
                      'Sessions: ${data.sessions.length}\n'
                      'Transfers: ${data.transfers.length}\n'
                      'Phonebooks: ${data.phonebooks.length}\n'
                      'Message stores: ${data.messageAccesses.length}\n'
                      'Messages: ${data.messages.length}',
                      style: textStyle,
                      textAlign: .center,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
