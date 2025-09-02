import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/firebase_service.dart';
import '../services/chat_service.dart';
import 'driver_search_view.dart';
import '../views/chat_list_view.dart';
import '../services/session_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../views/profile_view.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import '../utils/tile_cache_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'driver_accepted_passenger_panel.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverHomeView extends StatefulWidget {
  final String driverId;
  final String driverName;
  final Map<String, dynamic>? profile;
  
  const DriverHomeView({
    super.key,
    required this.driverId,
    required this.driverName,
    this.profile,
  });

  @override
  State<DriverHomeView> createState() => _DriverHomeViewState();
}

class _DriverHomeViewState extends State<DriverHomeView> {
  final MapController _mapController = MapController();
  final _tileProvider = FMTCTileProvider(
    stores: const {'mapStore': BrowseStoreStrategy.readUpdateCreate},
  );
  
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];
  List<Marker> _markers = [];
  
  bool _loading = false;
  bool _sidebarCollapsed = false;
  
  // Route information
  num _distance = 0;
  num _duration = 0;
  String _fromLocation = '';
  String _toLocation = '';
  
  // Accepted passengers
  List<Map<String, dynamic>> _acceptedPassengers = [];
  Map<String, List<LatLng>> _passengerRoutes = {};
  Map<String, Marker> _passengerMarkers = {};

  // --- NEW: Selected passenger state ---
  String? _selectedPassengerId;
  List<LatLng> _selectedPassengerRoutePoints = [];
  LatLng? _selectedPassengerFrom;
  LatLng? _selectedPassengerTo;
  // --- END NEW ---

  // Add state variable for panel
  bool _isPassengerPanelOpen = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadSavedRoute();
    _loadAcceptedPassengers();
    
    // Set up periodic refresh every 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _refreshDashboard();
      }
    });
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
      setState(() {
        _loading = true;
      });
      
      // Load the driver's most recent route
      final routes = await FirebaseService.getRoutesByDriverId(widget.driverId);
      if (routes.isNotEmpty) {
        // Get the most recent route
        final latestRoute = routes.first;
        final routePoints = latestRoute['routePoints'] as List<dynamic>? ?? [];
        
        if (routePoints.isNotEmpty) {
          setState(() {
            _routePoints = routePoints.map((point) => 
                LatLng(point['latitude'], point['longitude'])).toList();
            _distance = latestRoute['distance'] ?? 0;
            _duration = latestRoute['duration'] ?? 0;
            _fromLocation = latestRoute['fromLocation'] ?? '';
            _toLocation = latestRoute['toLocation'] ?? '';
          });
          
          // Set markers for start and end points
          if (_routePoints.isNotEmpty) {
            final fromLocation = _routePoints.first;
            final toLocation = _routePoints.last;
            _updateMarkers(fromLocation, toLocation);
            
            // Fit map to show the route
            _fitMapToRoute();
          }
        }
      }
    } catch (e) {
      print('Error loading saved route: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
    // After loading _routePoints
    if (_routePoints.isNotEmpty) {
      await TileCacheUtils.cacheRouteTiles(_routePoints);
    }
  }

  void _fitMapToRoute() {
    if (_routePoints.isNotEmpty) {
      // Calculate bounds manually and move to center
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

  void _updateMarkers(LatLng fromLocation, LatLng toLocation) {
    _markers.clear();
    
    // Add start marker
    _markers.add(
      Marker(
        point: fromLocation,
        width: 40,
        height: 40,
        child: const Icon(
          Icons.location_on,
          color: Colors.green,
          size: 40,
        ),
      ),
    );
    
    // Add end marker
    _markers.add(
      Marker(
        point: toLocation,
        width: 40,
        height: 40,
        child: const Icon(
          Icons.location_on,
          color: Colors.red,
          size: 40,
        ),
      ),
    );
  }

  void _toggleSidebar() {
    setState(() {
      _sidebarCollapsed = !_sidebarCollapsed;
    });
  }

  // Helper function to get day initials
  String _getDayInitial(String day) {
    switch (day.toLowerCase()) {
      case 'monday': return 'M';
      case 'tuesday': return 'T';
      case 'wednesday': return 'W';
      case 'thursday': return 'T';
      case 'friday': return 'F';
      case 'saturday': return 'S';
      case 'sunday': return 'S';
      default: return day.substring(0, 1).toUpperCase();
    }
  }

  Future<void> _loadAcceptedPassengers() async {
    try {
      setState(() {
        _loading = true;
      });

      // Get accepted offers for this driver
      final acceptedOffers = await ChatService.getOffersForDriver(widget.driverId, 'accepted');
      // Only keep the most recent accepted contract per passenger
      Map<String, Map<String, dynamic>> latestOffersByPassenger = {};
      for (final offer in acceptedOffers) {
        final passengerId = offer['passengerId'] as String;
        final timestamp = offer['timestamp'];
        if (!latestOffersByPassenger.containsKey(passengerId) ||
            (timestamp != null && (latestOffersByPassenger[passengerId]?['timestamp'] ?? Timestamp(0,0)).compareTo(timestamp) < 0)) {
          latestOffersByPassenger[passengerId] = offer;
        }
      }
      final uniqueAcceptedOffers = latestOffersByPassenger.values.toList();
      // Load passenger profiles for each accepted offer
      List<Map<String, dynamic>> passengersWithProfiles = [];
      for (final offer in uniqueAcceptedOffers) {
        final passengerId = offer['passengerId'] as String;
        // Get passenger profile data
        final passengerProfile = await ChatService.getPassengerProfile(passengerId);
        // Combine offer data with profile data
        final passengerData = {
          ...offer,
          'passengerProfile': passengerProfile ?? {},
        };
        passengersWithProfiles.add(passengerData);
      }
      setState(() {
        _acceptedPassengers = passengersWithProfiles;
      });

      // Load passenger routes and create markers
      for (final offer in passengersWithProfiles) {
        final passengerId = offer['passengerId'] as String;
        final passengerName = offer['passengerName'] as String;
        
        // Get passenger route
        final passengerRoute = await ChatService.getPassengerRoute(passengerId);
        if (passengerRoute != null) {
          final routePoints = (passengerRoute['routePoints'] as List<dynamic>? ?? [])
              .map((p) => LatLng(p['latitude'], p['longitude']))
              .toList();
          
          if (routePoints.isNotEmpty) {
            setState(() {
              _passengerRoutes[passengerId] = routePoints;
              
              // Create passenger marker (start point of their route)
              _passengerMarkers[passengerId] = Marker(
                point: routePoints.first,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.purple,
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
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              );
            });
          }
        }
      }

      // Update map to show all routes
      _updateMapWithPassengers();
    } catch (e) {
      print('Error loading accepted passengers: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildPassengerCard(Map<String, dynamic> passenger) {
    final passengerProfile = passenger['passengerProfile'] as Map<String, dynamic>? ?? {};
    final passengerName = passenger['passengerName'] as String? ?? 'Passenger';
    final offerData = passenger['offerData'] as Map<String, dynamic>? ?? {};
    final passengerId = passenger['passengerId'] as String?;
    // Extract offer details
    final selectedDays = (offerData['selectedDays'] as List<dynamic>? ?? []).cast<String>();
    final seatCountRaw = offerData['seatCount'];
    final seatCount = seatCountRaw is int ? seatCountRaw : (seatCountRaw is double ? seatCountRaw.toInt() : 1);
    final pricePerDayRaw = offerData['pricePerDay'];
    final pricePerDay = pricePerDayRaw is int ? pricePerDayRaw.toDouble() : (pricePerDayRaw as double? ?? 0.0);
    final isOneWay = offerData['isOneWay'] as bool? ?? true;
    final pickupTime = offerData['pickupTime'] as String? ?? '08:00';
    final dropTime = offerData['dropTime'] as String? ?? '17:00';
    // Calculate total price
    final totalPrice = pricePerDay * selectedDays.length * seatCount;

    return GestureDetector(
      onTap: () async {
        if (_selectedPassengerId == passengerId) {
          setState(() {
            _selectedPassengerId = null;
            _selectedPassengerRoutePoints = [];
            _selectedPassengerFrom = null;
            _selectedPassengerTo = null;
          });
        } else {
          final routePoints = _passengerRoutes[passengerId] ?? [];
          setState(() {
            _selectedPassengerId = passengerId;
            _selectedPassengerRoutePoints = routePoints;
            _selectedPassengerFrom = routePoints.isNotEmpty ? routePoints.first : null;
            _selectedPassengerTo = routePoints.isNotEmpty ? routePoints.last : null;
          });
          if (routePoints.isNotEmpty) {
            double minLat = routePoints.first.latitude;
            double maxLat = routePoints.first.latitude;
            double minLng = routePoints.first.longitude;
            double maxLng = routePoints.first.longitude;
            for (final point in routePoints) {
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
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedPassengerId == passengerId ? Colors.orange : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with passenger info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: passengerProfile['profileImageUrl'] != null && passengerProfile['profileImageUrl'].toString().isNotEmpty
                          ? NetworkImage(passengerProfile['profileImageUrl'])
                          : null,
                      backgroundColor: Colors.grey[300],
                      child: passengerProfile['profileImageUrl'] == null || passengerProfile['profileImageUrl'].toString().isEmpty
                          ? const Icon(Icons.person, color: Colors.grey, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            passengerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (passengerProfile['number'] != null)
                            Text(
                              '📞 ${passengerProfile['number']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'profile':
                            _showPassengerProfile(passenger);
                            break;
                          case 'complete':
                            _showCompleteTripConfirmation(passenger);
                            break;
                          case 'delete':
                            _showDeleteConfirmation(passenger);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 16),
                              SizedBox(width: 8),
                              Text('View Profile'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'complete',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, size: 16, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Complete Trip', style: TextStyle(color: Colors.green)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('End Contract', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      child: const Icon(Icons.more_vert, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Quick info row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOneWay ? 'One Way' : 'Two Way',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.airline_seat_recline_normal, size: 14, color: Colors.purple),
                    const SizedBox(width: 2),
                    Text(
                      '$seatCount seat${seatCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.purple[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${totalPrice.toStringAsFixed(0)} PKR',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Time info
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.orange[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Pickup: $pickupTime',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (!isOneWay) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.access_time, size: 12, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Drop: $dropTime',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                // Days info
                if (selectedDays.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          selectedDays.map((day) => _getDayInitial(day)).join(', '),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateMapWithPassengers() {
    // Combine driver route markers with passenger markers
    final allMarkers = <Marker>[];
    
    // Add driver route markers
    allMarkers.addAll(_markers);
    
    // Add passenger markers
    allMarkers.addAll(_passengerMarkers.values);
    
    setState(() {
      _markers = allMarkers;
    });
    
    // Fit map to show all routes
    _fitMapToAllRoutes();
  }

  void _fitMapToAllRoutes() {
    final allPoints = <LatLng>[];
    
    // Add driver route points
    allPoints.addAll(_routePoints);
    
    // Add passenger route points
    for (final routePoints in _passengerRoutes.values) {
      allPoints.addAll(routePoints);
    }
    
    if (allPoints.isNotEmpty) {
      // Calculate bounds for all points
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

  // Helper method to get left margin for passenger list based on sidebar state
  double _getPassengerListLeftMargin() {
    return _sidebarCollapsed ? 80.0 : 300.0;
  }

  // Refresh dashboard data
  Future<void> _refreshDashboard() async {
      setState(() {
        _loading = true;
      });
      
    try {
      await Future.wait([
        _loadSavedRoute(),
        _loadAcceptedPassengers(),
      ]);
    } catch (e) {
      print('Error refreshing dashboard: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Navigate to chats
  void _navigateToChats() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatListView(
          userId: widget.driverId,
          userRole: 'driver',
          userName: widget.driverName,
        ),
      ),
    );
  }

  // Show passenger profile
  void _showPassengerProfile(Map<String, dynamic> passenger) {
    final passengerProfile = passenger['passengerProfile'] as Map<String, dynamic>? ?? {};
    final passengerName = passenger['passengerName'] as String? ?? 'Passenger';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Passenger Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: passengerProfile['profileImageUrl'] != null && passengerProfile['profileImageUrl'].toString().isNotEmpty
                      ? NetworkImage(passengerProfile['profileImageUrl'])
                      : null,
                  backgroundColor: Colors.grey[300],
                  child: passengerProfile['profileImageUrl'] == null || passengerProfile['profileImageUrl'].toString().isEmpty
                      ? const Icon(Icons.person, color: Colors.grey, size: 30)
                      : null,
                ),
                const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                        passengerName,
                style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                ),
              ),
                      if (passengerProfile['number'] != null)
              Text(
                          '📞 ${passengerProfile['number']}',
                          style: TextStyle(
                  fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (passengerProfile['email'] != null)
                        Text(
                          '📧 ${passengerProfile['email']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Show complete trip confirmation
  void _showCompleteTripConfirmation(Map<String, dynamic> passenger) {
    final passengerName = passenger['passengerName'] as String? ?? 'Passenger';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Trip'),
        content: Text('Are you sure you want to mark the trip with $passengerName as completed? This will allow the passenger to review you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _completeTrip(passenger);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Complete Trip'),
          ),
        ],
      ),
    );
  }

  // Show delete confirmation
  void _showDeleteConfirmation(Map<String, dynamic> passenger) {
    final passengerName = passenger['passengerName'] as String? ?? 'Passenger';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
          title: const Text('End Contract'),
        content: Text('Are you sure you want to end the contract with $passengerName? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              _deleteAcceptedOffer(passenger);
              },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('End Contract'),
            ),
          ],
      ),
    );
  }

  // Complete trip
  Future<void> _completeTrip(Map<String, dynamic> passenger) async {
    try {
      setState(() {
        _loading = true;
      });

      final chatId = passenger['chatId'] as String;
      final messageId = passenger['messageId'] as String;
      final passengerId = passenger['passengerId'] as String;
      final passengerName = passenger['passengerName'] as String;

      await ChatService.completeTrip(
        chatId: chatId,
        messageId: messageId,
        driverId: widget.driverId,
        driverName: widget.driverName,
        passengerId: passengerId,
        passengerName: passengerName,
      );

      // Remove from local list since trip is completed
      setState(() {
        _acceptedPassengers.removeWhere((p) => p['chatId'] == chatId);
        _passengerRoutes.remove(passengerId);
        _passengerMarkers.remove(passengerId);
      });

      // Update map
      _updateMapWithPassengers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trip completed with $passengerName! Passenger can now review you.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing trip: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Delete accepted offer
  Future<void> _deleteAcceptedOffer(Map<String, dynamic> passenger) async {
    try {
      setState(() {
        _loading = true;
      });

      final chatId = passenger['chatId'] as String;
      final messageId = passenger['messageId'] as String;
      final passengerId = passenger['passengerId'] as String;
      final passengerName = passenger['passengerName'] as String;

      await ChatService.deleteAcceptedOffer(
        chatId: chatId,
        messageId: messageId,
        driverId: widget.driverId,
        driverName: widget.driverName,
        passengerId: passengerId,
        passengerName: passengerName,
      );

      // Remove from local list
      setState(() {
        _acceptedPassengers.removeWhere((p) => p['chatId'] == chatId);
        _passengerRoutes.remove(passengerId);
        _passengerMarkers.remove(passengerId);
      });

      // Update map
      _updateMapWithPassengers();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Contract ended with $passengerName'),
          backgroundColor: Colors.orange,
          ),
        );
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ending contract: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _navigateToSearch() async {
    // Navigate to search view and wait for result
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DriverSearchView(
          driverId: widget.driverId,
          driverName: widget.driverName,
        ),
      ),
    );
    
    // If we get back a result indicating route was updated, refresh the dashboard
    if (result == true) {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updating dashboard with new route...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Set loading state
      setState(() {
        _loading = true;
      });
      
      // Reload the saved route
      await _loadSavedRoute();
      _fitMapToRoute();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dashboard updated with latest route!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildSelectedPassengerBar() {
    if (_selectedPassengerId == null || _selectedPassengerFrom == null) return const SizedBox.shrink();
    final passenger = _acceptedPassengers.firstWhere(
      (p) => p['passengerId'] == _selectedPassengerId,
      orElse: () => <String, dynamic>{},
    );
    if (passenger.isEmpty) return const SizedBox.shrink();
    final offerData = passenger['offerData'] as Map<String, dynamic>? ?? {};
    final pickupLocation = _fromLocation.isNotEmpty ? _fromLocation : 'Pickup';
    final pickupTime = offerData['pickupTime'] ?? '--:--';
    final seats = offerData['seatCount']?.toString() ?? '1';
    final pricePerDay = offerData['pricePerDay']?.toString() ?? '0';
    final selectedDays = (offerData['selectedDays'] as List<dynamic>? ?? []).length;
    final totalPrice = (offerData['pricePerDay'] ?? 0) * (offerData['seatCount'] ?? 1) * selectedDays;
    final driverLat = _currentLocation?.latitude ?? 0.0;
    final driverLng = _currentLocation?.longitude ?? 0.0;
    final pickupLat = _selectedPassengerFrom?.latitude ?? 0.0;
    final pickupLng = _selectedPassengerFrom?.longitude ?? 0.0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.blueAccent, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pickup Location:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(pickupLocation, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text('Time of pickup: $pickupTime', style: const TextStyle(fontSize: 13)),
                Text('Seats: $seats', style: const TextStyle(fontSize: 13)),
                Text('Per day price: $pricePerDay', style: const TextStyle(fontSize: 13)),
                Text('Total price: $totalPrice', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          GoogleMapsButton(
            latitude1: driverLat,
            longitude1: driverLng,
            latitude2: pickupLat,
            longitude2: pickupLng,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    double buttonSize = 56;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              await _loadSavedRoute();
              _fitMapToRoute();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Route refreshed!'), backgroundColor: Colors.blue),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: Stack(
          children: [
            // Main content (map, etc.)
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      FlutterMap(
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
                              if (_selectedPassengerId != null && _selectedPassengerRoutePoints.isNotEmpty)
                                Polyline(
                                  points: _selectedPassengerRoutePoints,
                                  strokeWidth: 4,
                                  color: Colors.orange,
                                )
                              else if (_routePoints.isNotEmpty)
                                Polyline(
                                  points: _routePoints,
                                  strokeWidth: 4,
                                  color: Colors.blue,
                                ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              if (_selectedPassengerId != null) ...[
                                // Show selected passenger's marker with enhanced styling
                                if (_passengerMarkers.containsKey(_selectedPassengerId))
                                  Marker(
                                    point: _passengerMarkers[_selectedPassengerId]!.point,
                                    width: 50,
                                    height: 50,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.orange.withOpacity(0.5),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                // Show start point marker
                                if (_selectedPassengerFrom != null)
                                  Marker(
                                    point: _selectedPassengerFrom!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                                  ),
                                // Show end point marker
                                if (_selectedPassengerTo != null)
                                  Marker(
                                    point: _selectedPassengerTo!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                                  ),
                              ] else ..._markers,
                            ],
                          ),
                        ],
                      ),
                      if (_routePoints.isNotEmpty && !_loading)
                        Positioned(
                          top: 32,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              constraints: const BoxConstraints(maxWidth: 420),
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
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Right-side fixed button to open passenger panel
            Positioned(
              top: 120,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.arrow_left, color: Colors.black, size: 32),
                onPressed: () {
                  setState(() {
                    _isPassengerPanelOpen = true;
                  });
                },
                tooltip: 'Show Accepted Passengers',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 4,
                ),
              ),
            ),
            // Animated side panel for accepted passengers
            DriverAcceptedPassengerPanel(
              isOpen: _isPassengerPanelOpen,
              onClose: () => setState(() => _isPassengerPanelOpen = false),
              onRefresh: _loadAcceptedPassengers,
              acceptedPassengers: _acceptedPassengers,
              buildPassengerCard: (Map<String, dynamic> p) => _buildPassengerCard(p),
            ),
            // Add the selected passenger bar above the navigation bar
            if (_selectedPassengerId != null && _selectedPassengerFrom != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 70, // above the nav bar
                child: _buildSelectedPassengerBar(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        selectedIndex: 1,
        onChat: _navigateToChats,
        onSetRoute: _navigateToSearch,
        onProfile: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProfileView(userId: widget.driverId),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
} 

// GoogleMapsButton widget
class GoogleMapsButton extends StatelessWidget {
  final double latitude1;
  final double longitude1;
  final double latitude2;
  final double longitude2;

  const GoogleMapsButton({
    Key? key,
    required this.latitude1,
    required this.longitude1,
    required this.latitude2,
    required this.longitude2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final intentUrl = 'intent://maps.google.com/maps?daddr=$latitude2,$longitude2&directionsmode=driving#Intent;scheme=https;package=com.google.android.apps.maps;end';
        final webUrl = 'https://www.google.com/maps/dir/$latitude1,$longitude1/$latitude2,$longitude2';
        final intentUri = Uri.parse(intentUrl);
        final webUri = Uri.parse(webUrl);
        if (await canLaunchUrl(intentUri)) {
          await launchUrl(intentUri, mode: LaunchMode.externalApplication);
        } else if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch Google Maps')),
          );
        }
      },
      child: const Text('Open in Google Maps'),
    );
  }
} 