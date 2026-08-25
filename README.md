# SwiftBite

A food-ordering app for **Lake Sebu** built with Flutter and Firebase. Customers browse restaurant menus, place orders, and manage delivery addresses; restaurant owners get a dedicated dashboard to manage incoming orders.

## Features

- **Email/password & Google Sign-In** via Firebase Auth
- **Role-based routing** — customers and restaurant owners land in different app shells
- **Profile completion gate** — customers must provide a phone number before using the app
- **Real-time orders** — order status streams live from Firestore for both customers and owners
- **Delivery addresses** — CRUD with a default-address flag, sorted client-side (no composite indexes required)
- **Favourites**, map/location support (Google Maps + Geolocator), and cached network images

## Tech stack

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart SDK ^3.9.2), Material 3 |
| State management | `provider` (`ChangeNotifier` + `ChangeNotifierProxyProvider`) |
| Backend | Firebase — Auth, Cloud Firestore |
| Maps / location | `google_maps_flutter`, `geolocator`, `geocoding` |

## Project structure

```
lib/
├── main.dart            # App entry, provider wiring, auth gate
├── root_shell.dart      # Customer navigation shell
├── constants.dart       # Theme colours / typography
├── models/              # UserProfile, Address, FoodOrder, etc.
├── providers/           # Auth, menu, user-profile, orders, owner-orders
├── services/            # UserRepository — all Firestore access
├── pages/               # Screens (sign-in, checkout, owner/, ...)
└── widgets/             # Shared UI components
```

All Firestore access goes through `UserRepository`. Every method derives ownership from `FirebaseAuth.currentUser.uid` so the app code and the security rules agree on who owns what.

## Getting started

### Prerequisites

- Flutter SDK (see `pubspec.yaml` for the required Dart version)
- A Firebase project with **Authentication** (Email/Password + Google) and **Cloud Firestore** enabled
- Firebase CLI (`npm i -g firebase-tools`)

### Setup

```bash
# 1. Install dependencies
flutter pub get

# 2. Generate firebase_options.dart (gitignored — never commit real keys)
firebase login
flutterfire configure

# 3. Run the app
flutter run
```

`lib/firebase_options.dart.example` shows the expected shape of the generated file.

### Android configuration notes

Google Sign-In and Google Maps require SHA-1/SHA-256 fingerprints of your debug/release keystore registered in the Firebase Console, plus a Maps API key in `android/app/src/main/AndroidManifest.xml`.

## Account roles

Accounts are created as **customers** by default. To create a **restaurant owner** account, edit the user's document in the Firestore Console:

```
users/{uid}
  role: "restaurant_owner"
  restaurantId: "<document ID from the restaurants collection>"
```

Owners bypass the phone-verification gate and are routed straight to the owner shell. An owner account missing `restaurantId` is treated as misconfigured — the app shows an error screen with a sign-out button rather than crashing or dead-ending.

## Auth flow

```
app start
   │
   ▼
AuthStatus.unknown ──────────► Splash (resolving persisted session)
   │
   ├─ unauthenticated ───────► SignInPage
   │
   └─ authenticated
        │
        ├─ profile loading ───► Splash
        │
        ├─ role = owner ──────► OwnerRootShell
        │
        ├─ profile incomplete ► ProfileCompletionGate (add phone)
        │
        └─ otherwise ─────────► RootShell (customer)
```

## Database structure

All data lives in Cloud Firestore. Collections touched by the app:

```
users/{uid}                        ← profile document (one per Auth account)
├── addresses/{addressId}          ← saved delivery addresses
└── favourites/{menuItemId}        ← favourited menu items (doc ID = item ID)
phoneIndex/{e164}                  ← verified-phone uniqueness index
orders/{orderId}                   ← every order, single top-level collection
restaurants/{restaurantId}         ← public catalog (admin-managed)
menu_items/{menuItemId}            ← public catalog (admin-managed)
```

### `users/{uid}` — profile (`UserProfile`)

Owned solely by the authenticated user; `role` / `restaurantId` are only editable via the Firebase Console.

| Field | Type | Notes |
|---|---|---|
| `uid` | string | Always equals the document ID |
| `displayName` | string | |
| `email` | string | |
| `photoUrl` | string? | Google photo or in-app override |
| `phoneNumber` | string? | Normalised E.164, e.g. `+639171234567` |
| `phoneNumberVerified` | bool | Client may only write `false`; `true` only through the OTP flow in `UserRepository.markPhoneVerified` |
| `role` | string | `customer` \| `restaurant_owner` — immutable from the client |
| `restaurantId` | string? | Owners only; points to a `restaurants` doc — immutable from the client |
| `createdAt`, `updatedAt` | timestamp | Server timestamps; `createdAt` immutable |

### `users/{uid}/addresses/{addressId}` — delivery addresses (`Address`)

