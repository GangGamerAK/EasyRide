import 'package:latlong2/latlong.dart';

class TileCacheUtils {
  /// Pre-caches map tiles for the bounding box of the given route points and zoom range.
  static Future<void> cacheRouteTiles(List<LatLng> routePoints, {int minZoom = 12, int maxZoom = 16}) async {
    if (routePoints.isEmpty) return;

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

    // FMTC usage removed. If you need tile caching, reimplement with a supported method.
  }
} 