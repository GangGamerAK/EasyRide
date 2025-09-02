import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // Added for Color
import '../services/route_service.dart'; // Added for RouteService
import 'dart:io';
import 'dart:typed_data';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _routesCollection = 'routes';
  static const String _roadNamesCollection = 'road_names';

  static const String _imgbbApiKey = String.fromEnvironment('IMGBB_API_KEY');

  static Future<String> uploadImageToImgbb(dynamic fileOrBytes) async {
    Uint8List bytes;
    if (fileOrBytes is File) {
      bytes = await fileOrBytes.readAsBytes();
    } else if (fileOrBytes is Uint8List) {
      bytes = fileOrBytes;
    } else {
      throw ArgumentError('Invalid file type. Expected File or Uint8List.');
    }
    final base64Image = base64Encode(bytes);
    final response = await http
        .post(
          Uri.parse('https://api.imgbb.com/1/upload?key=$_imgbbApiKey'),
          body: {'image': base64Image},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['url'];
    } else {
      throw Exception('Failed to upload image (${response.statusCode}): ${response.body}');
    }
  }

  // Initialize Firebase
  static Future<void> initialize() async {
    // Firebase will be initialized in main.dart
  }

  // Extract road names from route points
  static Future<List<String>> extractRoadNames(List<LatLng> routePoints) async {
    List<String> roadNames = [];
    Set<String> uniqueRoadNames = {};

    // Calculate target number of road names based on route length
    int targetRoadNames = _calculateTargetRoadNames(routePoints.length);
    // Sample fewer points and stop after finding enough road names
    for (int i = 0; i < routePoints.length; i += 10) { // Sample every 10th point
      final point = routePoints[i];
      // Try to get road name using multiple methods
      String roadName = await _getRoadNameFromCoordinates(point);
      // If first method fails, try Nominatim
      if (roadName.isEmpty) {
        roadName = await _getRoadNameFromNominatim(point);
      }
      // Only add real street names, skip coordinate-based fallbacks
      if (_isRealRoadName(roadName)) {
        if (!uniqueRoadNames.contains(roadName)) {
          uniqueRoadNames.add(roadName);
          roadNames.add(roadName);
        }
        // Stop after finding target number of road names
        if (roadNames.length >= targetRoadNames) {
          break;
        }
      }
    }
    // If no real street names found, try a minimal broader search
    if (roadNames.isEmpty) {
      roadNames = await _extractRoadNamesWithMinimalSearch(routePoints);
    }
    return roadNames;
  }

  // Calculate target number of road names based on route length
  static int _calculateTargetRoadNames(int totalPoints) {
    // Base calculation: 1 road name per 10-15 points, with min/max limits
    int baseTarget = (totalPoints / 12).round();
    
    // Ensure minimum of 5 and maximum of 20 road names
    int target = baseTarget.clamp(5, 20);
    
    // For very long routes, cap at 25
    if (totalPoints > 200) {
      target = target.clamp(5, 25);
    }
    
    return target;
  }

  // Minimal search method that checks only a few key points
  static Future<List<String>> _extractRoadNamesWithMinimalSearch(List<LatLng> routePoints) async {
    List<String> roadNames = [];
    Set<String> uniqueRoadNames = {};

    try {
      // Calculate target number for minimal search (half of normal target)
      int targetRoadNames = (_calculateTargetRoadNames(routePoints.length) / 2).round();
      if (targetRoadNames < 3) targetRoadNames = 3;
      if (targetRoadNames > 10) targetRoadNames = 10;
      
      // Check only start, middle, and end points
      List<int> keyPoints = [
        0, // Start
        routePoints.length ~/ 4, // Quarter
        routePoints.length ~/ 2, // Middle
        3 * routePoints.length ~/ 4, // Three quarters
        routePoints.length - 1, // End
      ];
      
      for (int index in keyPoints) {
        if (index >= routePoints.length) continue;
        
        final point = routePoints[index];
        
        // Try Nominatim first (more reliable)
        String roadName = await _getRoadNameFromNominatim(point);
        
        if (roadName.isEmpty) {
          roadName = await _getRoadNameFromCoordinates(point);
        }
        
        // Only add real street names
        if (_isRealRoadName(roadName)) {
          if (!uniqueRoadNames.contains(roadName)) {
            uniqueRoadNames.add(roadName);
            roadNames.add(roadName);
          }
          
          // Stop after finding target number of road names
          if (roadNames.length >= targetRoadNames) {
            break;
          }
        }
      }
    } catch (e) {
      // Silently handle errors
    }

    return roadNames;
  }

  // Get road name from coordinates using reverse geocoding
  static Future<String> _getRoadNameFromCoordinates(LatLng point) async {
    try {
      final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        // Try to get the most specific road name
        String roadName = placemark.thoroughfare ?? 
                         placemark.street ?? 
                         placemark.name ?? 
                         '';
        // Clean up the road name
        roadName = roadName.trim();
        if (roadName.isNotEmpty && roadName != 'null') {
          return roadName;
        }
      }
    } catch (e) {
      // Silently handle geocoding errors to reduce spam
      return '';
    }
    return '';
  }

  // Alternative method using Nominatim for better street names
  static Future<String> _getRoadNameFromNominatim(LatLng point) async {
    try {
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json&addressdetails=1&zoom=18'),
        headers: {'User-Agent': 'FlutterMapApp/1.0'},
      ).timeout(const Duration(seconds: 5)); // Add timeout
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        if (address != null) {
          // Try different address components for road names
          String roadName = address['road'] ?? 
                           address['street'] ?? 
                           address['highway'] ?? 
                           address['name'] ?? 
                           '';
          roadName = roadName.trim();
          if (roadName.isNotEmpty && roadName != 'null') {
            return roadName;
          }
        }
        // If no road name in address, try the display name
        final displayName = data['display_name'] ?? '';
        if (displayName.isNotEmpty) {
          // Extract road name from display name
          final parts = displayName.split(',');
          if (parts.isNotEmpty) {
            String potentialRoad = parts.first.trim();
            if (potentialRoad.isNotEmpty && potentialRoad != 'null') {
              return potentialRoad;
            }
          }
        }
      }
    } catch (e) {
      // Silently handle errors to reduce spam
      return '';
    }
    return '';
  }

  // Real road name check (not empty and not a fallback)
  static bool _isRealRoadName(String roadName) {
    if (roadName.isEmpty) return false;
    return !(roadName.startsWith('North_') || roadName.startsWith('South_'));
  }

  // Save route data to Firebase
  static Future<String> saveRouteData({
    required String routeId,
    required List<LatLng> routePoints,
    required num distance,
    required num duration,
    required String fromLocation,
    required String toLocation,
    required List<String> roadNames,
    String? driverId,
    String? driverName,
    String? passengerId,
  }) async {
    try {
      LatLng startCoord = routePoints.first;
      LatLng endCoord = routePoints.last;
      final routePointsList = routePoints.map((p) => {'latitude': p.latitude, 'longitude': p.longitude}).toList();
      final routeData = {
        'routeId': routeId,
        'startLatitude': startCoord.latitude,
        'startLongitude': startCoord.longitude,
        'endLatitude': endCoord.latitude,
        'endLongitude': endCoord.longitude,
        'routePoints': routePointsList,
        'distance': distance,
        'duration': duration,
        'fromLocation': fromLocation,
        'toLocation': toLocation,
        'roadNames': roadNames,
        'timestamp': FieldValue.serverTimestamp(),
        'roadNamesHash': _generateRoadNamesHash(roadNames),
      };
      if (driverId != null) routeData['driverId'] = driverId;
      if (driverName != null) routeData['driverName'] = driverName;
      if (passengerId != null) routeData['passengerId'] = passengerId;
      await _firestore.collection(_routesCollection).doc(routeId).set(routeData);
      await _saveRoadNamesForSearch(routeId, roadNames);
      return routeId;
    } catch (e) {
      rethrow;
    }
  }

  // Generate hash for road names for quick comparison
  static String _generateRoadNamesHash(List<String> roadNames) {
    final sortedNames = List<String>.from(roadNames)..sort();
    return base64.encode(utf8.encode(sortedNames.join('|')));
  }

  // Save road names for easy searching
  static Future<void> _saveRoadNamesForSearch(String routeId, List<String> roadNames) async {
    try {
      final batch = _firestore.batch();
      for (String roadName in roadNames) {
        final docRef = _firestore.collection(_roadNamesCollection).doc(roadName);
        batch.set(
          docRef,
          {
            'roadName': roadName,
            'routeIds': FieldValue.arrayUnion([routeId]),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } catch (e) {
      print('Failed to save road name for search: $e'); // Log errors for debugging
    }
  }

  // Utility to convert List<dynamic> to List<LatLng>
  static List<LatLng> parseLatLngList(dynamic points) {
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

  // Get route by ID
  static Future<Map<String, dynamic>?> getRouteById(String routeId) async {
    try {
      final doc = await _firestore
          .collection(_routesCollection)
          .doc(routeId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['routePoints'] != null) {
          data['routePoints'] = parseLatLngList(data['routePoints']);
        }
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Search routes by road names - OPTIMIZED VERSION
  static Future<List<Map<String, dynamic>>> searchRoutesByRoadNames(List<String> roadNames) async {
    try {
      Set<String> uniqueRouteIds = {};

      if (roadNames.isEmpty) return [];

      // 1. Get all route IDs from the road_names collection in chunks (whereIn limit 30)
      for (final chunk in _chunk(roadNames, 30)) {
        final querySnapshot = await _firestore
            .collection(_roadNamesCollection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          if (data['routeIds'] != null) {
            uniqueRouteIds.addAll(List<String>.from(data['routeIds']));
          }
        }
      }

      if (uniqueRouteIds.isEmpty) {
        return [];
      }

      // 2. Fetch all matching routes in a single efficient query
      // Note: Firestore 'whereIn' is limited to 30 items per query.
      // For a larger set, we chunk uniqueRouteIds into lists of 30.
      List<Map<String, dynamic>> matchingRoutes = [];
      List<String> routeIdsList = uniqueRouteIds.toList();
      
      // Process in chunks of 30 to respect Firestore limits
      for (final chunk in _chunk(routeIdsList, 30)) {
        final routesQuery = await _firestore
            .collection(_routesCollection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (var doc in routesQuery.docs) {
          var routeData = doc.data();
          // Parse route points
          if (routeData['routePoints'] != null) {
            routeData['routePoints'] = parseLatLngList(routeData['routePoints']);
          }
          matchingRoutes.add(routeData);
        }
      }

      return matchingRoutes;
    } catch (e) {
      print('Error searching routes: $e'); // Log errors!
      return [];
    }
  }

  // Calculate common route percentage based on road names
  static double calculateCommonRoutePercentage(List<String> route1RoadNames, List<String> route2RoadNames) {
    if (route1RoadNames.isEmpty || route2RoadNames.isEmpty) return 0.0;

    Set<String> set1 = Set<String>.from(route1RoadNames);
    Set<String> set2 = Set<String>.from(route2RoadNames);

    // Find common road names
    Set<String> commonRoads = set1.intersection(set2);
    
    // Calculate percentage based on common roads vs total unique roads
    Set<String> allUniqueRoads = set1.union(set2);
    
    if (allUniqueRoads.isEmpty) return 0.0;
    
    return (commonRoads.length / allUniqueRoads.length) * 100.0;
  }

  // Get all driver routes with profile information
  static Future<List<Map<String, dynamic>>> getAllDriverRoutes() async {
    try {
      final querySnapshot = await _firestore
          .collection(_routesCollection)
          .where('driverId', isGreaterThan: '')
          .get();
      
      // Build unique driver id sets
      final Set<String> emailIds = {};
      final Set<String> numberIds = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final id = (data['driverId'] ?? '').toString();
        if (id.isEmpty) continue;
        if (id.contains('@')) {
          emailIds.add(id.toLowerCase());
        } else {
          numberIds.add(id);
        }
      }

      // Prefetch users by email and number in chunks
      final Map<String, Map<String, dynamic>> usersByEmail =
          await _fetchUsersByField('email', emailIds.toList());
      final Map<String, Map<String, dynamic>> usersByNumber =
          await _fetchUsersByField('number', numberIds.toList());

      // Merge route data with profile info
      List<Map<String, dynamic>> routesWithProfiles = [];
      for (var doc in querySnapshot.docs) {
        var routeData = doc.data();
        String driverId = routeData['driverId'] ?? '';
        if (driverId.isNotEmpty) {
          try {
            Map<String, dynamic>? userData;
            if (driverId.contains('@')) {
              userData = usersByEmail[driverId.toLowerCase()];
            } else {
              userData = usersByNumber[driverId];
            }
            if (userData != null) {
              routeData['profileImageUrl'] = userData['profileImageUrl'];
              routeData['isVerified'] = userData['isVerified'] ?? false;
            }
          } catch (e) {
            print('Error merging profile for driver $driverId: $e');
          }
        }
        routesWithProfiles.add(routeData);
      }

      return routesWithProfiles;
    } catch (e) {
      return [];
    }
  }

  // Get routes by driver ID
  static Future<List<Map<String, dynamic>>> getRoutesByDriverId(String driverId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_routesCollection)
          .where('driverId', isEqualTo: driverId)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get routes by driver name
  static Future<List<Map<String, dynamic>>> getRoutesByDriverName(String driverName) async {
    try {
      final querySnapshot = await _firestore
          .collection(_routesCollection)
          .where('driverName', isEqualTo: driverName)
          .get();

      return querySnapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get routes by passenger ID
  static Future<List<Map<String, dynamic>>> getRoutesByPassengerId(String passengerId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_routesCollection)
          .where('passengerId', isEqualTo: passengerId)
          .get();
      return querySnapshot.docs
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Get route points by calculating from start/end coordinates
  static Future<List<LatLng>> getRoutePoints(String routeId) async {
    try {
      final routeDoc = await getRouteById(routeId);
      if (routeDoc == null) return [];

      // Check for start/end coordinates
      final startLat = routeDoc['startLatitude'];
      final startLng = routeDoc['startLongitude'];
      final endLat = routeDoc['endLatitude'];
      final endLng = routeDoc['endLongitude'];

      // Validate coordinates
      if (startLat == null || startLng == null || endLat == null || endLng == null) {
        return [];
      }

      // Validate coordinate values
      if (startLat == 0.0 && startLng == 0.0 && endLat == 0.0 && endLng == 0.0) {
        return [];
      }

      final startCoord = LatLng(startLat, startLng);
      final endCoord = LatLng(endLat, endLng);

      // Calculate route using OSRM
      final calculatedRoute = await RouteService.calculateRoute(startCoord, endCoord);
      final points = calculatedRoute['points'] as List<LatLng>? ?? [];
      
      // Validate calculated points
      if (points.isEmpty) {
        return [];
      }

      return points;
    } catch (e) {
      return [];
    }
  }

  // Get all matching driver routes with calculated points and colors
  static Future<List<Map<String, dynamic>>> getMatchingDriverRoutesWithColors(List<String> passengerRoadNames) async {
    try {
      List<Map<String, dynamic>> matchingRoutes = [];
      Set<String> processedRouteIds = {};

      // Get all driver routes
      final allRoutes = await getAllDriverRoutes();
      
      // Calculate match percentages and add colors
      for (var route in allRoutes) {
        if (route['roadNames'] != null) {
          List<String> driverRoadNames = List<String>.from(route['roadNames']);
          double percentage = calculateCommonRoutePercentage(passengerRoadNames, driverRoadNames);
          
          if (percentage > 0) { // Only include routes with some match
            route['matchPercentage'] = percentage;
            route['markerColor'] = _getDriverColor(route['driverName'] ?? 'Unknown');
            
            // Calculate route points with error handling
            try {
              List<LatLng> routePoints = await getRoutePoints(route['routeId']);
              if (routePoints.isNotEmpty) {
                route['routePoints'] = routePoints;
                matchingRoutes.add(route);
                processedRouteIds.add(route['routeId']);
              }
            } catch (e) {
              // Skip this route if we can't calculate its points
              continue;
            }
          }
        }
      }

      // Sort by match percentage (highest first)
      matchingRoutes.sort((a, b) => (b['matchPercentage'] ?? 0.0).compareTo(a['matchPercentage'] ?? 0.0));

      return matchingRoutes;
    } catch (e) {
      return [];
    }
  }

  // Generate consistent color for each driver
  static Color _getDriverColor(String driverName) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
      Colors.lime,
      Colors.brown,
    ];
    
    // Generate consistent color based on driver name
    int hash = driverName.hashCode;
    int index = hash.abs() % colors.length;
    return colors[index];
  }

  static Future<String> signupUser({required String email, required String number, required String password}) async {
    // Validate phone number length
    if (number.length != 11) {
      return 'Phone number must be 11 digits';
    }
    
    final users = _firestore.collection('users');
    final emailLower = email.toLowerCase();
    // Check for existing email or number
    final emailSnap = await users.where('email', isEqualTo: emailLower).get();
    if (emailSnap.docs.isNotEmpty) return 'Email already in use';
    final numberSnap = await users.where('number', isEqualTo: number).get();
    if (numberSnap.docs.isNotEmpty) return 'Number already in use';
    // Create user
    await users.add({'email': emailLower, 'number': number, 'password': password});
    return 'success';
  }

  // Create admin user (for testing purposes)
  static Future<String> createAdminUser({required String email, required String password}) async {
    final users = _firestore.collection('users');
    final emailLower = email.toLowerCase();
    // Check for existing email
    final emailSnap = await users.where('email', isEqualTo: emailLower).get();
    if (emailSnap.docs.isNotEmpty) return 'Email already in use';
    // Create admin user
    await users.add({
      'email': emailLower, 
      'password': password,
      'role': 'admin',
      'name': 'Admin User',
    });
    return 'success';
  }

  static Future<Map<String, dynamic>?> loginUser({required String emailOrNumber, required String password}) async {
    final users = _firestore.collection('users');
    // Make email login not case sensitive
    final emailLower = emailOrNumber.contains('@') ? emailOrNumber.toLowerCase() : emailOrNumber;
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      users
          .where('password', isEqualTo: password)
          .where('email', isEqualTo: emailLower)
          .get(),
      users
          .where('password', isEqualTo: password)
          .where('number', isEqualTo: emailOrNumber)
          .get(),
    ];
    final results = await Future.wait(futures);
    if (results[0].docs.isNotEmpty) return results[0].docs.first.data();
    if (results[1].docs.isNotEmpty) return results[1].docs.first.data();
    return null;
  }

  static Future<void> deleteAllRoutes() async {
    final snapshot = await _firestore.collection(_routesCollection).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  static Future<void> saveUserProfile({
    required String userId,
    required String role,
    required String name,
    required String cnic,
    required String profileImageUrl,
    String? cnicImageUrl,
    String? licenseNumber,
    String? licenseImageUrl,
  }) async {
    // Validate CNIC length
    if (cnic.length != 13) {
      throw Exception('CNIC must be 13 digits');
    }
    final doc = await _findUserDocRefByEmailOrNumber(userId);
    
    // Check if driver is verified and trying to update CNIC or license images
    final currentData = await doc.get();
    final currentUserData = currentData.data();
    if (currentUserData != null && 
        currentUserData['role'] == 'driver' && 
        currentUserData['isVerified'] == true) {
      
      // Prevent updating CNIC and license images for verified drivers
      if (cnicImageUrl != null || licenseImageUrl != null) {
        throw Exception('Cannot update CNIC or license images for verified drivers. Contact admin for changes.');
      }
    }
    
    await doc.update({
      'role': role,
      'name': name,
      'cnic': cnic,
      'profileImageUrl': profileImageUrl,
      if (cnicImageUrl != null) 'cnicImageUrl': cnicImageUrl,
      if (licenseNumber != null) 'licenseNumber': licenseNumber,
      if (licenseImageUrl != null) 'licenseImageUrl': licenseImageUrl,
      if (userId.contains('@')) 'email': userIdLower, // Always store email lowercased
    });
  }

  static Future<bool> userProfileExists(String userId) async {
    final users = _firestore.collection('users');
    final isEmail = userId.contains('@');
    final emailLower = isEmail ? userId.toLowerCase() : userId;
    final futures = <Future<QuerySnapshot<Map<String, dynamic>>>>[
      users.where('email', isEqualTo: emailLower).get(),
      users.where('number', isEqualTo: userId).get(),
    ];
    final results = await Future.wait(futures);
    if (results[0].docs.isNotEmpty && results[0].docs.first.data().containsKey('role')) return true;
    if (results[1].docs.isNotEmpty && results[1].docs.first.data().containsKey('role')) return true;
    return false;
  }

  static FirebaseFirestore get firestore => _firestore;
  
  // Helper method to check if a driver can edit verification documents
  static bool canEditVerificationDocuments(Map<String, dynamic> userData) {
    return !(userData['role'] == 'driver' && userData['isVerified'] == true);
  }
  
  // Admin method to reset verification status (allows driver to edit documents again)
  static Future<void> resetDriverVerification(String driverId) async {
    final doc = await _findUserDocRefByEmailOrNumber(driverId);
    
    await doc.update({
      'isVerified': false,
      'verificationResetAt': FieldValue.serverTimestamp(),
    });
  }

  // Helper: chunk a list into sublists of given size
  static Iterable<List<T>> _chunk<T>(List<T> items, int chunkSize) sync* {
    if (items.isEmpty) return;
    for (int i = 0; i < items.length; i += chunkSize) {
      final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
      yield items.sublist(i, end);
    }
  }

  // Helper: fetch users by specific field (email/number) in batches, returns map keyed by the field value
  static Future<Map<String, Map<String, dynamic>>> _fetchUsersByField(String field, List<String> values) async {
    final Map<String, Map<String, dynamic>> result = {};
    if (values.isEmpty) return result;
    for (final chunk in _chunk(values, 30)) {
      final snap = await _firestore
          .collection('users')
          .where(field, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final key = data[field];
        if (key is String) {
          result[key] = data;
        }
      }
    }
    return result;
  }

  // Helper: resolve user doc reference by email (case-insensitive) or number
  static Future<DocumentReference<Map<String, dynamic>>> _findUserDocRefByEmailOrNumber(String userId) async {
    final users = _firestore.collection('users');
    final isEmail = userId.contains('@');
    final field = isEmail ? 'email' : 'number';
    final value = isEmail ? userId.toLowerCase() : userId;
    final snap = await users.where(field, isEqualTo: value).get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.first.reference;
    }
    // Fallback: try the other field if first attempt failed
    final otherField = isEmail ? 'number' : 'email';
    final otherValue = isEmail ? userId : userId.toLowerCase();
    final snap2 = await users.where(otherField, isEqualTo: otherValue).get();
    if (snap2.docs.isNotEmpty) {
      return snap2.docs.first.reference;
    }
    throw Exception('User not found');
  }
} 