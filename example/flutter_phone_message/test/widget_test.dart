/*
 * Copyright (c) 2026 Jian De jiande2020@gmail.com. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'package:flutter/material.dart';
import 'package:flutter_phone_message/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const FlutterPhoneMessageApp());
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

  testWidgets('uses responsive navigation and shows endpoint state', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('OBEX Phone Studio'), findsOneWidget);
    expect(find.text('Simulated endpoint'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Phone data, without hidden state'), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(1200, 900));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('runs all PBAP controls and reports invalid vCards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await navigate(tester, 'Contacts');

    for (final label in [
      'Open PBAP',
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

    await tapAction(tester, 'Open PBAP');
    expect(find.text('SIMULATED-DB'), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);

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
      'Open MAP',
      'Set folder',
      'List folders',
      'List messages',
      'Update inbox',
      'Push message',
      'Filter fields',
    ]) {
      expect(find.text(label), findsWidgets);
    }

    await tapAction(tester, 'Open MAP');
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
    await tapAction(tester, 'Connect');
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
