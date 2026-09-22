/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'package:bluez_obex_native/bluez_obex_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_phone_message/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const connectedPhone = BlueZDevice(
    address: 'AA:BB:CC:DD:EE:FF',
    name: 'Test phone',
    connected: true,
    uuids: [
      '0000112f-0000-1000-8000-00805f9b34fb',
      '00001132-0000-1000-8000-00805f9b34fb',
    ],
  );

  test('unsupported capabilities do not block profile operations', () async {
    expect(await readOptionalCapabilities(() async => 'PBAP'), 'PBAP');
    for (final error in [
      const BlueZObexNativeException(
        'bluez_obex_session_get_capabilities',
        -1,
        name: 'org.bluez.obex.Error.NotSupported',
      ),
      const BlueZObexNativeException(
        'bluez_obex_session_get_capabilities',
        -1,
        name: 'org.bluez.obex.Error.Failed',
        message: 'Not Acceptable',
      ),
    ]) {
      expect(await readOptionalCapabilities(() async => throw error), isEmpty);
    }
    final error = const BlueZObexNativeException(
      'bluez_obex_session_get_capabilities',
      -1,
      name: 'org.bluez.obex.Error.Failed',
      message: 'Connection lost',
    );
    await expectLater(
      readOptionalCapabilities(() async => throw error),
      throwsA(same(error)),
    );
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      FlutterPhoneMessageApp(
        discoverDevices: () async => [
          connectedPhone,
          const BlueZDevice(address: '11:22:33:44:55:66', name: 'Offline'),
        ],
        createClient: (workspace) =>
            BlueZObexClient.simulated(outputDirectory: workspace),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> navigate(WidgetTester tester, String label) async {
    final navigation = find.byType(NavigationBar);
    expect(navigation, findsOneWidget);
    await tester.tap(
      find.descendant(of: navigation, matching: find.text(label)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tapAction(WidgetTester tester, String label) async {
    final labelFinder = find.text(label);
    if (labelFinder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        labelFinder,
        -300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    final action = find
        .ancestor(
          of: labelFinder,
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        )
        .first;
    await tester.ensureVisible(action);
    await tester.pump();
    await tester.tap(action);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('uses a light theme and shows only connected devices', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('OBEX Phone Studio'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.text('OBEX Phone Studio'))).brightness,
      Brightness.light,
    );
    expect(find.textContaining('Test phone'), findsWidgets);
    expect(find.textContaining('Offline'), findsNothing);
    expect(find.text('Simulated'), findsNothing);
    expect(find.text('Connect'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Choose a phone to explore'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('explains how to proceed when no device is connected', (
    tester,
  ) async {
    await tester.pumpWidget(
      FlutterPhoneMessageApp(discoverDevices: () async => const []),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No connected phone found'), findsOneWidget);
    expect(find.text('Refresh devices'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
    await navigate(tester, 'Contacts');
    expect(
      find.text('Choose a connected phone on Overview first.'),
      findsOneWidget,
    );
  });

  testWidgets('overview fits a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Choose a phone to explore'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(700, 375));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('PBAP search limits the field to BlueZ choices', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await navigate(tester, 'Contacts');

    await tester.tap(find.text('Name').first);
    await tester.pumpAndSettle();
    expect(find.text('Number'), findsOneWidget);
    expect(find.text('Sound'), findsOneWidget);
    await tester.tap(find.text('Number').last);
    await tester.pumpAndSettle();
    expect(find.text('Number'), findsOneWidget);
  });

  testWidgets('runs all PBAP controls and reports invalid vCards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await navigate(tester, 'Contacts');

    for (final label in [
      'Load phonebook details',
      'Select',
      'List',
      'Search',
      'Pull all',
      'Pull one',
      'Get size',
      'Update version',
      'Filter fields',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    await tapAction(tester, 'List');
    expect(find.text('Ada Lovelace'), findsOneWidget);
    await tapAction(tester, 'Load phonebook details');
    expect(find.text('SIMULATED-DB'), findsOneWidget);
    expect(find.text('2 entries'), findsWidgets);

    await tapAction(tester, 'Select');
    expect(find.text('int/pb'), findsOneWidget);
    await tapAction(tester, 'Get size');
    await tapAction(tester, 'Update version');
    await tapAction(tester, 'Filter fields');

    await tapAction(tester, 'List');
    await tester.scrollUntilVisible(
      find.text('Ada Lovelace'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsOneWidget);

    await navigate(tester, 'Overview');
    await navigate(tester, 'Contacts');
    await tapAction(tester, 'Search');
    await tester.scrollUntilVisible(
      find.text('Ada Lovelace'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Grace Hopper'), findsNothing);

    await navigate(tester, 'Overview');
    await navigate(tester, 'Contacts');
    await tapAction(tester, 'Pull all');
    await tapAction(tester, 'Pull one');
    await navigate(tester, 'Transfers');
    expect(find.text('Suspend'), findsWidgets);
    expect(find.text('Resume'), findsWidgets);
    expect(find.text('Cancel'), findsWidgets);
    await tapAction(tester, 'Suspend');
    expect(find.text('suspended'), findsWidgets);
    await tapAction(tester, 'Resume');
    expect(find.text('active'), findsWidgets);
    await tapAction(tester, 'Cancel');
    expect(find.text('cancelled'), findsWidgets);

    await navigate(tester, 'Contacts');
    final vcardField = find.widgetWithText(TextField, 'vCard handle');
    await tester.ensureVisible(vcardField);
    await tester.enterText(vcardField, 'missing.vcf');
    await tapAction(tester, 'Pull one');
    expect(find.textContaining('Pull one failed'), findsOneWidget);
  });

  testWidgets('runs MAP controls and renders every message metadata field', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await navigate(tester, 'Messages');

    for (final label in [
      'Load message details',
      'Set folder',
      'List folders',
      'List messages',
      'Update inbox',
      'Push message',
      'Filter fields',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    await tapAction(tester, 'Load message details');
    expect(find.textContaining('SMS_GSM'), findsOneWidget);

    await tapAction(tester, 'Set folder');
    await tapAction(tester, 'List folders');
    await tester.scrollUntilVisible(
      find.text('inbox'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('inbox'), findsOneWidget);

    await tapAction(tester, 'Update inbox');
    await tapAction(tester, 'Filter fields');
    await tapAction(tester, 'Push message');
    await tapAction(tester, 'List messages');
    await tester.scrollUntilVisible(
      find.text('Hello from simulated MAP').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hello from simulated MAP'), findsWidgets);

    for (final field in [
      'Sender address',
      'Reply-to',
      'Recipient address',
      'Attachment size',
      'Delivery status',
      'Conversation ID',
      'Conversation name',
      'Direction',
      'Attachment MIME types',
    ]) {
      await tester.scrollUntilVisible(
        find.text(field),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(field), findsOneWidget);
    }

    await tapAction(tester, 'Mark read');
    expect(find.text('Mark unread'), findsOneWidget);
    await tapAction(tester, 'Delete');
    expect(find.text('Restore'), findsOneWidget);
    await tapAction(tester, 'Restore');
    expect(find.text('Delete'), findsOneWidget);

    await tapAction(tester, 'Download');
    await tester.scrollUntilVisible(
      find.text('Pushed message'),
      -180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pushed message'), findsOneWidget);
  });

  testWidgets('cancels event ownership when the view is disposed', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
