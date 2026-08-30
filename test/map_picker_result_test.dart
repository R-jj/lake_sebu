import 'package:flutter_test/flutter_test.dart';
import 'package:lake_sebu/pages/map_picker_page.dart';

void main() {
  group('MapPickerResult', () {
    test(
      'legacy 3-arg construction works, structured fields default to empty',
      () {
        const r = MapPickerResult(
          lat: 6.2963,
          lng: 124.7404,
          address: 'National Hwy, Lake Sebu',
        );
        expect(r.lat, 6.2963);
        expect(r.lng, 124.7404);
        expect(r.address, 'National Hwy, Lake Sebu');
        expect(r.street, '');
        expect(r.barangay, '');
        expect(r.municipality, '');
        expect(r.province, '');
        expect(r.postalCode, '');
      },
    );

    test('full construction carries all structured fields', () {
      const r = MapPickerResult(
        lat: 6.2963,
        lng: 124.7404,
        address: 'National Hwy, Poblacion, Lake Sebu, South Cotabato',
        street: 'National Hwy',
        barangay: 'Poblacion',
        municipality: 'Lake Sebu',
        province: 'South Cotabato',
        postalCode: '9514',
      );
      expect(r.address, 'National Hwy, Poblacion, Lake Sebu, South Cotabato');
      expect(r.street, 'National Hwy');
      expect(r.barangay, 'Poblacion');
      expect(r.municipality, 'Lake Sebu');
      expect(r.province, 'South Cotabato');
      expect(r.postalCode, '9514');
    });
  });
}
