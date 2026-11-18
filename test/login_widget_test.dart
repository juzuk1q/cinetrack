import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinetrack/screens/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen renders username and password fields and submit button', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    await tester.pump();

    // Verify form fields
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Войти в аккаунт'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsWidgets);
  });
}
