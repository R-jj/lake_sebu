import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../constants.dart';

/// Result returned when the user confirms a location.
class MapPickerResult {
  final double lat;
  final double lng;

  /// Flattened one-line address (kept for display + line-1 fallback).
  final String address;

  // ── Structured address components (empty when geocoding found nothing) ─────
  final String street;
  final String barangay;
  final String municipality;
  final String province;
  final String postalCode;

  const MapPickerResult({
    required this.lat,
    required this.lng,
    required this.address,
    this.street = '',
    this.barangay = '',
    this.municipality = '',
    this.province = '',
    this.postalCode = '',
  });
}

class MapPickerPage extends StatefulWidget {
  /// Optional initial position. Defaults to a central fallback if null.
  final LatLng? initialPosition;

  const MapPickerPage({super.key, this.initialPosition});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  // ── Map controller ────────────────────────────────────────────────────────
  final Completer<GoogleMapController> _controller = Completer();

  // ── State ─────────────────────────────────────────────────────────────────
  LatLng? _pickedLatLng;
  String _resolvedAddress = '';
  Placemark? _placemark;
  bool _isGeocoding = false;
  bool _isLocating = false;

  // Fallback centre — Manila, Philippines
  static const LatLng _kFallback = LatLng(14.5995, 120.9842);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _pickedLatLng = widget.initialPosition;
      _reverseGeocode(widget.initialPosition!);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() {
      _isGeocoding = true;
      _resolvedAddress = 'Fetching address…';
      _placemark = null; // never reuse a previous pin's placemark
    });
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
        setState(() {
          _resolvedAddress = parts.isEmpty ? 'Unknown location' : parts;
          _placemark = p;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _resolvedAddress = 'Unable to fetch address');
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _onMapTap(LatLng pos) {
    setState(() => _pickedLatLng = pos);
    _reverseGeocode(pos);
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _showPermissionDeniedSnack();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);

      final mapCtrl = await _controller.future;
      await mapCtrl.animateCamera(CameraUpdate.newLatLngZoom(latLng, 17));

      setState(() => _pickedLatLng = latLng);
      _reverseGeocode(latLng);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not get your location.'),
            backgroundColor: kRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showPermissionDeniedSnack() {
    if (!mounted) return;
    setState(() => _isLocating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Location permission denied. Enable it in Settings.',
        ),
        backgroundColor: kRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirm() {
    if (_pickedLatLng == null) return;
    final p = _placemark;
    // Trim + null-coalesce each component; rural PH placemarks often leave
    // several of these blank, so empty strings are fine downstream.
    String comp(String? v) => v?.trim() ?? '';
    // Placeholder strings shown while geocoding (or when nothing was found)
    // must never leak into saved address fields — blank means "fill by hand".
    const sentinels = {
      'Fetching address…',
      'Unable to fetch address',
      'Unknown location',
    };
    final address = sentinels.contains(_resolvedAddress)
        ? ''
        : _resolvedAddress;
    Navigator.of(context).pop(
      MapPickerResult(
        lat: _pickedLatLng!.latitude,
        lng: _pickedLatLng!.longitude,
        address: address,
        street: p == null
            ? ''
            : (comp(p.street).isNotEmpty
                  ? comp(p.street)
                  : (comp(p.thoroughfare).isNotEmpty
                        ? comp(p.thoroughfare)
                        : comp(p.name))),
        barangay: p == null ? '' : comp(p.subLocality),
        municipality: p == null
            ? ''
            : (comp(p.locality).isNotEmpty
                  ? comp(p.locality)
                  : comp(p.subAdministrativeArea)),
        province: p == null ? '' : comp(p.administrativeArea),
        postalCode: p == null ? '' : comp(p.postalCode),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialPosition ?? _kFallback;

    return Scaffold(
      backgroundColor: kCanvas,
      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initial, zoom: 15),
            onMapCreated: (ctrl) => _controller.complete(ctrl),
            onTap: _onMapTap,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _pickedLatLng == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _pickedLatLng!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                    ),
                  },
          ),

          // ── Top bar ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: kCanvas,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: kInk,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: kCanvas,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: kBrand,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Tap on the map to pin your location',
                            style: TextStyle(color: kMuted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── My location FAB ───────────────────────────────────────────────
          Positioned(
            right: 16,
            bottom: _pickedLatLng == null ? 32 : 180,
            child: GestureDetector(
              onTap: _isLocating ? null : _goToMyLocation,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kCanvas,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: _isLocating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: kBrand,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.my_location, color: kBrand, size: 22),
              ),
            ),
          ),

          // ── Bottom confirm sheet ──────────────────────────────────────────
          if (_pickedLatLng != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildConfirmSheet(),
            ),
        ],
      ),
    );
  }

  Widget _buildConfirmSheet() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SELECTED LOCATION',
            style: TextStyle(
              color: kMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kBrand.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on, color: kBrand, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isGeocoding
                        ? Row(
                            children: const [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: kBrand,
                                  strokeWidth: 1.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Fetching address…',
                                style: TextStyle(color: kMuted, fontSize: 13),
                              ),
                            ],
                          )
                        : Text(
                            _resolvedAddress.isEmpty
                                ? 'Unknown location'
                                : _resolvedAddress,
                            style: const TextStyle(
                              color: kInk,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                    const SizedBox(height: 4),
                    Text(
                      '${_pickedLatLng!.latitude.toStringAsFixed(6)}, '
                      '${_pickedLatLng!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(color: kMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isGeocoding ? null : _confirm,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                color: _isGeocoding ? kBorder : kBrand,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Confirm Location',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
