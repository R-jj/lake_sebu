import 'package:cloud_firestore/cloud_firestore.dart';

/// A saved delivery address belonging to a specific authenticated user.
///
/// Firestore path: `users/{uid}/addresses/{addressId}`
class Address {
  final String id;          // Firestore document ID (auto-generated)
  final String userId;      // Must match the owning user's uid
  final String label;       // e.g. "Home", "Work", "Other"
  final String icon;        // Emoji icon, e.g. "🏠", "💼", "📍"
  final String line1;       // Street / building / unit
  final String line2;       // Additional line (e.g. floor, block, lot)
  final String barangay;
  final String municipality; // City or municipality
  final String province;
  final String postalCode;
  final String country;
  final String? notes;       // Delivery instructions / landmark
  final bool isDefault;
  final double? lat;
  final double? lng;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.icon,
    required this.line1,
    this.line2 = '',
    this.barangay = '',
    this.municipality = '',
    this.province = '',
    this.postalCode = '',
    this.country = 'Philippines',
    this.notes,
    this.isDefault = false,
    this.lat,
    this.lng,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasCoordinates => lat != null && lng != null;

  /// A human-readable single-line summary of the address.
  String get displayLine {
    final parts = [
      if (line1.isNotEmpty) line1,
      if (barangay.isNotEmpty) barangay,
      if (municipality.isNotEmpty) municipality,
      if (province.isNotEmpty) province,
    ];
    return parts.join(', ');
  }

  /// A shorter two-line summary used in cards.
  String get shortLine {
    final parts = [
      if (municipality.isNotEmpty) municipality,
      if (province.isNotEmpty) province,
      if (postalCode.isNotEmpty) postalCode,
    ];
    return parts.join(', ');
  }

  // ── Firestore serialisation ───────────────────────────────────────────────

  factory Address.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Address(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      label: d['label'] as String? ?? '',
      icon: d['icon'] as String? ?? '📍',
      line1: d['line1'] as String? ?? '',
      line2: d['line2'] as String? ?? '',
      barangay: d['barangay'] as String? ?? '',
      municipality: d['municipality'] as String? ?? '',
      province: d['province'] as String? ?? '',
      postalCode: d['postalCode'] as String? ?? '',
      country: d['country'] as String? ?? 'Philippines',
      notes: d['notes'] as String?,
      isDefault: d['isDefault'] as bool? ?? false,
      lat: (d['lat'] as num?)?.toDouble(),
      lng: (d['lng'] as num?)?.toDouble(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'label': label,
        'icon': icon,
        'line1': line1,
        'line2': line2,
        'barangay': barangay,
        'municipality': municipality,
        'province': province,
        'postalCode': postalCode,
        'country': country,
        if (notes != null) 'notes': notes,
        'isDefault': isDefault,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Address copyWith({
    String? id,
    String? userId,
    String? label,
    String? icon,
    String? line1,
    String? line2,
    String? barangay,
    String? municipality,
    String? province,
    String? postalCode,
    String? country,
    String? notes,
    bool? isDefault,
    double? lat,
    double? lng,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Address(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        label: label ?? this.label,
        icon: icon ?? this.icon,
        line1: line1 ?? this.line1,
        line2: line2 ?? this.line2,
        barangay: barangay ?? this.barangay,
        municipality: municipality ?? this.municipality,
        province: province ?? this.province,
        postalCode: postalCode ?? this.postalCode,
        country: country ?? this.country,
        notes: notes ?? this.notes,
        isDefault: isDefault ?? this.isDefault,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
