import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/firebase_service.dart';
import '../widgets/shared_map_widget.dart';
import '../widgets/route_info_widget.dart';
import '../widgets/route_setup_widget.dart';
import 'dart:math';

class PassengerView extends StatefulWidget {
  const PassengerView({super.key});

  @override
  State<PassengerView> createState() => _PassengerViewState();
}

class _PassengerViewState extends State<PassengerView> {
  // Passenger route data
  LatLng? passengerFrom;
  LatLng? passengerTo;
  var passengerPoints = <LatLng>[];
  num passengerDistance = 0.0;
  num passengerDuration = 0.0;
  List<String> passengerRoadNames = [];
  
  // Controllers
  final TextEditingController _passengerFromController = TextEditingController();
  final TextEditingController _passengerToController = TextEditingController();
  
  // UI state
  final MapController _mapController = MapController();
  bool _isLoading = false;
  bool _isMapSelectionMode = false;
  String? _currentSelectionField;
  
  // Driver routes for comparison
  List<Map<String, dynamic>> driverRoutes = [];
  Map<String, dynamic>? selectedDriverRoute;
  double? commonRoutePercentage;
  Map<String, List<LatLng>> convertedDriverRoutes = {};

  @override
  void dispose() {
    _passengerFromController.dispose();
    _passengerToController.dispose();
    super.dispose();
  }

  Future<void> _searchAndCalculatePassengerRoute(bool isFrom) async {
    final controller = isFrom ? _passengerFromController : _passengerToController;
    
    if (controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Search for location
      final location = await LocationService.searchLocation(controller.text);
      if (location == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location not found')),
        );
        setState(() => _isLoading = false);
        return;
      }
      
      // Set location
      setState(() {
        if (isFrom) {
          passengerFrom = location;
        } else {
          passengerTo = location;
        }
      });
      
      _mapController.move(location, 15.0);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location set: ${controller.text}')),
      );
      
      // If both locations are set, calculate route and search for matching drivers
      if (passengerFrom != null && passengerTo != null) {
        await _calculatePassengerRouteAndSearchDrivers();
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error searching location')),
      );
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _calculatePassengerRouteAndSearchDrivers() async {
    if (passengerFrom == null || passengerTo == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Calculate passenger route
      final routeData = await RouteService.calculateRoute(passengerFrom!, passengerTo!);
      passengerDistance = routeData['distance'];
      passengerDuration = routeData['duration'];
      passengerPoints = routeData['points'];
      
      // Extract road names from passenger route using reverse geocoding
      passengerRoadNames = await FirebaseService.extractRoadNames(passengerPoints);
      
      // Search for matching driver routes based on road names
      driverRoutes = await FirebaseService.searchRoutesByRoadNames(passengerRoadNames);
      
      // Calculate common route percentages for all driver routes
      for (var driverRoute in driverRoutes) {
        if (driverRoute['roadNames'] != null) {
          List<String> driverRoadNames = List<String>.from(driverRoute['roadNames']);
          double percentage = FirebaseService.calculateCommonRoutePercentage(
            passengerRoadNames, 
            driverRoadNames
          );
          driverRoute['commonPercentage'] = percentage;
        } else {
          driverRoute['commonPercentage'] = 0.0;
        }
      }
      
      // Sort driver routes by common percentage (highest first)
      driverRoutes.sort((a, b) => (b['commonPercentage'] ?? 0.0).compareTo(a['commonPercentage'] ?? 0.0));
      
      // Convert driver routes to the format expected by the map widget
      if (driverRoutes.isNotEmpty) {
        _convertDriverRoutesToMap();
      } else {
        convertedDriverRoutes.clear();
      }
      
      setState(() {});
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Passenger route calculated! Found ${driverRoutes.length} matching driver routes\nFrom: ${passengerFrom?.latitude}, ${passengerFrom?.longitude}\nTo: ${passengerTo?.latitude}, ${passengerTo?.longitude}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to calculate passenger route')),
      );
    }
    
