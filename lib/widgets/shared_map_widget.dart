import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/driver.dart';
import '../services/route_service.dart';
import '../utils/color_utils.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class SharedMapWidget extends StatelessWidget {
  static final _tileProvider = FMTCTileProvider(
    stores: const {'mapStore': BrowseStoreStrategy.readUpdateCreate},
  );
  final MapController mapController;
  final List<Driver> drivers;
  final String? selectedDriverId;
  final LatLng? driverFrom;
  final LatLng? driverTo;
  final List<LatLng> driverPoints;
  final LatLng? passengerFrom;
  final LatLng? passengerTo;
  final List<LatLng> passengerPoints;
  final bool isMapSelectionMode;
  final String? currentSelectionField;
  final Function(TapPosition, LatLng)? onMapTap;
  final bool isLoading;
  final Map<String, List<LatLng>>? dynamicDriverRoutes;

  const SharedMapWidget({
    super.key,
    required this.mapController,
    required this.drivers,
    required this.selectedDriverId,
    required this.driverFrom,
    required this.driverTo,
    required this.driverPoints,
    required this.passengerFrom,
    required this.passengerTo,
    required this.passengerPoints,
    required this.isMapSelectionMode,
    this.currentSelectionField,
    this.onMapTap,
    required this.isLoading,
    this.dynamicDriverRoutes,
  });

  Color _getDriverColor(String driverId) {
    if (drivers.isNotEmpty) {
      final driver = drivers.firstWhere(
        (d) => d.id == driverId,
        orElse: () => drivers.first,
      );
      return driver.markerColor;
    }
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final commonPoints = RouteService.getCommonRoute(driverPoints, passengerPoints);
    final mapCenter = driverFrom ?? passengerFrom ?? const LatLng(36.479960, 2.829099);
    final isSingleRoute = drivers.isEmpty;
    final routeColor = drivers.isNotEmpty
        ? (selectedDriverId != null
            ? drivers.firstWhere(
                (d) => d.id == selectedDriverId,
                orElse: () => drivers.first,
              ).markerColor
            : drivers.first.markerColor)
        : Colors.blue;

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: 13.0,
            onTap: isMapSelectionMode ? onMapTap : null,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.easyridev2',
              tileProvider: _tileProvider,
              subdomains: const ['a', 'b', 'c'],
              maxZoom: 19,
            ),
            // Dynamic driver routes (for passenger view)
            if (dynamicDriverRoutes != null && dynamicDriverRoutes!.isNotEmpty)
              ...dynamicDriverRoutes!.entries.map((entry) {
                final driverId = entry.key;
                final routePoints = entry.value;
                final color = _getDriverColor(driverId);
                return PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 3.0,
                      color: color,
                    ),
                  ],
                );
              }).toList(),
            // Route
            if (driverPoints.isNotEmpty && dynamicDriverRoutes == null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: driverPoints,
                    strokeWidth: 4.0,
                    color: routeColor,
                  ),
                ],
              ),
            // Passenger route (only for comparison mode)
            if (passengerPoints.isNotEmpty && !isSingleRoute)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: passengerPoints,
                    strokeWidth: 4.0,
                    color: Colors.green,
                  ),
                ],
              ),
            // Common route (only for comparison mode)
            if (commonPoints.isNotEmpty && !isSingleRoute)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: commonPoints,
                    strokeWidth: 6.0,
                    color: Colors.red,
                  ),
                ],
              ),
            // Common route markers (only for comparison mode)
            if (commonPoints.isNotEmpty && !isSingleRoute)
              MarkerLayer(
                markers: commonPoints.asMap().entries.map((entry) {
                  final index = entry.key;
                  final point = entry.value;
                  return Marker(
                    width: 40.0,
                    height: 40.0,
                    point: point,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            MarkerLayer(
              markers: [
                // Driver profile markers (only for comparison mode)
                if (!isSingleRoute)
                  ...drivers.map((driver) => Marker(
                    width: 50.0,
                    height: 50.0,
                    point: driver.profileLocation,
                    child: Container(
                      decoration: BoxDecoration(
                        color: driver.markerColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          driver.name.split(' ').map((n) => n[0]).join(''),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  )).toList(),
                
                // Route markers
                if (driverFrom != null)
                  Marker(
                    width: 60.0,
                    height: 60.0,
                    point: driverFrom!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: routeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                    ),
                  ),
                if (driverTo != null)
                  Marker(
                    width: 60.0,
                    height: 60.0,
                    point: driverTo!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: routeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                    ),
                  ),
                // Passenger markers (only for comparison mode)
                if (passengerFrom != null && !isSingleRoute)
                  Marker(
                    width: 60.0,
                    height: 60.0,
                    point: passengerFrom!,
                    child: const Icon(Icons.circle, color: Colors.green, size: 30),
                  ),
                if (passengerTo != null && !isSingleRoute)
                  Marker(
                    width: 60.0,
                    height: 60.0,
                    point: passengerTo!,
                    child: const Icon(Icons.circle, color: Colors.green, size: 30),
                  ),
              ],
            ),
          ],
        ),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
        if (isMapSelectionMode)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Tap on map to set ${currentSelectionField?.toLowerCase().replaceAll('driver', 'driver ').replaceAll('passenger', 'passenger ').replaceAll('from', 'FROM').replaceAll('to', 'TO')}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
} 