| Field | Type | Notes |
|---|---|---|
| `userId` | string | Must equal the parent `uid` |
| `label` | string | e.g. `Home`, `Work` |
| `icon` | string | Emoji shown on the card |
| `line1`, `line2` | string | Street/unit; `line2` optional |
| `barangay`, `municipality`, `province`, `postalCode` | string | Philippine address components |
| `country` | string | Defaults to `Philippines` |
| `notes` | string? | Landmark / delivery instructions |
| `isDefault` | bool | Single-default maintained client-side |
| `lat`, `lng` | number? | Optional pinned location |
| `createdAt`, `updatedAt` | timestamp | Sorted default-first, then oldest-first (client-side sort) |

### `users/{uid}/favourites/{menuItemId}` — favourites (`Favourite`)

The document ID **is** the `menu_items` ID, so an existence check is a direct `doc(itemId).get()` — no query needed.

| Field | Type | Notes |
|---|---|---|
| `userId` | string | Must equal the parent `uid` |
| `menuItemId` | string | Same as the document ID |
| `createdAt` | timestamp | Server timestamp |

### `phoneIndex/{e164}` — phone uniqueness index

Document ID is the normalised E.164 number. Written only when a number has actually been verified; intentionally skipped by `updatePhoneNumber` while SMS verification is unavailable.

| Field | Type | Notes |
|---|---|---|
| `uid` | string | Account that owns the number |

### `orders/{orderId}` — orders (`FoodOrder`)

Customers may create/read their own orders; owners may read their restaurant's orders and change **only** `status`. No one can delete — orders are a permanent audit trail. Snapshot fields are frozen at creation time so later profile changes never rewrite history.

| Field | Type | Notes |
|---|---|---|
| `customerId` | string | Must equal the creating auth uid — immutable |
| `customerName` | string | Snapshot — immutable |
| `customerPhone` | string | E.164 snapshot shared with the restaurant — immutable |
| `restaurantId` | string | Query key for the owner dashboard — immutable |
| `restaurantName` | string | Snapshot — immutable |
| `items` | array\<map\> | Each entry: `{ id, name, price, qty, img }` |
| `deliveryAddress` | string | Formatted address snapshot — immutable |
| `subtotal`, `deliveryFee`, `discount`, `total` | number | Immutable financials |
| `promoCode` | string? | Applied code, if any |
| `status` | string | See below — the **only** field an owner can update |
| `createdAt` | timestamp | Immutable |

Status lifecycle: `pending` → `confirmed` → `preparing` → `on_the_way` → `delivered`, with `cancelled` possible along the way.

Queries used require two composite indexes (see [`firestore.indexes.json`](firestore.indexes.json)): `customerId + createdAt desc` and `restaurantId + createdAt desc`.

### `restaurants/{restaurantId}` — public catalog

Readable by any signed-in user; **no client writes** — documents are created and edited via the Firebase Console. There is no Dart model class; `MenuProvider` reads them as raw maps, so this shape is by convention.

| Field | Type | Notes |
|---|---|---|
| `name` | string | Also joins menu items to their restaurant |
| `img` | string | Hero image URL |
| `cuisine` | string? | Short cuisine line |
| `description` | string? | Longer blurb |
| `open` | bool | Missing treated as open |
| `rating` | number? | Info-pill value |
| `time` | string? | Delivery-time info pill |
| `fee` | string? | Delivery-fee info pill |
| `badge` | string? | Overlay badge text |

### `menu_items/{menuItemId}` — public catalog

Same access pattern as `restaurants`: readable by any signed-in user, written only via the Console, no Dart model class.

| Field | Type | Notes |
|---|---|---|
| `name` | string | |
| `description` | string? | |
| `price` | number | Base price (₱) |
| `img` | string | Card image URL |
| `heroImg` | string? | Overrides `img` on the detail page hero |
| `category` | string | Grouping/filter key across the app |
| `restaurant` / `restaurantName` | string | Restaurant display name (`restaurantName` preferred; both read) |
| `restaurantImg` | string? | Explicit logo override |
| `isFeatured` | bool | Included in the home-page featured rail |
| `rating` | number? | |
| `time` | string? | Prep-time text |
| `tag` | string? | Badge text |
| `sizes` | array\<map\>? | `{ label, extra }` — price add-on per size |
| `extras` | array\<map\>? | `{ label, price }` — optional add-ons |
| `related` | array\<string\>? | Menu-item IDs suggested together |

## Security rules

Firestore rules live in [`firestore.rules`](firestore.rules); composite index definitions in [`firestore.indexes.json`](firestore.indexes.json). Deploy with:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Key rule: clients can never set `phoneNumberVerified: true` directly on their own profile — verified state is only written through the OTP flow in `UserRepository.markPhoneVerified`.

## Testing

```bash
flutter test          # unit tests (models, business rules)
flutter analyze       # static analysis
```

## Known limitations

- **"Sign out of all devices"** signs out locally and refreshes the token; other sessions remain valid until their ID token naturally expires (~1 hour). True immediate revocation requires a Cloud Function calling the Admin SDK's `revokeRefreshTokens`.
- Phone numbers are currently saved without SMS verification (no paid Firebase plan). The `phoneIndex` uniqueness collection is designed for verified numbers and is intentionally skipped by `updatePhoneNumber`.