    setState(() => _isLoading = false);
  }

  void _selectDriverRoute(Map<String, dynamic> driverRoute) {
    setState(() {
      selectedDriverRoute = driverRoute;
      commonRoutePercentage = driverRoute['commonPercentage'] ?? 0.0;
    });
  }

  void _enableMapSelection(String fieldName) {
    setState(() {
      _isMapSelectionMode = true;
      _currentSelectionField = fieldName;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Click on the map to set ${fieldName.toLowerCase()} location'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) async {
    if (!_isMapSelectionMode || _currentSelectionField == null) return;
    
    setState(() {
      if (_currentSelectionField == 'passengerFrom') {
        passengerFrom = point;
        _passengerFromController.text = '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
      } else if (_currentSelectionField == 'passengerTo') {
        passengerTo = point;
        _passengerToController.text = '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
      }
      
      _isMapSelectionMode = false;
      _currentSelectionField = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location set: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}'),
        duration: const Duration(seconds: 2),
      ),
    );
    
    // If both locations are set, calculate route and search for matching drivers
    if (passengerFrom != null && passengerTo != null) {
      await _calculatePassengerRouteAndSearchDrivers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Passenger Route Setup'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            RouteSetupWidget(
              role: 'passenger',
              userId: '', // TODO: Pass actual passenger ID if available
              userName: '', // TODO: Pass actual passenger name if available
              onRouteSaved: (routeData) {
                // Optionally update state or refresh
                // setState(() {});
              },
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseService.deleteAllRoutes();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All routes deleted!')),
                    );
                    setState(() {
                      driverRoutes.clear();
                      convertedDriverRoutes.clear();
                      selectedDriverRoute = null;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete All Routes'),
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  // Left Panel - Passenger Route Setup and Driver Results
                  Container(
                    width: 400,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Passenger Route Setup Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Passenger Route Setup',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Enter your pick-up and drop-off locations',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Pick-up location
                                _buildLocationInput(
                                  icon: Icons.location_on,
                                  label: 'Pick-up Location',
                                  controller: _passengerFromController,
                                  fieldName: 'passengerFrom',
                                  onSearch: () => _searchAndCalculatePassengerRoute(true),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Drop-off location
                                _buildLocationInput(
                                  icon: Icons.location_on_outlined,
                                  label: 'Drop-off Location',
                                  controller: _passengerToController,
                                  fieldName: 'passengerTo',
                                  onSearch: () => _searchAndCalculatePassengerRoute(false),
                                ),
                                
                                const SizedBox(height: 24),
                                
                                // Calculate route button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _isLoading || passengerFrom == null || passengerTo == null 
                                        ? null 
                                        : _calculatePassengerRouteAndSearchDrivers,
                                    icon: const Icon(Icons.route),
                                    label: const Text('Calculate Route & Find Drivers'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Driver Routes Results
                        if (driverRoutes.isNotEmpty) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Matching Driver Routes',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Found ${driverRoutes.length} driver routes with common roads',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 200,
                                    child: ListView.builder(
                                      itemCount: driverRoutes.length,
                                      itemBuilder: (context, index) {
                                        final driverRoute = driverRoutes[index];
                                        if (driverRoute == null) return const SizedBox.shrink();
                                        
                                        final percentage = driverRoute['commonPercentage'] ?? 0.0;
                                        final markerColor = driverRoute['markerColor'] as Color? ?? Colors.blue;
                                        final isSelected = selectedDriverRoute == driverRoute;
                                        
                                        return Card(
                                          color: isSelected ? markerColor.withOpacity(0.1) : null,
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: markerColor,
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            ),
                                            title: Text(
                                              '${driverRoute['driverName'] ?? 'Driver'} Route',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            subtitle: Text(
                                              '${((driverRoute['distance'] ?? 0.0) / 1000).toStringAsFixed(1)} km • ${((driverRoute['duration'] ?? 0.0) / 60).toStringAsFixed(1)} min',
                                            ),
                                            trailing: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getPercentageColor(percentage),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${percentage.toStringAsFixed(1)}%',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            onTap: () => _selectDriverRoute(driverRoute),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        
                        // No matching drivers message
                        if (driverRoutes.isEmpty && passengerFrom != null && passengerTo != null) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No Matching Driver Routes',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No driver routes found with common roads for your route.',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        
                        // Help message for route comparison
                        if (driverRoutes.isNotEmpty && selectedDriverRoute == null) ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Route Comparison Available',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap on any driver route above to see detailed comparison with your route.',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // Route Info Panel
                        if (selectedDriverRoute != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.compare_arrows, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Route Comparison Active',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 300, // Fixed height instead of Expanded
                            child: SingleChildScrollView(
                              child: RouteInfoWidget(
                                selectedDriver: null,
                                driverPoints: _ensureLatLngList(selectedDriverRoute!['routePoints']),
                                passengerPoints: _ensureLatLngList(passengerPoints),
                                driverDistance: selectedDriverRoute!['distance'] ?? 0.0,
                                driverDuration: selectedDriverRoute!['duration'] ?? 0.0,
                                passengerDistance: passengerDistance,
                                passengerDuration: passengerDuration,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Right Panel - Map
                  Expanded(
                    child: SharedMapWidget(
                      mapController: _mapController,
                      drivers: [], // No drivers in passenger view
                      selectedDriverId: null,
                      driverFrom: null,
                      driverTo: null,
                      driverPoints: [],
                      passengerFrom: passengerFrom,
                      passengerTo: passengerTo,
                      passengerPoints: _ensureLatLngList(passengerPoints),
                      isMapSelectionMode: _isMapSelectionMode,
                      currentSelectionField: _currentSelectionField,
                      onMapTap: _handleMapTap,
                      isLoading: _isLoading,
                      dynamicDriverRoutes: convertedDriverRoutes.isNotEmpty ? convertedDriverRoutes : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInput({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required String fieldName,
    required VoidCallback onSearch,
  }) {
    final isActive = _isMapSelectionMode && _currentSelectionField == fieldName;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Interactive icon
            GestureDetector(
              onTap: () => _enableMapSelection(fieldName),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? Colors.green : Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isActive ? Colors.green : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Enter ${label.toLowerCase()}',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : onSearch,
              child: const Text('Search'),
            ),
          ],
        ),
      ],
    );
  }

  Color _getPercentageColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    if (percentage >= 40) return Colors.yellow;
    return Colors.red;
  }

  // Utility to ensure a List<dynamic> is converted to List<LatLng>
  List<LatLng> _ensureLatLngList(dynamic points) {
    if (points is List<LatLng>) return points;
    if (points is List) {
      return points.map((e) {
        if (e is LatLng) return e;
        if (e is Map<String, dynamic>) {
          return LatLng(
            (e['latitude'] as num).toDouble(),
            (e['longitude'] as num).toDouble(),
          );
        }
        return null;
      }).whereType<LatLng>().toList();
    }
    return [];
  }

  // Convert driver routes to the format expected by SharedMapWidget
  void _convertDriverRoutesToMap() {
    convertedDriverRoutes.clear();
    
    try {
      for (var driverRoute in driverRoutes) {
        if (driverRoute == null) continue;
        
        final driverId = driverRoute['driverId'] ?? driverRoute['driverName'] ?? 'unknown';
        
        // Get start and end coordinates from the stored route data
        final startLat = driverRoute['startLatitude'] as double?;
        final startLng = driverRoute['startLongitude'] as double?;
        final endLat = driverRoute['endLatitude'] as double?;
        final endLng = driverRoute['endLongitude'] as double?;
        
        if (startLat != null && startLng != null && endLat != null && endLng != null) {
          final startCoord = LatLng(startLat, startLng);
          final endCoord = LatLng(endLat, endLng);
          
          // For now, create a simple route with just start and end points
          // The full route calculation would be done asynchronously in a real implementation
          convertedDriverRoutes[driverId] = [startCoord, endCoord];
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error converting driver routes: $e')),
      );
      convertedDriverRoutes.clear();
    }
  }
} 