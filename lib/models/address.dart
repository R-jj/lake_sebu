/// A saved delivery address.
class Address {
  final int id;
  final String label;
  final String line1;
  final String line2;
  final String icon;
  final bool isDefault;
  final double? lat;
  final double? lng;

  const Address({
    required this.id,
    required this.label,
    required this.line1,
    required this.line2,
    required this.icon,
    this.isDefault = false,
    this.lat,
    this.lng,
  });

  bool get hasCoordinates => lat != null && lng != null;

  Address copyWith({
    int? id,
    String? label,
    String? line1,
    String? line2,
    String? icon,
    bool? isDefault,
    double? lat,
    double? lng,
  }) =>
      Address(
        id: id ?? this.id,
        label: label ?? this.label,
        line1: line1 ?? this.line1,
        line2: line2 ?? this.line2,
        icon: icon ?? this.icon,
        isDefault: isDefault ?? this.isDefault,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
      );
}
