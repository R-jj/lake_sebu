import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'root_shell.dart';
import 'providers/menu_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/user_profile_provider.dart';
import 'providers/orders_provider.dart';
import 'providers/owner_orders_provider.dart';
import 'providers/owner_menu_provider.dart';
import 'pages/sign_in_page.dart';
import 'pages/profile_completion_gate.dart';
import 'pages/owner/owner_root_shell.dart';
import 'services/owner_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await OwnerNotificationService.instance.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => MenuProvider()),
        // UserProfileProvider depends on AppAuthProvider — use
        // ChangeNotifierProxyProvider so it receives the auth instance
        // and can react to uid changes.
        ChangeNotifierProxyProvider<AppAuthProvider, UserProfileProvider>(
          create: (ctx) => UserProfileProvider(
            ctx.read<AppAuthProvider>(),
          ),
          update: (ctx, auth, previous) {
            final provider = previous ?? UserProfileProvider(auth);
            // React to auth state changes: init streams on sign-in,
            // clear on sign-out.
            if (auth.isAuthenticated && auth.user?.uid != null) {
              // Only call init when the uid actually changes (or streams have
              // never been started yet) to avoid tearing down live Firestore
              // subscriptions on every AppAuthProvider.notifyListeners call
              // (e.g. markProfileComplete, token refresh, loading-state flips).
              final uid = auth.user!.uid;
              if (provider.initializedUid != uid) {
                // Schedule async work outside the build phase.
                Future.microtask(() => provider.init(uid));
              }
            } else if (!auth.isAuthenticated) {
              Future.microtask(() => provider.clear());
            }
            return provider;
          },
        ),
        // OrdersProvider mirrors the same lifecycle as UserProfileProvider:
        // auto-inits on sign-in and clears on sign-out.
        ChangeNotifierProxyProvider<AppAuthProvider, OrdersProvider>(
          create: (_) => OrdersProvider(),
          update: (ctx, auth, previous) {
            final provider = previous ?? OrdersProvider();
            if (auth.isAuthenticated && auth.user?.uid != null) {
              final uid = auth.user!.uid;
              if (provider.initializedUid != uid) {
                Future.microtask(() => provider.init(uid));
              }
            } else if (!auth.isAuthenticated) {
              Future.microtask(() => provider.clear());
            }
            return provider;
          },
        ),
        // OwnerOrdersProvider: only active for restaurant_owner accounts.
        // Initialises with the restaurantId stored in the owner's profile.
        ChangeNotifierProxyProvider<AppAuthProvider, OwnerOrdersProvider>(
          create: (_) => OwnerOrdersProvider(),
          update: (ctx, auth, previous) {
            final provider = previous ?? OwnerOrdersProvider();
            if (auth.isAuthenticated &&
                auth.isRestaurantOwner &&
                auth.restaurantId != null) {
              final rid = auth.restaurantId!;
              if (provider.initializedRestaurantId != rid) {
                Future.microtask(() => provider.init(rid));
              }
            } else if (!auth.isAuthenticated) {
              Future.microtask(() => provider.clear());
            }
            return provider;
          },
        ),
        // OwnerMenuProvider: real-time menu stream for restaurant owners.
        // Same lifecycle as OwnerOrdersProvider — init on sign-in, clear on
        // sign-out, keyed by restaurantId so re-login to a different account
        // resets the stream.
        ChangeNotifierProxyProvider<AppAuthProvider, OwnerMenuProvider>(
          create: (_) => OwnerMenuProvider(),
          update: (ctx, auth, previous) {
            final provider = previous ?? OwnerMenuProvider();
            if (auth.isAuthenticated &&
                auth.isRestaurantOwner &&
                auth.restaurantId != null) {
              final rid = auth.restaurantId!;
              if (provider.initializedRestaurantId != rid) {
                Future.microtask(() => provider.init(rid));
              }
            } else if (!auth.isAuthenticated) {
              Future.microtask(() => provider.clear());
            }
            return provider;
          },
        ),
      ],
      child: const SwiftBiteApp(),
    ),
  );
}

class SwiftBiteApp extends StatelessWidget {
  const SwiftBiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SwiftBite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kCanvas,
        textTheme: appTextTheme(),
        colorScheme: const ColorScheme.dark(
          primary: kBrand,
          surface: kSurface,
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Listens to [AppAuthProvider] and routes to the correct screen:
///
///   unknown          → SplashScreen (Firebase resolving persisted auth)
///   unauthenticated  → SignInPage
///   authenticated
///     profileLoaded = false       → SplashScreen (loading Firestore profile)
///     role = restaurant_owner     → OwnerRootShell
///     isProfileComplete = false   → ProfileCompletionGate  (customers only)
///     isProfileComplete = true    → RootShell              (customers)
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();

    switch (auth.status) {
      case AuthStatus.unknown:
        return const _SplashScreen();

      case AuthStatus.unauthenticated:
        return const SignInPage();

      case AuthStatus.authenticated:
        // Wait for the Firestore profile check to finish.
        if (!auth.profileLoaded) {
          return const _SplashScreen();
        }

        // Restaurant owners bypass the profile completion gate and go
        // directly to their own operational shell.
        if (auth.isRestaurantOwner) {
          // Guard: an owner account with no restaurantId is misconfigured.
          if (auth.restaurantId == null || auth.restaurantId!.isEmpty) {
            return _MisconfiguredOwnerScreen(uid: auth.user?.uid ?? '');
          }
          return const OwnerRootShell();
        }

        // Customer path — unchanged from before.
        if (!auth.isProfileComplete) {
          return const ProfileCompletionGate();
        }
        return const RootShell();
    }
  }
}

/// Minimal full-screen splash shown while Firebase resolves the persisted
/// auth state, and again while the Firestore profile is being loaded.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCanvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: kBrand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBrand.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.bolt_rounded, color: kBrand, size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              'SwiftBite',
              style: kSerif.copyWith(
                color: kInk,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: kBrand,
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when an account has role=restaurant_owner but no restaurantId set.
/// This is an admin configuration error — display a clear message and
/// provide a sign-out button so the user is not permanently stuck.
class _MisconfiguredOwnerScreen extends StatelessWidget {
  final String uid;
  const _MisconfiguredOwnerScreen({required this.uid});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AppAuthProvider>();
    return Scaffold(
      backgroundColor: kCanvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: kGold, size: 48),
              const SizedBox(height: 16),
              Text(
                'Account Setup Incomplete',
                style: kSerif.copyWith(
                  color: kInk,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your restaurant-owner account is missing a restaurant '
                'assignment. Please contact the administrator.\n\nUID: $uid',
                style: const TextStyle(color: kMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrand,
                    foregroundColor: kInk,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => auth.signOut(),
                  child: const Text('Sign Out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
