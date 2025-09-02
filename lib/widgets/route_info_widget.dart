import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/driver.dart';
import '../services/route_service.dart';


class RouteInfoWidget extends StatelessWidget {
  final Driver? selectedDriver;
  final List<LatLng> driverPoints;
  final List<LatLng> passengerPoints;
  final num driverDistance;
  final num driverDuration;
  final num passengerDistance;
  final num passengerDuration;

  const RouteInfoWidget({
    super.key,
    required this.selectedDriver,
    required this.driverPoints,
    required this.passengerPoints,
    required this.driverDistance,
    required this.driverDuration,
    required this.passengerDistance,
    required this.passengerDuration,
  });

  @override
  Widget build(BuildContext context) {
    final commonPoints = RouteService.getCommonRoute(driverPoints, passengerPoints);
    final isSingleRoute = selectedDriver == null;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              Text(
                isSingleRoute ? 'Route Information' : 'Route Comparison',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              
              // Legend
              if (!isSingleRoute) ...[
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      color: selectedDriver?.markerColor ?? Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text('${selectedDriver?.name ?? 'Driver'} Route'),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 20,
                      height: 20,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text('Passenger Route'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (commonPoints.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      const Text('Common Route'),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ] else ...[
                // Single route legend
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    const Text('Route'),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // Route statistics
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (driverDistance > 0) ...[
                    if (isSingleRoute) ...[
                      Text(
                        'Distance: ${(driverDistance / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Duration: ${(driverDuration / 60).toStringAsFixed(1)} min',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ] else ...[
                      Text('Driver: ${(driverDistance / 1000).toStringAsFixed(1)} km, ${(driverDuration / 60).toStringAsFixed(1)} min'),
                    ],
                  ],
                  if (passengerDistance > 0 && !isSingleRoute)
                    Text('Passenger: ${(passengerDistance / 1000).toStringAsFixed(1)} km, ${(passengerDuration / 60).toStringAsFixed(1)} min'),
                  if (commonPoints.isNotEmpty && !isSingleRoute) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Common: ${commonPoints.length} points',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.5)),
                          ),
                          child: Text(
                            '${RouteService.calculateCommonPercentage(driverPoints, passengerPoints).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '(${commonPoints.length > 6 ? "Extended" : "Exact"} matches)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
              

            ],
          ),
        ),
      ),
    );
  }
} 