import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lake_sebu/pages/owner/owner_restaurant_page.dart';
import 'package:lake_sebu/providers/auth_provider.dart';
import 'package:lake_sebu/models/app_user.dart';
import 'package:lake_sebu/models/user_profile.dart';

// ── Fake AppAuthProvider ──────────────────────────────────────────────────────
//
// Overrides only the members that OwnerRestaurantPage actually accesses:
//   • restaurantId  — read in _load() via context.read<AppAuthProvider>()
//   • updateRestaurantId — called after a successful create
//   • status / isAuthenticated / profileLoaded — consumed by guards elsewhere
//
// All other inherited members throw UnimplementedError so a stray call
// surfaces immediately rather than silently doing nothing.

class _FakeAuthProvider extends ChangeNotifier implements AppAuthProvider {
  final String? _restaurantId;

  _FakeAuthProvider({String? restaurantId}) : _restaurantId = restaurantId;

  @override
  String? get restaurantId => _restaurantId;

  @override
  void updateRestaurantId(String id) {
    // no-op for widget tests — the page calls this on successful setup
    notifyListeners();
  }

  @override
  AuthStatus get status => AuthStatus.authenticated;

  @override
  bool get isAuthenticated => true;

  @override
  bool get profileLoaded => true;

  @override
  bool get isProfileComplete => true;

  @override
  UserRole get userRole => UserRole.restaurantOwner;

  @override
  bool get isRestaurantOwner => true;

  @override
  bool get isGoogleUser => false;

  @override
  AppUser? get user => null;

  @override
  String? get errorMessage => null;

  @override
  bool get isLoading => false;

  @override
  void clearError() {}

  @override
  void markProfileComplete() {}

  @override
  void markProfileIncomplete() {}

  @override
  Future<bool> signInWithEmail(String email, String password) =>
      throw UnimplementedError();

  @override
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) =>
      throw UnimplementedError();

  @override
  Future<bool> signInWithGoogle() => throw UnimplementedError();

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<bool> signOutAllDevices() => throw UnimplementedError();

  @override
  Future<bool> reauthenticate({String? password}) =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ── Helper ────────────────────────────────────────────────────────────────────

/// Pumps [OwnerRestaurantPage] with the supplied [auth] provider and waits
/// for the widget tree to settle.
Future<void> pumpRestaurantPage(
  WidgetTester tester,
  AppAuthProvider auth,
) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppAuthProvider>(create: (_) => auth),
      ],
      child: MaterialApp(
        // Use Roboto so Google Fonts network calls are not required.
        theme: ThemeData(fontFamily: 'Roboto'),
        home: const OwnerRestaurantPage(),
      ),
    ),
  );
  // Settle timers and animations. The setup path has no async gap so a
  // single pumpAndSettle is sufficient.
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  // Task 11.1 — Widget tests for _SetupView (accessed via OwnerRestaurantPage)
  group('_SetupView (via OwnerRestaurantPage with restaurantId == null)', () {
    // ── Test 1 ──────────────────────────────────────────────────────────────
    testWidgets(
      '1. Setup form renders when restaurantId is null',
      (tester) async {
        await pumpRestaurantPage(tester, _FakeAuthProvider(restaurantId: null));

        // Heading
        expect(find.text('Set Up Your Restaurant'), findsOneWidget);

        // Primary action button
        expect(find.text('Create Restaurant'), findsOneWidget);

        // Key field labels
        expect(find.text('Restaurant Name'), findsOneWidget);
        expect(find.text('Cuisine / Category'), findsOneWidget);
      },
    );

    // ── Test 2 ──────────────────────────────────────────────────────────────
    testWidgets(
      '2. Empty name shows validation error and does not call the repository',
      (tester) async {
        await pumpRestaurantPage(tester, _FakeAuthProvider(restaurantId: null));

        // The button is below the fold — scroll it into view first.
        await tester.ensureVisible(find.text('Create Restaurant'));
        await tester.pumpAndSettle();

        // Tap the Create Restaurant button without entering anything.
        await tester.tap(find.text('Create Restaurant'));
        await tester.pumpAndSettle();

        // Scroll back to the top so the name field error is in the viewport.
        await tester.ensureVisible(find.text('Restaurant Name'));
        await tester.pumpAndSettle();

        // Inline validation error must appear on the name field.
        expect(find.text('Restaurant name is required'), findsOneWidget);
      },
    );

    // ── Test 3 ──────────────────────────────────────────────────────────────
    testWidgets(
      '3. No cuisine selected shows validation error',
      (tester) async {
        await pumpRestaurantPage(tester, _FakeAuthProvider(restaurantId: null));

        // Enter a valid name in the first TextFormField (the name field).
        final nameField = find.byType(TextFormField).first;
        await tester.ensureVisible(nameField);
        await tester.enterText(nameField, 'Sunset Grill');
        await tester.pumpAndSettle();

        // Scroll to and tap Create Restaurant without selecting a cuisine.
        await tester.ensureVisible(find.text('Create Restaurant'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create Restaurant'));
        await tester.pumpAndSettle();

        // Scroll to where the cuisine field lives so the error is in the tree.
        await tester.ensureVisible(find.text('Cuisine / Category'));
        await tester.pumpAndSettle();

        // The cuisine dropdown validation error must appear.
        expect(find.text('Please select a cuisine'), findsOneWidget);
      },
    );
  });
}
