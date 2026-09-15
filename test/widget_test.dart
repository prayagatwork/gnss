import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skytrack_gnss_explorer/main.dart';

void main() {
  testWidgets('App loads and shows dashboard test',
      (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    // Since we use Riverpod, we MUST wrap SkyTrackApp in a ProviderScope here.
    await tester.pumpWidget(
      const ProviderScope(
        child: SkyTrackApp(),
      ),
    );

    // 2. Verify that the App Bar title is displayed correctly.
    expect(find.text('SkyTrack GNSS Explorer'), findsWidgets);

    // 3. Verify that the Dashboard cards are present.
    // We check for 'Latitude' because it is a core part of your updated UI.
    expect(find.text('Latitude'), findsOneWidget);
    expect(find.text('Longitude'), findsOneWidget);

    // 4. Verify that the Action Buttons are present.
    expect(find.text('Start Path'), findsOneWidget);
    expect(find.text('Share Location'), findsOneWidget);
  });
}
