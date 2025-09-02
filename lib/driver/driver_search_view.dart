import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/route_service.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';

class DriverSearchView extends StatefulWidget {
  final String driverId;
  final String driverName;
  
  const DriverSearchView({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<DriverSearchView> createState() => _DriverSearchViewState();
}

class _DriverSearchViewState extends State<DriverSearchView> {
  final MapController _mapController = MapController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  
  LatLng? _currentLocation;
  LatLng? _fromLocation;
  LatLng? _toLocation;
  List<LatLng> _routePoints = [];
  List<String> _roadNames = []; // ✨ NEW: Store road names from OSRM
  List<Marker> _markers = [];
  
  bool _loading = false;
  String? _error;
  num _distance = 0;
  num _duration = 0;
  bool _waitingForFromLocation = false;
  bool _waitingForToLocation = false;
  final _tileProvider = FMTCTileProvider(
    stores: const {'mapStore': BrowseStoreStrategy.readUpdateCreate},
  );
  String? _progressText; // Add this field for progress updates

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadSavedRoute();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (_routePoints.isEmpty) {
          _mapController.move(_currentLocation!, 13.0);
        }
      });
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<void> _loadSavedRoute() async {
    try {
      final routes = await FirebaseService.getRoutesByDriverId(widget.driverId);
      if (routes.isNotEmpty) {
        final latestRoute = routes.first;
        final routePoints = latestRoute['routePoints'] as List<dynamic>? ?? [];
        if (routePoints.isNotEmpty) {
          setState(() {
            _routePoints = routePoints.map((point) => LatLng(point['latitude'], point['longitude'])).toList();
            _distance = latestRoute['distance'] ?? 0;
            _duration = latestRoute['duration'] ?? 0;
            _fromController.text = latestRoute['fromLocation'] ?? '';
            _toController.text = latestRoute['toLocation'] ?? '';
          });
          if (_routePoints.isNotEmpty) {
            _fromLocation = _routePoints.first;
            _toLocation = _routePoints.last;
            _updateMarkers();
            _fitMapToRoute();
          }
        }
      }
    } catch (e) {
      print('Error loading saved route: $e');
    }
  }

