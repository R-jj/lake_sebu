import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lake_sebu/models/user_profile.dart';

void main() {
  group('UserRole', () {
    test('fromString parses known values', () {
      expect(UserRole.fromString('customer'), UserRole.customer);
      expect(UserRole.fromString('restaurant_owner'), UserRole.restaurantOwner);
    });

    test('fromString falls back to customer for unknown/null', () {
      expect(UserRole.fromString('admin'), UserRole.customer);
      expect(UserRole.fromString(null), UserRole.customer);
    });
  });

  group('UserProfile.isComplete', () {
    test('customer without phone is incomplete', () {
      const profile = UserProfile(
        uid: 'u1',
        displayName: 'A',
        email: 'a@b.c',
      );
      expect(profile.isComplete, isFalse);
    });

    test('customer with phone is complete', () {
      const profile = UserProfile(
        uid: 'u1',
        displayName: 'A',
        email: 'a@b.c',
        phoneNumber: '+639171234567',
      );
      expect(profile.isComplete, isTrue);
    });

    test('blank phone string counts as incomplete', () {
      const profile = UserProfile(
        uid: 'u1',
        displayName: 'A',
        email: 'a@b.c',
        phoneNumber: '',
      );
      expect(profile.isComplete, isFalse);
    });

    test('restaurant owner is always complete, even without phone', () {
      const profile = UserProfile(
        uid: 'u1',
        displayName: 'Owner',
        email: 'o@b.c',
        role: UserRole.restaurantOwner,
        restaurantId: 'r1',
      );
      expect(profile.isComplete, isTrue);
    });
  });

  group('UserProfile.toFirestoreCreate', () {
    test('always writes customer role and unverified phone', () {
      // Even if the in-memory object claims owner/verified status, creation
      // must never escalate privileges — that is enforced server-side too.
      const profile = UserProfile(
        uid: 'u1',
        displayName: 'Evil',
        email: 'e@b.c',
        role: UserRole.restaurantOwner,
        restaurantId: 'r1',
        phoneNumberVerified: true,
      );

      final map = profile.toFirestoreCreate();

      expect(map['role'], UserRole.customer.value);
      expect(map['phoneNumberVerified'], isFalse);
      expect(map.containsKey('restaurantId'), isFalse);
      expect(map['uid'], 'u1');
    });

    test('omits photoUrl when null but includes it when set', () {
      const noPhoto = UserProfile(uid: 'u1', displayName: 'A', email: 'a@b.c');
      expect(noPhoto.toFirestoreCreate().containsKey('photoUrl'), isFalse);

      const withPhoto = UserProfile(
        uid: 'u1',
        displayName: 'A',
        email: 'a@b.c',
        photoUrl: 'https://example.com/p.png',
      );
      expect(withPhoto.toFirestoreCreate()['photoUrl'], 'https://example.com/p.png');
    });

    test('uses server timestamps for createdAt/updatedAt', () {
      const profile = UserProfile(uid: 'u1', displayName: 'A', email: 'a@b.c');
      final map = profile.toFirestoreCreate();
      expect(map['createdAt'], isA<FieldValue>());
      expect(map['updatedAt'], isA<FieldValue>());
    });
  });

  group('UserProfile.phone update maps', () {
    test('phoneVerifiedUpdate sets number and verified flag', () {
      final map = UserProfile.phoneVerifiedUpdate('+639171234567');
      expect(map['phoneNumber'], '+639171234567');
      expect(map['phoneNumberVerified'], isTrue);
    });

    test('phonePendingUpdate clears verified flag', () {
      final map = UserProfile.phonePendingUpdate('+639170000000');
      expect(map['phoneNumber'], '+639170000000');
      expect(map['phoneNumberVerified'], isFalse);
    });
  });
}
