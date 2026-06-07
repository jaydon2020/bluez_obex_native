import 'package:flutter/material.dart';
import 'package:flutter_phone_message/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows phone message controls', (tester) async {
    await tester.pumpWidget(const FlutterPhoneMessageApp());

    expect(find.text('Phone Message'), findsWidgets);
    expect(find.text('Simulated endpoint'), findsOneWidget);
    expect(find.byIcon(Icons.contacts), findsOneWidget);
    expect(find.byIcon(Icons.inbox), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
  });
}
