import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unic_tunnel_app/core/unic_link.dart';
import 'package:unic_tunnel_app/ui/home_screen.dart';

Widget _harness() => const MaterialApp(
      home: HomeScreen(singboxBinaryPath: '/nonexistent/sing-box'),
    );

void main() {
  testWidgets('Home shows paste screen on first launch', (tester) async {
    await tester.pumpWidget(_harness());
    expect(find.text('Paste your unic:// link'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Pasting a valid link transitions to the connect screen',
      (tester) async {
    await tester.pumpWidget(_harness());

    final link = buildUnicLink(const UnicPayload(
      name: 'test-server',
      host: '1.2.3.4',
      port: 2222,
      user: 'u_xxxxxxxx',
      password: 'secret',
    ));
    await tester.enterText(find.byType(TextField), link);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('test-server'), findsOneWidget);
    expect(find.text('1.2.•.•'), findsOneWidget); // masked host
    expect(find.text('ON'), findsOneWidget);
    expect(find.text('Disconnected'), findsOneWidget);
  });

  testWidgets('Pasting an invalid link shows an error', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.enterText(find.byType(TextField), 'not-a-unic-link');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.textContaining('not a unic'), findsOneWidget);
    expect(find.text('Paste your unic:// link'), findsOneWidget);
  });

  testWidgets('Forget link returns to the paste screen', (tester) async {
    await tester.pumpWidget(_harness());

    final link = buildUnicLink(const UnicPayload(
      name: 'temp',
      host: '5.6.7.8',
      port: 22,
      user: 'u_t',
      password: 'p',
    ));
    await tester.enterText(find.byType(TextField), link);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('temp'), findsOneWidget);

    await tester.tap(find.text('Forget this link'));
    await tester.pumpAndSettle();

    expect(find.text('Paste your unic:// link'), findsOneWidget);
  });
}
