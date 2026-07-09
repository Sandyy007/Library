import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:library_management_app/widgets/common_widgets.dart';
import 'package:library_management_app/widgets/gradient_button.dart';

import '../support/harness.dart';

void main() {
  setUpAll(disableGoogleFontsFetching);

  testWidgets('renders icon, title and subtitle', (tester) async {
    await tester.pumpWidget(wrapApp(
      const EmptyStateWidget(
        icon: Icons.inbox_rounded,
        title: 'Nothing here',
        subtitle: 'Add your first item to get started.',
      ),
      center: false,
    ));
    await tester.pump(); // start the bounce animation

    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Add your first item to get started.'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
  });

  testWidgets('shows a gradient CTA that fires onAction', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrapApp(
      EmptyStateWidget(
        icon: Icons.menu_book_outlined,
        title: 'No books yet',
        subtitle: 'Add one to begin.',
        actionLabel: 'Add a book',
        onAction: () => tapped = true,
      ),
      center: false,
    ));
    await tester.pump();

    expect(find.byType(GradientButton), findsOneWidget);
    await tester.tap(find.text('Add a book'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('hides the action button when no callback is given',
      (tester) async {
    await tester.pumpWidget(wrapApp(
      const EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle: 'Try a different search.',
      ),
      center: false,
    ));
    await tester.pump();
    expect(find.byType(GradientButton), findsNothing);
  });
}
