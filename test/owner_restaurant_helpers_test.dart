import 'package:flutter_test/flutter_test.dart';
import 'package:lake_sebu/utils/restaurant_form_helpers.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Task 10.1 — computeDiff
  // ---------------------------------------------------------------------------
  group('computeDiff', () {
    test('identical maps produce an empty diff', () {
      final map = {'name': 'Resto', 'cuisine': 'Filipino', 'phone': '123'};
      expect(computeDiff(map, Map.of(map)), isEmpty);
    });

    test('single changed value → diff contains only that key', () {
      final original = {'name': 'Resto', 'cuisine': 'Filipino', 'phone': '123'};
      final updated = {'name': 'New Resto', 'cuisine': 'Filipino', 'phone': '123'};
      expect(computeDiff(original, updated), equals({'name': 'New Resto'}));
    });

    test('all fields changed → diff equals updated', () {
      final original = {'name': 'A', 'cuisine': 'B', 'phone': 'C'};
      final updated = {'name': 'X', 'cuisine': 'Y', 'phone': 'Z'};
      expect(computeDiff(original, updated), equals(updated));
    });

    test('extra key in updated not in original → key appears in diff', () {
      final original = {'name': 'Resto'};
      final updated = {'name': 'Resto', 'address': '123 Main St'};
      expect(computeDiff(original, updated), equals({'address': '123 Main St'}));
    });

    test('null vs empty string → key appears in diff', () {
      final original = <String, dynamic>{'description': null};
      final updated = <String, dynamic>{'description': ''};
      expect(computeDiff(original, updated), equals({'description': ''}));
    });

    test('empty original and updated maps → empty diff', () {
      expect(computeDiff({}, {}), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Task 10.3 — isValidImageUrl
  // ---------------------------------------------------------------------------
  group('isValidImageUrl', () {
    test('valid HTTPS URL → accepted', () {
      expect(isValidImageUrl('https://example.com/img.jpg'), isTrue);
    });

    test('valid HTTP URL → accepted', () {
      expect(isValidImageUrl('http://example.com'), isTrue);
    });

    test('valid HTTPS URL with path and query → accepted', () {
      expect(
        isValidImageUrl('https://cdn.example.com/r/img.jpg?w=400'),
        isTrue,
      );
    });

    test('FTP URL → rejected', () {
      expect(isValidImageUrl('ftp://example.com/file'), isFalse);
    });

    test('URL with no scheme → rejected', () {
      expect(isValidImageUrl('example.com/image'), isFalse);
    });

    test('empty string → rejected', () {
      expect(isValidImageUrl(''), isFalse);
    });

    test('whitespace-only string → rejected', () {
      expect(isValidImageUrl('   '), isFalse);
    });

    test('malformed string with no host → rejected', () {
      expect(isValidImageUrl('https:///path'), isFalse);
    });

    test('mailto: URL → rejected', () {
      expect(isValidImageUrl('mailto:user@example.com'), isFalse);
    });
  });
}
