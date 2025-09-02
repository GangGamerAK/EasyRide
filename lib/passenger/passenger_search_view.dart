import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/route_service.dart';
import '../services/chat_service.dart';
import '../views/chat_view.dart';
import '../views/profile_view.dart';
import 'passenger_home_view.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../widgets/verification_badge.dart';

class PassengerSearchView extends StatefulWidget {
  final String passengerId;
  final String passengerName;
  
  const PassengerSearchView({
    super.key,
    required this.passengerId,
    required this.passengerName,
  });

  @override
  State<PassengerSearchView> createState() => _PassengerSearchViewState();
}

class _PassengerSearchViewState extends State<PassengerSearchView> {
  final MapController _mapController = MapController();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  
  LatLng? _currentLocation;
  LatLng? _fromLocation;
  LatLng? _toLocation;
  List<LatLng> _passengerRoutePoints = [];
  List<String> _roadNames = []; // ✨ NEW: Store road names from OSRM
  List<Marker> _markers = [];
  
  bool _loading = false;
  String? _error;
  num _distance = 0;
  num _duration = 0;
  bool _waitingForFromLocation = false;
  bool _waitingForToLocation = false;
  bool _showMatchingDrivers = false;
  
  // Driver matching
  List<Map<String, dynamic>> _allDriverRoutes = [];
  List<Map<String, dynamic>> _matchingDriverRoutes = [];
  Map<String, dynamic>? _selectedDriverRoute;
  List<LatLng> _selectedDriverRoutePoints = [];
  
  final _tileProvider = FMTCTileProvider(
    stores: const {'mapStore': BrowseStoreStrategy.readUpdateCreate},
  );
  
