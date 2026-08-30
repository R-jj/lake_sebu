import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../constants.dart';

/// Full-screen map view showing an order's pinned delivery location.
///
/// Displays an interactive Google map with a marker at the exact
/// delivery spot, floating zoom / recenter controls, and the address
/// and coordinate readout in a card at the bottom.  Pinch, pan, and
/// rotate gestures stay enabled.  Opened from [OrderMapThumbnail] and
/// the owner orders list.
class OrderMapPage extends StatefulWidget {
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
  State<OrderMapPage> createState() => _OrderMapPageState();
}

class _OrderMapPageState extends State<OrderMapPage> {
  // ── Map controller ────────────────────────────────────────────────────────

  final Completer<GoogleMapController> _controller = Completer();

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Zooms the camera in (positive [delta]) or out (negative).
  Future<void> _zoomBy(double delta) async {
    if (!_controller.isCompleted) return;
    final mapCtrl = await _controller.future;
    await mapCtrl.animateCamera(CameraUpdate.zoomBy(delta));
  }

  /// Re-centers the camera on the pinned delivery spot at initial zoom.
  Future<void> _recenter() async {
    if (!_controller.isCompleted) return;
    final mapCtrl = await _controller.future;
    await mapCtrl.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(widget.lat, widget.lng), 16),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final position = LatLng(widget.lat, widget.lng);

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
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: position,
                    zoom: 16,
                  ),
                  onMapCreated: (ctrl) => _controller.complete(ctrl),
                  markers: {
                    Marker(
                      markerId: const MarkerId('delivery'),
                      position: position,
                      infoWindow: InfoWindow(
                        title: 'Delivery address',
                        snippet: widget.address,
                      ),
                    ),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // ── Zoom / recenter controls ────────────────────────────
                Positioned(
                  right: 16,
                  top: 16,
                  child: Column(
                    children: [
                      _MapControlButton(
                        icon: Icons.add,
                        onTap: () => _zoomBy(1),
                      ),
                      const SizedBox(height: 10),
                      _MapControlButton(
                        icon: Icons.remove,
                        onTap: () => _zoomBy(-1),
                      ),
                      const SizedBox(height: 10),
                      _MapControlButton(
                        icon: Icons.filter_center_focus,
                        onTap: _recenter,
                      ),
                    ],
                  ),
                ),
              ],
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
                          widget.address.isNotEmpty
                              ? widget.address
                              : 'Pinned location',
                          style: const TextStyle(
                            color: kInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.lat.toStringAsFixed(6)}, '
                          '${widget.lng.toStringAsFixed(6)}',
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

// ── _MapControlButton ───────────────────────────────────────────────────────

/// Floating control button overlayed on the full-screen order map.
/// Mirrors the FAB styling used in `map_picker_page.dart`.
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: kCanvas,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: kBrand, size: 22),
      ),
    );
  }
}