  void _fitMapToRoute() {
    if (_routePoints.isNotEmpty) {
      double minLat = _routePoints.first.latitude;
      double maxLat = _routePoints.first.latitude;
      double minLng = _routePoints.first.longitude;
      double maxLng = _routePoints.first.longitude;
      for (final point in _routePoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      _mapController.move(LatLng(centerLat, centerLng), 12.0);
    }
  }

  Future<void> _searchLocation(String query, bool isFrom) async {
    if (query.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);
        setState(() {
          if (isFrom) {
            _fromLocation = latLng;
            _fromController.text = query;
            _mapController.move(latLng, 14.0);
          } else {
            _toLocation = latLng;
            _toController.text = query;
            _mapController.move(latLng, 14.0);
          }
          _updateMarkers();
        });
      } else {
        setState(() {
          _error = 'Location not found: $query';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error searching location: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _updateMarkers() {
    _markers.clear();
    if (_fromLocation != null) {
      _markers.add(
        Marker(
          point: _fromLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
        ),
      );
    }
    if (_toLocation != null) {
      _markers.add(
        Marker(
          point: _toLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    }
    if (_routePoints.isNotEmpty) {
      _markers.add(
        Marker(
          point: _routePoints.first,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
        ),
      );
      _markers.add(
        Marker(
          point: _routePoints.last,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    }
  }

  Future<String> _getAddressFromCoordinates(LatLng point) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        String address = '';
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          address = placemark.street!;
        } else if (placemark.name != null && placemark.name!.isNotEmpty) {
          address = placemark.name!;
        } else if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          address = placemark.locality!;
        }
        if (address.isEmpty) {
          address = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        }
        return address;
      }
    } catch (e) {
      print('Error getting address from coordinates: $e');
    }
    return '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
  }

  Future<void> _calculateRoute() async {
    if (_fromLocation == null || _toLocation == null) {
      setState(() {
        _error = 'Please select both start and end locations';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _progressText = 'Getting coordinates...';
    });
    try {
      final routeData = await RouteService.calculateRoute(_fromLocation!, _toLocation!);
      final points = routeData['points'] as List<LatLng>? ?? [];
      final distance = routeData['distance'] as num? ?? 0;
      final duration = routeData['duration'] as num? ?? 0;
      final roadNames = routeData['roadNames'] as List<String>? ?? []; // ✨ NEW: Get road names from OSRM
      setState(() {
        _routePoints = points;
        _distance = distance;
        _duration = duration;
        _roadNames = roadNames; // ✨ NEW: Store road names
        _progressText = 'Converting to road names...';
      });
      if (points.isNotEmpty) {
        _fitMapToRoute();
      }
    } catch (e) {
      setState(() {
        _error = 'Error calculating route: $e';
        _progressText = null;
      });
    } finally {
      // Don't set _loading = false here, wait until save is done
    }
  }

  Future<void> _saveRoute() async {
    if (_routePoints.isEmpty) {
      setState(() {
        _error = 'No route to save';
        _progressText = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _progressText = 'Saving route...';
    });
    try {
      String fromAddress = await _getAddressFromCoordinates(_fromLocation!);
      String toAddress = await _getAddressFromCoordinates(_toLocation!);
      // ✨ NEW: Use road names from OSRM instead of extracting them
      setState(() { _progressText = 'Processing road names...'; });
      final roadNames = _roadNames.isNotEmpty ? _roadNames : await FirebaseService.extractRoadNames(_routePoints);
      setState(() { _progressText = 'Storing route in database...'; });
      // Delete previous routes for this driver
      final existingRoutes = await FirebaseService.getRoutesByDriverId(widget.driverId);
      if (existingRoutes.isNotEmpty) {
        for (final route in existingRoutes) {
          final routeId = route['routeId'];
          await FirebaseService.firestore.collection('routes').doc(routeId).delete();
        }
      }
      String routeId = '${widget.driverId}_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseService.saveRouteData(
        routeId: routeId,
        routePoints: _routePoints,
        distance: _distance,
        duration: _duration,
        fromLocation: fromAddress,
        toLocation: toAddress,
        roadNames: roadNames,
        driverId: widget.driverId,
        driverName: widget.driverName,
      );
      setState(() {
        _fromController.text = fromAddress;
        _toController.text = toAddress;
        _progressText = 'Done! Redirecting...';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Error saving route: $e';
        _progressText = null;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _calculateAndSaveRoute() async {
    setState(() { _progressText = 'Starting route calculation...'; });
    await _calculateRoute();
    await _saveRoute();
    if (mounted) {
      setState(() { _progressText = null; });
      Navigator.of(context).pop(true); // Return to dashboard and trigger refresh
    }
  }

  void _clearRoute() {
    setState(() {
      _fromController.clear();
      _toController.clear();
      _fromLocation = null;
      _toLocation = null;
      _routePoints.clear();
      _markers.clear();
      _distance = 0;
      _duration = 0;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Route Setup'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? const LatLng(33.6844, 73.0479),
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) {
                      if (_waitingForFromLocation || _waitingForToLocation) {
                        setState(() {
                          if (_waitingForFromLocation) {
                            _fromLocation = point;
                            _waitingForFromLocation = false;
                          } else if (_waitingForToLocation) {
                            _toLocation = point;
                            _waitingForToLocation = false;
                          }
                          _updateMarkers();
                        });
                        _getAddressFromCoordinates(point).then((address) {
                          if (mounted) {
                            setState(() {
                              if (_fromLocation == point) {
                                _fromController.text = address;
                              } else if (_toLocation == point) {
                                _toController.text = address;
                              }
                            });
                          }
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.easyridev2',
                      tileProvider: _tileProvider,
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    PolylineLayer(
                      polylines: [
                        if (_routePoints.isNotEmpty)
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 4,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              ),
            ],
          ),
          // Bottom panel for route input
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.my_location, color: _waitingForFromLocation ? Colors.blue : Colors.grey),
                            tooltip: 'Tap to pick on map',
                            onPressed: () {
                              setState(() {
                                _waitingForFromLocation = true;
                                _waitingForToLocation = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tap on the map to set "From" location'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: _fromController,
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                hintText: 'From',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onSubmitted: (value) => _searchLocation(value, true),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.blue),
                            onPressed: () => _searchLocation(_fromController.text, true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.location_on, color: _waitingForToLocation ? Colors.red : Colors.grey),
                            tooltip: 'Tap to pick on map',
                            onPressed: () {
                              setState(() {
                                _waitingForToLocation = true;
                                _waitingForFromLocation = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tap on the map to set "To" location'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          Expanded(
                            child: TextField(
                              controller: _toController,
                              style: const TextStyle(color: Colors.black),
                              decoration: const InputDecoration(
                                hintText: 'To',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onSubmitted: (value) => _searchLocation(value, false),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search, color: Colors.red),
                            onPressed: () => _searchLocation(_toController.text, false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _calculateAndSaveRoute,
                          icon: const Icon(Icons.route),
                          label: const Text('Calculate & Save Route'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _clearRoute,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                          side: const BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (_distance > 0 || _duration > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text('Distance: ${(_distance / 1000).toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white)),
                        Text('Duration: ${(_duration / 60).round()} min', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_loading && _progressText != null)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        _progressText!,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }
} 