  String? _progressText; // Add this field for progress updates
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadSavedRoute();
    _loadAllDriverRoutes();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (_passengerRoutePoints.isEmpty) {
          _mapController.move(_currentLocation!, 13.0);
        }
      });
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  Future<void> _loadSavedRoute() async {
    try {
      // Load the passenger's most recent route
      final routes = await FirebaseService.getRoutesByDriverId(widget.passengerId);
      if (routes.isNotEmpty) {
        // Get the most recent route
        final latestRoute = routes.first;
        final routePoints = latestRoute['routePoints'] as List<dynamic>? ?? [];
        
        if (routePoints.isNotEmpty) {
          setState(() {
            _passengerRoutePoints = routePoints.map((point) => 
                LatLng(point['latitude'], point['longitude'])).toList();
            _distance = latestRoute['distance'] ?? 0;
            _duration = latestRoute['duration'] ?? 0;
            _fromController.text = latestRoute['fromLocation'] ?? '';
            _toController.text = latestRoute['toLocation'] ?? '';
          });
          
          // Set markers for start and end points
          if (_passengerRoutePoints.isNotEmpty) {
            _fromLocation = _passengerRoutePoints.first;
            _toLocation = _passengerRoutePoints.last;
            _updateMarkers();
            
            // Fit map to show the route
            _fitMapToRoute();
          }
        }
      }
    } catch (e) {
      print('Error loading saved route: $e');
    }
  }

  Future<void> _loadAllDriverRoutes() async {
    try {
      _allDriverRoutes = await FirebaseService.getAllDriverRoutes();
      // Don't find matching drivers until route is calculated
    } catch (e) {
      print('Error loading driver routes: $e');
    }
  }

  void _findMatchingDrivers() {
    if (_passengerRoutePoints.isEmpty) {
      setState(() {
        _matchingDriverRoutes = [];
        _selectedDriverRoute = null;
        _selectedDriverRoutePoints = [];
        _showMatchingDrivers = false;
      });
      return;
    }

    const threshold = 0.2; // km
    final Distance dist = const Distance();
    List<Map<String, dynamic>> matches = [];
    
    for (final route in _allDriverRoutes) {
      // Skip if this is the current passenger's own route
      final routeDriverId = route['driverId'] as String? ?? '';
      if (routeDriverId == widget.passengerId) {
        continue;
      }
      
      final points = (route['routePoints'] as List<dynamic>? ?? [])
          .map((p) => LatLng(p['latitude'], p['longitude']))
          .toList();
      
      // Calculate match percentage
      double matchPercentage = _calculateMatchPercentage(_passengerRoutePoints, points, threshold);
      
      if (matchPercentage > 0) {
        // Add match percentage to route data
        final routeWithMatch = Map<String, dynamic>.from(route);
        routeWithMatch['matchPercentage'] = matchPercentage;
        matches.add(routeWithMatch);
      }
    }
    
    // Sort by match percentage (highest first)
    matches.sort((a, b) => (b['matchPercentage'] as double).compareTo(a['matchPercentage'] as double));
    
    setState(() {
      _matchingDriverRoutes = matches;
      _showMatchingDrivers = true;
    });
  }

  double _calculateMatchPercentage(List<LatLng> passengerRoute, List<LatLng> driverRoute, double threshold) {
    if (passengerRoute.isEmpty || driverRoute.isEmpty) return 0.0;
    
    final Distance dist = const Distance();
    int matchingPoints = 0;
    int totalPassengerPoints = passengerRoute.length;
    
    // Check each passenger route point against driver route points
    for (final passengerPoint in passengerRoute) {
      bool hasMatch = false;
      
      for (final driverPoint in driverRoute) {
        if (dist(passengerPoint, driverPoint) < threshold * 1000) {
          hasMatch = true;
          break;
        }
      }
      
      if (hasMatch) {
        matchingPoints++;
      }
    }
    
    // Calculate percentage
    return (matchingPoints / totalPassengerPoints) * 100;
  }

  Color _getMatchColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    if (percentage >= 40) return Colors.yellow.shade700;
    return Colors.red;
  }

  void _selectDriverRoute(Map<String, dynamic> route) {
    setState(() {
      _selectedDriverRoute = route;
      _selectedDriverRoutePoints = (route['routePoints'] as List<dynamic>? ?? [])
          .map((p) => LatLng(p['latitude'], p['longitude']))
          .toList();
    });
    _updateMarkers();
    _fitMapToRoutes();
  }

  void _fitMapToRoute() {
    if (_passengerRoutePoints.isNotEmpty) {
      // Calculate bounds manually and move to center
      double minLat = _passengerRoutePoints.first.latitude;
      double maxLat = _passengerRoutePoints.first.latitude;
      double minLng = _passengerRoutePoints.first.longitude;
      double maxLng = _passengerRoutePoints.first.longitude;
      
      for (final point in _passengerRoutePoints) {
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

  void _fitMapToRoutes() {
    final allPoints = [..._passengerRoutePoints, ..._selectedDriverRoutePoints];
    if (allPoints.isNotEmpty) {
      double minLat = allPoints.first.latitude;
      double maxLat = allPoints.first.latitude;
      double minLng = allPoints.first.longitude;
      double maxLng = allPoints.first.longitude;
      
      for (final point in allPoints) {
        if (point.latitude < minLat) minLat = point.latitude;
        if (point.latitude > maxLat) maxLat = point.latitude;
        if (point.longitude < minLng) minLng = point.longitude;
        if (point.longitude > maxLng) maxLng = point.longitude;
      }
      
      final centerLat = (minLat + maxLat) / 2;
      final centerLng = (minLng + maxLng) / 2;
      _mapController.move(LatLng(centerLat, centerLng), 11.0);
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
            // Move map to 'From' location
            _mapController.move(latLng, 14.0);
          } else {
            _toLocation = latLng;
            _toController.text = query;
            // Move map to 'To' location
            _mapController.move(latLng, 14.0);
            // Only trigger route calculation when both are set and 'To' is searched
            if (_fromLocation != null && _toLocation != null) {
              _calculateRouteAndSave();
            }
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
    
    // Show marker for 'From' location if set
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
    // Show marker for 'To' location if set
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

    // Passenger route markers (for calculated route)
    if (_passengerRoutePoints.isNotEmpty) {
      _markers.add(
        Marker(
          point: _passengerRoutePoints.first,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.green, size: 40),
        ),
      );
      _markers.add(
        Marker(
          point: _passengerRoutePoints.last,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
        ),
      );
    }
    
    // Selected driver route markers
    if (_selectedDriverRoutePoints.isNotEmpty) {
      _markers.add(
        Marker(
          point: _selectedDriverRoutePoints.first,
          width: 40,
          height: 40,
          child: const Icon(Icons.directions_car, color: Colors.blue, size: 36),
        ),
      );
      _markers.add(
        Marker(
          point: _selectedDriverRoutePoints.last,
          width: 40,
          height: 40,
          child: const Icon(Icons.flag, color: Colors.blue, size: 36),
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
        
        // Build address from placemark components
        if (placemark.street != null && placemark.street!.isNotEmpty) {
          address = placemark.street!;
          if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
            address += ', ${placemark.subLocality}';
          }
        } else if (placemark.name != null && placemark.name!.isNotEmpty) {
          address = placemark.name!;
        } else if (placemark.locality != null && placemark.locality!.isNotEmpty) {
          address = placemark.locality!;
        }
        
        if (address.isEmpty) {
          // Fallback to coordinates if no address found
          address = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        }
        
        return address;
      }
    } catch (e) {
      print('Error getting address from coordinates: $e');
    }
    
    // Fallback to coordinates
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
      _showMatchingDrivers = false;
      _progressText = 'Getting coordinates...';
    });

    try {
      final routeData = await RouteService.calculateRoute(_fromLocation!, _toLocation!);
      final points = routeData['points'] as List<LatLng>? ?? [];
      final distance = routeData['distance'] as num? ?? 0;
      final duration = routeData['duration'] as num? ?? 0;
      final roadNames = routeData['roadNames'] as List<String>? ?? []; // ✨ NEW: Get road names from OSRM

      setState(() {
        _passengerRoutePoints = points;
        _distance = distance;
        _duration = duration;
        _roadNames = roadNames; // ✨ NEW: Store road names
        _progressText = 'Converting to road names...';
      });

      // Find matching drivers after calculating route
      // _findMatchingDrivers(); // This is now called after saving

      // Fit map to show the entire route
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
    if (_passengerRoutePoints.isEmpty) {
      if (mounted) {
      setState(() {
        _error = 'No route to save';
          _progressText = null;
      });
      }
      return;
    }

    if (mounted) {
    setState(() {
      _loading = true;
        _progressText = 'Saving route...';
    });
    }

    try {
      // Get address names for from and to locations
      String fromAddress = await _getAddressFromCoordinates(_fromLocation!);
      String toAddress = await _getAddressFromCoordinates(_toLocation!);

      // ✨ NEW: Use road names from OSRM instead of extracting them
      setState(() { _progressText = 'Processing road names...'; });
      final roadNames = _roadNames.isNotEmpty ? _roadNames : await FirebaseService.extractRoadNames(_passengerRoutePoints);
      setState(() { _progressText = 'Storing route in database...'; });
      // Delete previous routes for this passenger
      final existingRoutes = await FirebaseService.getRoutesByPassengerId(widget.passengerId);
      if (existingRoutes.isNotEmpty) {
        for (final route in existingRoutes) {
          final routeId = route['routeId'];
          await FirebaseService.firestore.collection('routes').doc(routeId).delete();
        }
      }
      String routeId = '${widget.passengerId}_${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseService.saveRouteData(
        routeId: routeId,
        routePoints: _passengerRoutePoints,
        distance: _distance,
        duration: _duration,
        fromLocation: fromAddress,
        toLocation: toAddress,
        roadNames: roadNames,
        passengerId: widget.passengerId,
      );

      if (mounted) {
      setState(() {
        _fromController.text = fromAddress;
        _toController.text = toAddress;
          _progressText = 'Done! Redirecting...';
      });
      }

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      }
    } catch (e) {
      if (mounted) {
      setState(() {
        _error = 'Error saving route: $e';
          _progressText = null;
      });
      }
    } finally {
      if (mounted) {
      setState(() {
        _loading = false;
      });
      }
    }
  }

  Future<void> _startChatWithDriver(Map<String, dynamic> driverRoute) async {
    try {
      final driverId = driverRoute['driverId'] as String? ?? '';
      final driverName = driverRoute['driverName'] as String? ?? 'Driver';
      final routeId = driverRoute['routeId'] as String? ?? '';
      final matchPercentage = driverRoute['matchPercentage'] as double? ?? 0.0;
      
      // Create or get existing chat
      final chatId = await ChatService.createChat(
        passengerId: widget.passengerId,
        passengerName: widget.passengerName,
        driverId: driverId,
        driverName: driverName,
        routeId: routeId,
        matchPercentage: matchPercentage,
      );

      // Navigate to chat
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatView(
              chatId: chatId,
              currentUserId: widget.passengerId,
              currentUserName: widget.passengerName,
              otherUserName: driverName,
              userRole: 'passenger',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error starting chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _calculateRouteAndSave() async {
    setState(() { _progressText = 'Starting route calculation...'; });
    await _calculateRoute();
    await _saveRoute();
    // After saving, go back to dashboard and update the route
    if (mounted) {
      setState(() { _progressText = null; });
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PassengerHomeView(
            passengerId: widget.passengerId,
            passengerName: widget.passengerName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Find Drivers - ${widget.passengerName}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Map and Driver List
          Column(
              children: [
          Expanded(
            child: Row(
                  children: [
                // Map
                    Expanded(
                  flex: 2,
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
                              // Get address for the tapped location and update the field
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
                          if (_passengerRoutePoints.isNotEmpty)
                            Polyline(
                              points: _passengerRoutePoints,
                              strokeWidth: 4,
                              color: Colors.green,
                            ),
                          if (_selectedDriverRoutePoints.isNotEmpty)
                            Polyline(
                              points: _selectedDriverRoutePoints,
                              strokeWidth: 4,
                              color: Colors.blue,
                            ),
                        ],
                      ),
                      MarkerLayer(markers: _markers),
                    ],
                  ),
                ),
                    // Driver List
                    if (_showMatchingDrivers && _matchingDriverRoutes.isNotEmpty) ...[
                      Expanded(
                        child: ListView.builder(
                          itemCount: _matchingDriverRoutes.length,
                          itemBuilder: (context, idx) {
                            final driver = _matchingDriverRoutes[idx];
                            final driverName = driver['driverName'] ?? 'Driver';
                            final driverId = driver['driverId'] ?? '';
                            final matchPercentage = driver['matchPercentage'] ?? 0.0;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              color: Colors.black,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[900],
                                  backgroundImage: (driver['profileImageUrl'] != null && (driver['profileImageUrl'] as String).isNotEmpty)
                                      ? NetworkImage(driver['profileImageUrl'])
                                      : null,
                                  child: (driver['profileImageUrl'] == null || (driver['profileImageUrl'] as String).isEmpty)
                                      ? const Icon(Icons.person, color: Colors.white, size: 24)
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(driverName, style: const TextStyle(color: Colors.white)),
                                    ),
                                    // Verification badge
                                    if (driver['isVerified'] == true)
                                      const VerificationBadge(isVerified: true, size: 16),
                                  ],
                                ),
                                subtitle: Text('Match: ${matchPercentage.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70)),
                                trailing: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => ProfileView(userId: driverId),
                                      ),
                                    );
                                  },
                                  child: const Text('View Profile'),
                                ),
                                onTap: () => _selectDriverRoute(driver),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
                          onPressed: _loading ? null : _calculateRouteAndSave,
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

  void _clearRoute() {
    setState(() {
      _fromController.clear();
      _toController.clear();
      _fromLocation = null;
      _toLocation = null;
      _passengerRoutePoints.clear();
      _markers.clear();
      _distance = 0;
      _duration = 0;
      _error = null;
      _matchingDriverRoutes.clear();
      _selectedDriverRoute = null;
      _selectedDriverRoutePoints.clear();
      _showMatchingDrivers = false;
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }
} 