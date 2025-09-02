import 'package:latlong2/latlong.dart';
import 'package:osrm/osrm.dart';
import 'dart:math' as math;
import '../models/driver.dart';
import 'location_service.dart';
import 'package:geolocator/geolocator.dart';

class RouteService {
  // Get route details from OSRM API
  static Future<Map<String, dynamic>> calculateRoute(LatLng from, LatLng to) async {
    try {
      final osrm = Osrm();
      final options = RouteRequest(
        coordinates: [
          (from.longitude, from.latitude),
          (to.longitude, to.latitude),
        ],
        overview: OsrmOverview.full,
      );
      final route = await osrm.route(options);
      
      // Extract route data
      final distance = route.routes.first.distance!;
      final duration = route.routes.first.duration!;
      final points = route.routes.first.geometry!.lineString!.coordinates.map((e) {
        var location = e.toLocation();
        return LatLng(location.lat, location.lng);
      }).toList();
      
      // Get road names from route
      final roadNames = route.routes.first.legs
          ?.expand((leg) => leg.steps ?? [])
          .map((step) => step.name)
          .where((name) => name != null && name.isNotEmpty)
          .toSet()
          .toList() ?? [];
      
      return {
        'distance': distance,
        'duration': duration,
        'points': points,
        'roadNames': roadNames,
      };
    } catch (e) {
      rethrow;
    }
  }

  // Calculate how well driver and passenger routes match
  static double calculateMatchPercentage(List<LatLng> driverPoints, List<LatLng> passengerPoints) {
    if (driverPoints.isEmpty || passengerPoints.isEmpty) return 0.0;
    
    const double matchRadius = 500.0;
    int matchingPassengerPoints = 0;
    int totalPassengerPoints = passengerPoints.length;
    
    // Check each passenger point against driver route
    for (final passengerPoint in passengerPoints) {
      bool hasNearbyDriverPoint = false;
      
      for (final driverPoint in driverPoints) {
        double distance = _calculateSegmentDistance(passengerPoint, driverPoint);
        if (distance <= matchRadius) {
          hasNearbyDriverPoint = true;
          break;
        }
      }
      
      if (hasNearbyDriverPoint) {
        matchingPassengerPoints++;
      }
    }
    
    return (matchingPassengerPoints / totalPassengerPoints) * 100.0;
  }

  // Calculate distance between two coordinates
  static double _calculateSegmentDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // Find common route points between driver and passenger
  static List<LatLng> getCommonRoute(List<LatLng> driverPoints, List<LatLng> passengerPoints) {
    if (driverPoints.isEmpty || passengerPoints.isEmpty) return [];
    
    const double matchRadius = 500.0;
    List<LatLng> commonPoints = [];
    
    // Find overlapping points
    for (final driverPoint in driverPoints) {
      for (final passengerPoint in passengerPoints) {
        double distance = _calculateSegmentDistance(driverPoint, passengerPoint);
        if (distance <= matchRadius) {
          commonPoints.add(driverPoint);
          break;
        }
      }
    }
    
    // Remove duplicates
    Set<LatLng> seen = {};
    List<LatLng> uniquePoints = [];
    for (LatLng point in commonPoints) {
      if (!seen.contains(point)) {
        seen.add(point);
        uniquePoints.add(point);
      }
    }
    
    return uniquePoints;
  }

  // Get common route percentage (same as match percentage)
  static double calculateCommonPercentage(List<LatLng> driverPoints, List<LatLng> passengerPoints) {
    return calculateMatchPercentage(driverPoints, passengerPoints);
  }
} 