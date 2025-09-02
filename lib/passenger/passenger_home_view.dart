import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firebase_service.dart';
import '../services/chat_service.dart';
import '../services/route_service.dart';
import '../views/chat_list_view.dart';
import '../views/chat_view.dart';
import 'passenger_search_view.dart';
import '../services/session_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../views/profile_view.dart';
import '../utils/color_utils.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../utils/tile_cache_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'passenger_active_contract_dashboard.dart';
import '../widgets/verification_badge.dart';



class PassengerHomeView extends StatefulWidget {
  final String passengerId;
  final String passengerName;
  final Map<String, dynamic>? profile;

  const PassengerHomeView({
    super.key,
    required this.passengerId,
    required this.passengerName,
    this.profile,
  });

  @override
  State<PassengerHomeView> createState() => _PassengerHomeViewState();
}

class _PassengerHomeViewState extends State<PassengerHomeView> {
  final MapController _mapController = MapController();
  final _tileProvider = FMTCTileProvider(
    stores: const {'mapStore': BrowseStoreStrategy.readUpdateCreate},
  );

  LatLng? _currentLocation;
  List<LatLng> _passengerRoutePoints = [];
  List<LatLng> _selectedDriverRoutePoints = [];
  List<Marker> _markers = [];
  bool _loading = false;
  bool _sidebarCollapsed = false;
  bool _isDriverSheetVisible = true;

  // Route info
  num _distance = 0;
  num _duration = 0;
  String _fromLocation = '';
  String _toLocation = '';

  // Driver routes
  List<Map<String, dynamic>> _allDriverRoutes = [];
  List<Map<String, dynamic>> _matchingDriverRoutes = [];
  Map<String, dynamic>? _selectedDriverRoute;

  List<Map<String, dynamic>> _acceptedOffers = [];
  Map<String, dynamic>? _acceptedDriverProfile;
  Map<String, dynamic>? _acceptedDriverRoute;
  Map<String, dynamic>? _acceptedOfferData;

  String? _driverContactNumber;
  bool _isDisposed = false;



  @override
  void initState() {
    super.initState();
    print('DEBUG: PassengerHomeView initState for passengerId: \'${widget.passengerId}\'');
    _getCurrentLocation();
    _loadPassengerRouteAndDrivers();
    _loadAcceptedOffersAndDriver();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Removed the calls to prevent infinite rebuilds
    // These methods are already called in initState()
  }

