import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class Driver {
  final String id;
  final String name;
  final LatLng? from;
  final LatLng? to;
  final List<LatLng> points;
  final num distance;
  final num duration;
  final double matchPercentage;
  final LatLng profileLocation;
  final Color markerColor;
  final double? averageRating;
  final int? reviewCount;

  Driver({
    required this.id,
    required this.name,
    this.from,
    this.to,
    required this.points,
    required this.distance,
    required this.duration,
    required this.matchPercentage,
    required this.profileLocation,
    required this.markerColor,
    this.averageRating,
    this.reviewCount,
  });
} 