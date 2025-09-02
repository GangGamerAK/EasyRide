import 'package:flutter/material.dart';

class DriverAcceptedPassengerPanel extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onRefresh;
  final List<dynamic> acceptedPassengers;
  final Widget Function(Map<String, dynamic>) buildPassengerCard;

  const DriverAcceptedPassengerPanel({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onRefresh,
    required this.acceptedPassengers,
    required this.buildPassengerCard,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: 0,
      bottom: 0,
      right: isOpen ? 0 : -340,
      width: 340,
      child: Material(
        elevation: 16,
        color: Colors.white,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_right, color: Colors.black),
                  onPressed: onClose,
                  tooltip: 'Close',
                ),
                const Text('Accepted Passengers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.blue),
                  onPressed: onRefresh,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: acceptedPassengers.isNotEmpty
                  ? ListView.builder(
                      itemCount: acceptedPassengers.length,
                      itemBuilder: (context, index) {
                        final passenger = acceptedPassengers[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: buildPassengerCard(passenger),
                        );
                      },
                    )
                  : const Center(child: Text('No accepted passengers yet.')),
            ),
          ],
        ),
      ),
    );
  }
} 