  @override
  void dispose() {
    _isDisposed = true;
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted || _isDisposed) return;
      if (!_isDisposed) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          if (_passengerRoutePoints.isEmpty) {
            _mapController.move(_currentLocation!, 13.0);
          }
        });
      }
    } catch (e) {
      if (!_isDisposed) {
        print('Error getting current location: $e');
      }
    }
  }

  Future<void> _loadPassengerRouteAndDrivers() async {
    if (!mounted || _isDisposed) return;
    setState(() { _loading = true; });
    try {
      // Load passenger's most recent route
      final routes = await FirebaseService.getRoutesByPassengerId(widget.passengerId);
      if (!mounted || _isDisposed) return;
      if (routes.isNotEmpty) {
        final latestRoute = routes.first;
        final routePoints = latestRoute['routePoints'] as List<dynamic>? ?? [];
        if (routePoints.isNotEmpty) {
          if (!_isDisposed) {
            setState(() {
              _passengerRoutePoints = routePoints.map((point) => LatLng(point['latitude'], point['longitude'])).toList();
            });
          }
          _distance = latestRoute['distance'] ?? 0;
          _duration = latestRoute['duration'] ?? 0;
          _fromLocation = latestRoute['fromLocation'] ?? '';
          _toLocation = latestRoute['toLocation'] ?? '';
          if (!_isDisposed) {
            _updateMarkers();
          }
        }
      }
      // Load all driver routes
      _allDriverRoutes = await FirebaseService.getAllDriverRoutes();
      if (!mounted || _isDisposed) return;
      // Find matching driver routes
      _matchingDriverRoutes = _findMatchingRoutes(_passengerRoutePoints, _allDriverRoutes);
      // If any, select the first by default
      if (_matchingDriverRoutes.isNotEmpty) {
        _selectDriverRoute(_matchingDriverRoutes.first);
      } else {
        _selectedDriverRoute = null;
        _selectedDriverRoutePoints = [];
      }
      if (!mounted || _isDisposed) return;
      if (!_isDisposed) {
        setState(() {});
        _updateMarkers();
        _fitMapToRoutes();
      }
      // After loading _passengerRoutePoints
      if (_passengerRoutePoints.isNotEmpty && !_isDisposed) {
        await TileCacheUtils.cacheRouteTiles(_passengerRoutePoints);
      }
    } catch (e) {
      if (!_isDisposed) {
        print('Error loading passenger/driver routes: $e');
      }
    } finally {
      if (!mounted || _isDisposed) return;
      if (!_isDisposed) {
        setState(() { _loading = false; });
      }
    }
  }



  Future<void> _loadAcceptedOffersAndDriver() async {
    if (!mounted || _isDisposed) return;
    // Fetch accepted offers for this passenger
    final offers = await ChatService.getOffersForPassenger(widget.passengerId, 'accepted');
    if (!mounted || _isDisposed) return;
    print('DEBUG: Offers for passenger ${widget.passengerId}: $offers');
    
    if (offers.isNotEmpty) {
      // Sort offers by timestamp descending
      offers.sort((a, b) {
        final tsA = a['timestamp'];
        final tsB = b['timestamp'];
        if (tsA is Timestamp && tsB is Timestamp) {
          return tsB.compareTo(tsA);
        }
        return 0;
      });
      final offer = offers.first;
      final chatId = offer['chatId'];
      final driverId = offer['offerData']?['driverId'] ?? offer['driverId'];
      final routeId = offer['offerData']?['routeId'] ?? offer['routeId'];
      print('DEBUG: driverId=$driverId, routeId=$routeId');
      if (driverId == null || routeId == null) {
        print('ERROR: driverId or routeId is null in accepted offer: $offer');
        return;
      }
      _acceptedOffers = offers;
      _acceptedOfferData = offer['offerData'];
      // Fetch driver profile
      final driverProfile = await FirebaseService.getRoutesByDriverId(driverId);
      if (!mounted || _isDisposed) return;
      print('DEBUG: Driver profile for $driverId: $driverProfile');
      _acceptedDriverProfile = driverProfile.isNotEmpty ? driverProfile.first : null;
      // Fetch driver route
      final driverRoute = await FirebaseService.getRouteById(routeId);
      if (!mounted || _isDisposed) return;
      print('DEBUG: Driver route for $routeId: $driverRoute');
      if (driverRoute != null) {
        print('DEBUG: routePoints field: ${driverRoute['routePoints']}');
        print('DEBUG: routePoints type: \'${driverRoute['routePoints']?.runtimeType}\'');
        if (driverRoute['routePoints'] is List) {
          print('DEBUG: routePoints length: ${(driverRoute['routePoints'] as List).length}');
        }
      }
      _acceptedDriverRoute = driverRoute;
      // Do NOT show driver's route on map anymore
      // if (driverRoute != null && driverRoute['routePoints'] != null) {
      //   setState(() {
      //     _selectedDriverRoutePoints = List<LatLng>.from(driverRoute['routePoints']);
      //   });
      // }
    } else {
      print('DEBUG: No accepted offers found for passenger ${widget.passengerId}');
      _acceptedOffers = [];
      _acceptedDriverProfile = null;
      _acceptedDriverRoute = null;
      _acceptedOfferData = null;
    }
    print('DEBUG: _acceptedDriverProfile: $_acceptedDriverProfile');
    print('DEBUG: _acceptedDriverRoute: $_acceptedDriverRoute');
    print('DEBUG: _acceptedOfferData: $_acceptedOfferData');
    if (!mounted || _isDisposed) return;
    if (!_isDisposed) {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _findMatchingRoutes(List<LatLng> passengerRoute, List<Map<String, dynamic>> driverRoutes) {
    const threshold = 0.2; // km
    final Distance dist = const Distance();
    List<Map<String, dynamic>> matches = [];
    
    for (final route in driverRoutes) {
      // Skip if this is the current passenger's own route
      final routeDriverId = route['driverId'] as String? ?? '';
      if (routeDriverId == widget.passengerId) {
        continue;
      }
      
      final points = (route['routePoints'] as List<dynamic>? ?? [])
          .map((p) => LatLng(p['latitude'], p['longitude']))
          .toList();
      
      // Calculate match percentage using the same algorithm as the test widget
      double matchPercentage = RouteService.calculateMatchPercentage(points, passengerRoute);
      
      if (matchPercentage > 0) {
        // Add match percentage to route data
        final routeWithMatch = Map<String, dynamic>.from(route);
        routeWithMatch['matchPercentage'] = matchPercentage;
        matches.add(routeWithMatch);
      }
    }
    
    // Sort by match percentage (highest first)
    matches.sort((a, b) => (b['matchPercentage'] as double).compareTo(a['matchPercentage'] as double));
    
    return matches;
  }





  void _selectDriverRoute(Map<String, dynamic> route) {
    if (!mounted || _isDisposed) return;
    if (!_isDisposed) {
      setState(() {
        _selectedDriverRoute = route;
        _selectedDriverRoutePoints = (route['routePoints'] as List<dynamic>? ?? [])
            .map((p) => LatLng(p['latitude'], p['longitude']))
            .toList();
      });
    }
    if (mounted && !_isDisposed) {
      _updateMarkers();
      _fitMapToRoutes();
    }
  }

  void _fitMapToRoutes() {
    if (!mounted || _isDisposed) return;
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
      if (!_isDisposed) {
        _mapController.move(LatLng(centerLat, centerLng), 12.0);
      }
    }
  }

  void _updateMarkers() {
    if (!mounted || _isDisposed) return;
    _markers.clear();
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



  void _navigateToSearch() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PassengerSearchView(
          passengerId: widget.passengerId,
          passengerName: widget.passengerName,
        ),
      ),
    );
    if (result == true && mounted && !_isDisposed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updating dashboard with new route...'), duration: Duration(seconds: 1)),
      );
      if (!_isDisposed) {
        setState(() { _loading = true; });
      }
      await _loadPassengerRouteAndDrivers();
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dashboard updated with latest route!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
        );
      }
    }
  }

  void _navigateToChats() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatListView(
          userId: widget.passengerId,
          userName: widget.passengerName,
          userRole: 'passenger',
        ),
      ),
    );
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
      if (mounted && !_isDisposed) {
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
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Add a method to fetch driver contact number
  Future<String> _fetchDriverContact(String driverId) async {
    try {
      final profile = await ChatService.getPassengerProfile(driverId);
      return profile?['number'] ?? '';
    } catch (e) {
      if (!_isDisposed) {
        print('Error fetching driver contact: $e');
      }
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final double sheetHeight = _isDriverSheetVisible
        ? (4 * 72.0 + 32.0) // 4 cards + padding/arrow
        : 0.0;
    return Scaffold(
      backgroundColor: ColorUtils.matteBlack,
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 2), // Minimal space at the top
              // From/To location row (like driver dashboard)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 1,
                          offset: const Offset(0, 1),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // From location
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _fromLocation.isNotEmpty ? _fromLocation : 'From',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Arrow separator
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade600,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                        
                        // To location
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _toLocation.isNotEmpty ? _toLocation : 'To',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? const LatLng(33.6844, 73.0479),
                    initialZoom: 13.0,
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
                        // Optionally, show driver's route polyline:
                        if (_selectedDriverRoutePoints.isNotEmpty)
                          Polyline(
                            points: _selectedDriverRoutePoints,
                            strokeWidth: 4,
                            color: Colors.blue,
                          ),
                      ],
                    ),
                    MarkerLayer(
                      markers: _markers,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          // Minimal, toggleable bottom sheet for matching drivers
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: _isDriverSheetVisible ? 0 : -sheetHeight - 32,
            height: sheetHeight,
            child: IgnorePointer(
              ignoring: !_isDriverSheetVisible,
              child: Container(
                decoration: const BoxDecoration(
                  color: ColorUtils.matteBlack,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 12,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _isDriverSheetVisible = false),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Icon(Icons.keyboard_arrow_down, color: ColorUtils.softWhite, size: 32),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8, left: 8, right: 8),
                        itemCount: _matchingDriverRoutes.where((route) => route['driverId'] != widget.passengerId).take(10).length,
                        itemBuilder: (context, idx) {
                          // Only show drivers, never the passenger's own route
                          final filteredRoutes = _matchingDriverRoutes.where((route) => route['driverId'] != widget.passengerId).toList();
                          if (idx >= filteredRoutes.length) return const SizedBox.shrink();
                          final route = filteredRoutes[idx];
                          final driverName = route['driverName'] ?? 'Driver';
                          final from = route['fromLocation'] ?? '';
                          final to = route['toLocation'] ?? '';
                          final matchPercentage = route['matchPercentage'] ?? 0.0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[700]!, width: 1),
                              ),
                              child: ListTile(
                                tileColor: Colors.transparent,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[800],
                                  backgroundImage: (route['profileImageUrl'] != null && (route['profileImageUrl'] as String).isNotEmpty)
                                      ? NetworkImage(route['profileImageUrl'])
                                      : null,
                                  child: (route['profileImageUrl'] == null || (route['profileImageUrl'] as String).isEmpty)
                                      ? const Icon(Icons.person, color: ColorUtils.softWhite, size: 24)
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        driverName,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                                      ),
                                    ),
                                    // Verification badge
                                    if (route['isVerified'] == true)
                                      const VerificationBadge(isVerified: true, size: 16),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('From: $from', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 13)),
                                    Text('To: $to', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500, fontSize: 13)),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green.withOpacity(0.5), width: 1),
                                      ),
                                      child: Text(
                                        '${matchPercentage.toStringAsFixed(1)}%',
                                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(Icons.chat, color: Colors.blue),
                                        tooltip: 'Chat with driver',
                                        onPressed: () => _startChatWithDriver(route),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () => _selectDriverRoute(route),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Mini floating button to bring the sheet back up
          if (!_isDriverSheetVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80, // just above nav bar
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _isDriverSheetVisible = true),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Icon(Icons.keyboard_arrow_up, color: ColorUtils.softWhite, size: 28),
                  ),
                ),
              ),
            ),
          if (_loading)
            const Positioned(
              top: 100,
              right: 20,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Loading routes...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),



      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // View Active Contract Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PassengerActiveContractDashboard(
                      passengerId: widget.passengerId,
                      passengerName: widget.passengerName,
                      profile: widget.profile,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.assignment_turned_in),
              label: const Text('View Active Contract'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          CustomBottomNavBar(
            selectedIndex: 1,
            onChat: _navigateToChats,
            onSetRoute: _navigateToSearch,
            onProfile: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfileView(userId: widget.passengerId),
                ),
              );
            },
          ),
        ],
      ),

    );
  }
} 