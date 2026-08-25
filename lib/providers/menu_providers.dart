import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Parses the optional sizes array from a menu item.
List<Map<String, dynamic>> sizesOf(Map<String, dynamic> item) {
  final raw = item['sizes'];
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// Parses the optional extras array from a menu item.
List<Map<String, dynamic>> extrasOf(Map<String, dynamic> item) {
  final raw = item['extras'];
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// Parses the optional related ids array from a menu item.
List<String> relatedOf(Map<String, dynamic> item) {
  final raw = item['related'];
  if (raw is! List) return [];
  return raw.map((e) => e.toString()).toList();
}

class MenuProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _menuItems = [];
  bool _isLoading = true;

  // Getters
  List<Map<String, dynamic>> get restaurants => _restaurants;
  List<Map<String, dynamic>> get allItems => _menuItems;

  Map<String, dynamic>? itemById(String id) {
    for (final item in _menuItems) {
      if ('${item['id']}' == id) return item;
    }
    return null;
  }

  /// Finds a restaurant by its Firestore document ID.
  Map<String, dynamic>? restaurantById(String? id) {
    if (id == null) return null;
    for (final r in _restaurants) {
      if ('${r['id']}' == id) return r;
    }
    return null;
  }

  /// Finds a restaurant by its name (kept for legacy callers).
  Map<String, dynamic>? restaurantByName(String? name) {
    if (name == null) return null;
    for (final r in _restaurants) {
      if (r['name'] == name) return r;
    }
    return null;
  }
  
  // Dynamically filter featured items in memory
  List<Map<String, dynamic>> get featuredItems => 
      _menuItems.where((item) => item['isFeatured'] == true).toList();
      
  bool get isLoading => _isLoading;

  MenuProvider() {
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    try {
      final db = FirebaseFirestore.instance;

      // Fetch the two unified collections
      final results = await Future.wait([
        db.collection('restaurants').get(),
        db.collection('menu_items').get(),
      ]);

      _restaurants = results[0].docs.map((doc) => _injectId(doc)).toList();
      _menuItems = results[1].docs.map((doc) => _injectId(doc)).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _injectId(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return data;
  }
}
