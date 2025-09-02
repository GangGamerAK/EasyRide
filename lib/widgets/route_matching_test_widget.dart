import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/route_service.dart';

class RouteMatchingTestWidget extends StatefulWidget {
  final List<LatLng> driverPoints;
  final List<LatLng> passengerPoints;

  const RouteMatchingTestWidget({
    Key? key,
    required this.driverPoints,
    required this.passengerPoints,
  }) : super(key: key);

  @override
  State<RouteMatchingTestWidget> createState() => _RouteMatchingTestWidgetState();
}

class _RouteMatchingTestWidgetState extends State<RouteMatchingTestWidget> {
  bool _showComparison = false;

  @override
  Widget build(BuildContext context) {
    // Calculate results using the standard algorithm
    final matchPercentage = RouteService.calculateMatchPercentage(
      widget.driverPoints, 
      widget.passengerPoints
    );
    final commonPoints = RouteService.getCommonRoute(
      widget.driverPoints, 
      widget.passengerPoints
    );
    final commonPercentage = RouteService.calculateCommonPercentage(
      widget.driverPoints, 
      widget.passengerPoints
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Route Matching Test',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(_showComparison ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _showComparison = !_showComparison;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Summary comparison
            Row(
              children: [
                Expanded(
                  child: _buildAlgorithmCard(
                    'Standard Algorithm',
                    matchPercentage,
                    commonPoints.length,
                    commonPercentage,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.withOpacity(0.1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Algorithm Info',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('500m radius', style: TextStyle(fontSize: 12)),
                        Text('Geographic distance', style: TextStyle(fontSize: 12)),
                        Text('Real-world ready', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            if (_showComparison) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              
              // Algorithm details
              _buildAlgorithmDetails(
                matchPercentage,
                commonPoints,
                commonPercentage,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlgorithmCard(
    String title,
    double matchPercentage,
    int commonPointsCount,
    double commonPercentage,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text('Match: ${matchPercentage.toStringAsFixed(1)}%'),
          Text('Common Points: $commonPointsCount'),
          Text('Common %: ${commonPercentage.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _buildAlgorithmDetails(
    double matchPercentage,
    List<LatLng> commonPoints,
    double commonPercentage,
  ) {

          return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Algorithm Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Algorithm information
          _buildInfoRow('Match Percentage', '${matchPercentage.toStringAsFixed(1)}%'),
          _buildInfoRow('Common Points', '${commonPoints.length}'),
          _buildInfoRow('Common Percentage', '${commonPercentage.toStringAsFixed(1)}%'),
          
          const SizedBox(height: 16),
          
          // Algorithm features
          _buildFeaturesSection(),
        ],
      );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Algorithm Features',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• 500m radius for nearby route detection',
            style: TextStyle(fontSize: 12, color: Colors.green),
          ),
          Text(
            '• Geographic distance calculation',
            style: TextStyle(fontSize: 12, color: Colors.green),
          ),
          Text(
            '• Real-world ride-sharing ready',
            style: TextStyle(fontSize: 12, color: Colors.green),
          ),
        ],
      ),
    );
  }
} 