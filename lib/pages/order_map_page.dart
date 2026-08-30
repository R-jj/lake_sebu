import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants.dart';

/// Full-screen map view showing an order's pinned delivery location.
///
/// Displays an interactive Google map with a marker at the exact
/// delivery spot, plus the address and coordinate readout in a card
/// at the bottom.  Opened from [OrderMapThumbnail] and the owner
/// orders list.
class OrderMapPage extends StatelessWidget {
  /// Pinned delivery latitude (from `FoodOrder.deliveryLat`).
  final double lat;

  /// Pinned delivery longitude (from `FoodOrder.deliveryLng`).
  final double lng;

  /// Delivery address snapshot shown in the bottom card.
  final String address;

  const OrderMapPage({
    super.key,
    required this.lat,
    required this.lng,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final position = LatLng(lat, lng);

    return Scaffold(
      backgroundColor: kCanvas,
      appBar: AppBar(
        backgroundColor: kCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: kInk,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Delivery location',
          style: TextStyle(
            color: kInk,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: position, zoom: 16),
              markers: {
                Marker(
                  markerId: const MarkerId('delivery'),
                  position: position,
                  infoWindow: InfoWindow(
                    title: 'Delivery address',
                    snippet: address,
                  ),
                ),
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),
          // ── Address + coordinates card ───────────────────────────────
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                color: kCanvas,
                border: Border(top: BorderSide(color: kSurface2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kBrand.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: kBrand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address.isNotEmpty ? address : 'Pinned location',
                          style: const TextStyle(
                            color: kInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                          style: const TextStyle(color: kMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Embedded lite-mode map thumbnail showing an order's pinned delivery
/// location.  Tapping it opens the full-screen [OrderMapPage].
///
/// Uses [GoogleMap.liteModeEnabled] on Android for static-like rendering
/// without the full interactive map overhead — mirrors the
/// `_MapThumbnail` pattern in `owner_restaurant_page.dart`.
class OrderMapThumbnail extends StatelessWidget {
  final double lat;
  final double lng;
  final String address;

  const OrderMapThumbnail({
    super.key,
    required this.lat,
    required this.lng,
    required this.address,
  });

  void _openFullMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderMapPage(lat: lat, lng: lng, address: address),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullMap(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 160,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(lat, lng),
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('delivery'),
                position: LatLng(lat, lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            liteModeEnabled: true,
          ),
        ),
      ),
    );
  }
}
