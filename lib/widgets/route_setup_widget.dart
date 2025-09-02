import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RouteSetupWidget extends StatefulWidget {
  final String role; // 'driver' or 'passenger'
  final String userId;
  final String userName;
  final Function(Map routeData) onRouteSaved;

  const RouteSetupWidget({
    Key? key,
    required this.role,
    required this.userId,
    required this.userName,
    required this.onRouteSaved,
  }) : super(key: key);

  @override
  State<RouteSetupWidget> createState() => _RouteSetupWidgetState();
}

class _RouteSetupWidgetState extends State<RouteSetupWidget> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng? _fromLocation;
  LatLng? _toLocation;
  List<LatLng> _routePoints = [];
  List<String> _roadNames = []; // ✨ NEW: Store road names from OSRM
  num _distance = 0;
  num _duration = 0;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(bool isFrom) async {
    final controller = isFrom ? _fromController : _toController;
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final location = await LocationService.searchLocation(controller.text);
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found')),
        );
        setState(() => _loading = false);
        return;
      }
      setState(() {
        if (isFrom) {
          _fromLocation = location;
        } else {
          _toLocation = location;
        }
      });
      _mapController.move(location, 15.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location set: ${controller.text}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error searching location')),
      );
    }
    setState(() => _loading = false);
  }

  Future<void> _calculateRoute() async {
    if (_fromLocation == null || _toLocation == null) return;
    setState(() => _loading = true);
    try {
      final routeData = await RouteService.calculateRoute(_fromLocation!, _toLocation!);
      setState(() {
        _distance = routeData['distance'];
        _duration = routeData['duration'];
        _routePoints = routeData['points'];
        // ✨ NEW: Store road names from OSRM for later use
        _roadNames = routeData['roadNames'] ?? [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route calculated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to calculate route')),
      );
    }
    setState(() => _loading = false);
  }

  Future<void> _saveOrUpdateRoute() async {
    if (_routePoints.isEmpty) {
      setState(() { _error = 'No route to save'; });
      return;
    }
    setState(() { _loading = true; });
    try {
      String fromAddress = _fromController.text;
      String toAddress = _toController.text;
      // ✨ NEW: Use road names from OSRM instead of extracting them
      final roadNames = _roadNames.isNotEmpty ? _roadNames : await FirebaseService.extractRoadNames(_routePoints);
      final existingRoutes = await FirebaseService.getRoutesByDriverId(widget.userId);
      String routeId;
      if (existingRoutes.isNotEmpty) {
        // Update existing route
        routeId = existingRoutes.first['routeId'];
        await FirebaseService.firestore
            .collection('routes')
            .doc(routeId)
            .update({
          'routePoints': _routePoints.map((p) => {'latitude': p.latitude, 'longitude': p.longitude}).toList(),
          'distance': _distance,
          'duration': _duration,
          'fromLocation': fromAddress,
          'toLocation': toAddress,
          'roadNames': roadNames,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new route
        routeId = '${widget.userId}_${DateTime.now().millisecondsSinceEpoch}';
        await FirebaseService.saveRouteData(
          routeId: routeId,
          routePoints: _routePoints,
          distance: _distance,
          duration: _duration,
          fromLocation: fromAddress,
          toLocation: toAddress,
          roadNames: roadNames,
          driverId: widget.role == 'driver' ? widget.userId : null,
          driverName: widget.role == 'driver' ? widget.userName : null,
          passengerId: widget.role == 'passenger' ? widget.userId : null,
        );
      }
      widget.onRouteSaved({
        'routeId': routeId,
        'routePoints': _routePoints,
        'distance': _distance,
        'duration': _duration,
        'fromLocation': fromAddress,
        'toLocation': toAddress,
        'roadNames': roadNames,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existingRoutes.isNotEmpty ? 'Route updated successfully!' : 'Route saved successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() { _error = 'Error saving route: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.role == 'driver' ? 'Driver Route Setup' : 'Passenger Route Setup',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fromController,
                    decoration: const InputDecoration(
                      labelText: 'From',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : () => _searchLocation(true),
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _toController,
                    decoration: const InputDecoration(
                      labelText: 'To',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _loading ? null : () => _searchLocation(false),
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _calculateRoute,
                icon: const Icon(Icons.route),
                label: const Text('Calculate Route'),
              ),
            ),
            const SizedBox(height: 8),
            if (_routePoints.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _saveOrUpdateRoute,
                  icon: const Icon(Icons.save),
                  label: const Text('Save/Update Route'),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _fromLocation ?? LatLng(0, 0),
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  if (_fromLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _fromLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on, color: Colors.green, size: 36),
                        ),
                        if (_toLocation != null)
                          Marker(
                            point: _toLocation!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.flag, color: Colors.blue, size: 36),
                          ),
                      ],
                    ),
                  if (_routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 4,
                          color: Colors.purple,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 