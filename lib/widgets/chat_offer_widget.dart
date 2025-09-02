import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatOfferWidget extends StatefulWidget {
  final String chatId;
  final String senderId;
  final String senderName;
  final double matchPercentage;
  final Function(Map<String, dynamic>) onSendOffer;
  final Map<String, dynamic>? existingOffer; // For editing existing offers
  final String routeId;

  const ChatOfferWidget({
    super.key,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.matchPercentage,
    required this.onSendOffer,
    this.existingOffer,
    required this.routeId,
  });

  @override
  State<ChatOfferWidget> createState() => _ChatOfferWidgetState();
}

class _ChatOfferWidgetState extends State<ChatOfferWidget> {
  final Set<String> _selectedDays = {};
  int _seatCount = 1;
  double _pricePerDay = 0.0;
  bool _isSending = false;
  bool _isOneWay = true; // true for one-way, false for two-way
  TimeOfDay _pickupTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _dropTime = const TimeOfDay(hour: 17, minute: 0);

  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday', 
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with existing offer data if editing
    if (widget.existingOffer != null) {
      final offer = widget.existingOffer!;
      _selectedDays.addAll((offer['selectedDays'] as List<dynamic>? ?? []).cast<String>());
      _seatCount = offer['seatCount'] as int? ?? 1;
      _pricePerDay = (offer['pricePerDay'] as num?)?.toDouble() ?? 0.0;
      _isOneWay = offer['isOneWay'] as bool? ?? true;
      final pickupTimeString = offer['pickupTime'] as String? ?? '08:00';
      _pickupTime = _parseTimeString(pickupTimeString);
      final dropTimeString = offer['dropTime'] as String? ?? '17:00';
      _dropTime = _parseTimeString(dropTimeString);
    }
  }

  TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: hour, minute: minute);
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _incrementSeats() {
    if (_seatCount < 4) {
      setState(() {
        _seatCount++;
      });
    }
  }

  void _decrementSeats() {
    if (_seatCount > 1) {
      setState(() {
        _seatCount--;
      });
    }
  }

  Future<void> _sendOffer() async {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_pricePerDay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a valid price per day'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final offerData = {
        'routeId': widget.routeId,
        'type': 'ride_offer',
        'matchPercentage': widget.matchPercentage,
        'selectedDays': _selectedDays.toList(),
        'seatCount': _seatCount,
        'pricePerDay': _pricePerDay,
        'isOneWay': _isOneWay,
        'pickupTime': _formatTimeOfDay(_pickupTime),
        'dropTime': _formatTimeOfDay(_dropTime),
        'status': 'pending', // pending, accepted, rejected
        'timestamp': FieldValue.serverTimestamp(),
      };

      await widget.onSendOffer(offerData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingOffer != null ? 'Offer updated successfully!' : 'Offer sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending offer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.local_offer, color: Colors.blue, size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Send Ride Offer',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Route Match and Travel Type Row
                    Row(
                      children: [
                        // Route Match Circle
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.1),
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${widget.matchPercentage.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                                const Text(
                                  'Match',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Travel Type Toggle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Travel Type',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isOneWay = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: _isOneWay ? Colors.blue : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'One Way',
                                            style: TextStyle(
                                              color: _isOneWay ? Colors.white : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _isOneWay = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: !_isOneWay ? Colors.blue : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'Two Way',
                                            style: TextStyle(
                                              color: !_isOneWay ? Colors.white : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Time Selection
                    const Text(
                      'Time Selection',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Pickup Time
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pickup Time',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () async {
                                  final TimeOfDay? picked = await showTimePicker(
                                    context: context,
                                    initialTime: _pickupTime,
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _pickupTime = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, color: Colors.blue, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTimeOfDay(_pickupTime),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.arrow_drop_down, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Drop Time (only for two-way)
                        if (!_isOneWay) ...[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Drop Time',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () async {
                                    final TimeOfDay? picked = await showTimePicker(
                                      context: context,
                                      initialTime: _dropTime,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _dropTime = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, color: Colors.orange, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatTimeOfDay(_dropTime),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.arrow_drop_down, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Days Selection
                    const Text(
                      'Select Days',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _daysOfWeek.map((day) {
                        final isSelected = _selectedDays.contains(day);
                        return FilterChip(
                          label: Text(day),
                          selected: isSelected,
                          onSelected: (_) => _toggleDay(day),
                          backgroundColor: Colors.grey[200],
                          selectedColor: Colors.blue[100],
                          checkmarkColor: Colors.blue,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Seat Count
                    const Text(
                      'Number of Seats',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _decrementSeats,
                          icon: const Icon(Icons.remove_circle_outline),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_seatCount',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: _incrementSeats,
                          icon: const Icon(Icons.add_circle_outline),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Max: 4',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Price Per Day
                    const Text(
                      'Price Per Day',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.currency_rupee),
                        hintText: 'Enter price per day (PKR)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _pricePerDay = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendOffer,
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(_isSending ? 'Sending...' : 'Send Offer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
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
}

// Widget to display received offers in chat
class ChatOfferDisplayWidget extends StatelessWidget {
  final Map<String, dynamic> offerData;
  final bool isMyMessage;
  final String userRole; // 'passenger' or 'driver'
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onEdit;

  const ChatOfferDisplayWidget({
    super.key,
    required this.offerData,
    required this.isMyMessage,
    required this.userRole,
    this.onAccept,
    this.onReject,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final matchPercentage = offerData['matchPercentage'] as double? ?? 0.0;
    final selectedDays = (offerData['selectedDays'] as List<dynamic>? ?? []).cast<String>();
    final seatCountRaw = offerData['seatCount'];
    final seatCount = seatCountRaw is int ? seatCountRaw : (seatCountRaw is double ? seatCountRaw.toInt() : 1);
    final pricePerDayRaw = offerData['pricePerDay'];
    final pricePerDay = pricePerDayRaw is int ? pricePerDayRaw.toDouble() : (pricePerDayRaw as double? ?? 0.0);
    final isOneWay = offerData['isOneWay'] as bool? ?? true;
    final pickupTime = offerData['pickupTime'] as String? ?? '08:00';
    final dropTime = offerData['dropTime'] as String? ?? '17:00';
    final status = offerData['status'] as String? ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMyMessage ? Colors.blue : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'accepted' 
              ? Colors.green 
              : status == 'rejected' 
                  ? Colors.red 
                  : Colors.grey,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.local_offer,
                color: isMyMessage ? Colors.white : Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Ride Offer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isMyMessage ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              if (status != 'pending')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'accepted' ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

                     // Route Match and Travel Type
           Row(
             children: [
               // Route Match Circle
               Container(
                 width: 40,
                 height: 40,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   color: isMyMessage ? Colors.white24 : Colors.blue.withOpacity(0.1),
                   border: Border.all(
                     color: isMyMessage ? Colors.white70 : Colors.blue,
                     width: 1,
                   ),
                 ),
                 child: Center(
                   child: Text(
                     '${matchPercentage.toStringAsFixed(1)}%',
                     style: TextStyle(
                       fontSize: 10,
                       fontWeight: FontWeight.bold,
                       color: isMyMessage ? Colors.white : Colors.blue,
                     ),
                   ),
                 ),
               ),
               const SizedBox(width: 12),
               // Travel Type
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: isMyMessage ? Colors.white24 : Colors.grey[200],
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Text(
                   isOneWay ? 'One Way' : 'Two Way',
                   style: TextStyle(
                     fontSize: 10,
                     fontWeight: FontWeight.bold,
                     color: isMyMessage ? Colors.white : Colors.black87,
                   ),
                 ),
               ),
               if (isOneWay) ...[
                 const SizedBox(width: 8),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: isMyMessage ? Colors.white24 : Colors.orange[100],
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: Text(
                     'Pickup: $pickupTime',
                     style: TextStyle(
                       fontSize: 10,
                       fontWeight: FontWeight.bold,
                       color: isMyMessage ? Colors.white : Colors.orange[700],
                     ),
                   ),
                 ),
               ] else ...[
                 const SizedBox(width: 8),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: isMyMessage ? Colors.white24 : Colors.orange[100],
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: Text(
                     'Pickup: $pickupTime',
                     style: TextStyle(
                       fontSize: 10,
                       fontWeight: FontWeight.bold,
                       color: isMyMessage ? Colors.white : Colors.orange[700],
                     ),
                   ),
                 ),
                 const SizedBox(width: 4),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: isMyMessage ? Colors.white24 : Colors.green[100],
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: Text(
                     'Drop: $dropTime',
                     style: TextStyle(
                       fontSize: 10,
                       fontWeight: FontWeight.bold,
                       color: isMyMessage ? Colors.white : Colors.green[700],
                     ),
                   ),
                 ),
               ],
             ],
           ),
           const SizedBox(height: 8),

          // Selected Days
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: isMyMessage ? Colors.white70 : Colors.blue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Days: ${selectedDays.join(', ')}',
                  style: TextStyle(
                    color: isMyMessage ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Seat Count
          Row(
            children: [
              Icon(
                Icons.airline_seat_recline_normal,
                color: isMyMessage ? Colors.white70 : Colors.blue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Seats: $seatCount',
                style: TextStyle(
                  color: isMyMessage ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Price
          Row(
            children: [
              Icon(
                Icons.currency_rupee,
                color: isMyMessage ? Colors.white70 : Colors.blue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Price: PKR ${pricePerDay.toStringAsFixed(0)} per day',
                style: TextStyle(
                  color: isMyMessage ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

                     // Action buttons
           if (status == 'pending') ...[
             const SizedBox(height: 12),
             Row(
               children: [
                 // Accept/Reject buttons (only for driver, only for pending offers from passengers)
                 if (!isMyMessage && userRole == 'driver') ...[
                   Expanded(
                     child: OutlinedButton(
                       onPressed: onAccept,
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Colors.green,
                         side: const BorderSide(color: Colors.green),
                       ),
                       child: const Text('Accept'),
                     ),
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: OutlinedButton(
                       onPressed: onReject,
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Colors.red,
                         side: const BorderSide(color: Colors.red),
                       ),
                       child: const Text('Reject'),
                     ),
                   ),
                 ],
                 // Edit button (for the sender of the offer)
                 if (isMyMessage && onEdit != null) ...[
                   Expanded(
                     child: OutlinedButton(
                       onPressed: onEdit,
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Colors.blue,
                         side: const BorderSide(color: Colors.blue),
                       ),
                       child: const Text('Edit'),
                     ),
                   ),
                 ],
                 // Counter offer button (for the receiver)
                 if (!isMyMessage && onEdit != null) ...[
                   Expanded(
                     child: OutlinedButton(
                       onPressed: onEdit,
                       style: OutlinedButton.styleFrom(
                         foregroundColor: Colors.orange,
                         side: const BorderSide(color: Colors.orange),
                       ),
                       child: const Text('Counter Offer'),
                     ),
                   ),
                 ],
               ],
             ),
           ],
        ],
      ),
    );
  }
} 