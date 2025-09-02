import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/chat_service.dart';
import '../services/firebase_service.dart';
import '../utils/color_utils.dart';
import '../widgets/verification_badge.dart';
import '../views/chat_view.dart';
import 'passenger_home_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

class PassengerActiveContractDashboard extends StatefulWidget {
  final String passengerId;
  final String passengerName;
  final Map<String, dynamic>? profile;

  const PassengerActiveContractDashboard({
    super.key,
    required this.passengerId,
    required this.passengerName,
    this.profile,
  });

  @override
  State<PassengerActiveContractDashboard> createState() => _PassengerActiveContractDashboardState();
}

class _PassengerActiveContractDashboardState extends State<PassengerActiveContractDashboard> 
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _acceptedOffers = [];
  Map<String, dynamic>? _acceptedDriverProfile;
  Map<String, dynamic>? _acceptedDriverRoute;
  Map<String, dynamic>? _acceptedOfferData;
  String? _driverContactNumber;
  bool _loading = true;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Trip status
  String _tripStatus = 'En Route'; // 'En Route', 'Arrived', 'In Progress', 'Completed'
  int _estimatedArrivalMinutes = 8;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadActiveContract();
    _startStatusUpdates();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _slideController.forward();
  }

  void _startStatusUpdates() {
    // Simulate real-time status updates
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && _tripStatus == 'En Route') {
        setState(() {
          _tripStatus = 'Arrived';
          _estimatedArrivalMinutes = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveContract() async {
    setState(() { _loading = true; });
    try {
      // Fetch accepted offers for this passenger
      final offers = await ChatService.getOffersForPassenger(widget.passengerId, 'accepted');
      print('DEBUG: Offers for passenger ${widget.passengerId}: $offers');
      
      if (offers.isNotEmpty) {
        // Sort offers by timestamp descending
        offers.sort((a, b) {
          final tsA = a['timestamp'];
          final tsB = b['timestamp'];
          if (tsA is Timestamp && tsB is Timestamp) {
            return tsB.compareTo(tsA);
          }
          return 0;
        });
        final offer = offers.first;
        final chatId = offer['chatId'];
        final driverId = offer['offerData']?['driverId'] ?? offer['driverId'];
        final routeId = offer['offerData']?['routeId'] ?? offer['routeId'];
        print('DEBUG: driverId=$driverId, routeId=$routeId');
        if (driverId == null || routeId == null) {
          print('ERROR: driverId or routeId is null in accepted offer: $offer');
          return;
        }
        _acceptedOffers = offers;
        _acceptedOfferData = offer['offerData'];
        // Fetch driver profile
        final driverProfile = await FirebaseService.getRoutesByDriverId(driverId);
        print('DEBUG: Driver profile for $driverId: $driverProfile');
        _acceptedDriverProfile = driverProfile.isNotEmpty ? driverProfile.first : null;
        // Fetch driver route
        final driverRoute = await FirebaseService.getRouteById(routeId);
        print('DEBUG: Driver route for $routeId: $driverRoute');
        _acceptedDriverRoute = driverRoute;
        
        // Fetch driver contact number
        _driverContactNumber = await _fetchDriverContact(driverId);
      } else {
        print('DEBUG: No accepted offers found for passenger ${widget.passengerId}');
        _acceptedOffers = [];
        _acceptedDriverProfile = null;
        _acceptedDriverRoute = null;
        _acceptedOfferData = null;
        _driverContactNumber = null;
      }
    } catch (e) {
      print('Error loading active contract: $e');
    } finally {
      if (!mounted) return;
      setState(() { _loading = false; });
    }
  }

  Future<String> _fetchDriverContact(String driverId) async {
    try {
      final profile = await ChatService.getPassengerProfile(driverId);
      return profile?['number'] ?? '';
    } catch (e) {
      return '';
    }
  }

  void _navigateToChat() {
    if (_acceptedOffers.isNotEmpty) {
      final offer = _acceptedOffers.first;
      final chatId = offer['chatId'];
      final driverName = _acceptedDriverProfile?['driverName'] ?? 'Driver';
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatView(
            chatId: chatId,
            currentUserId: widget.passengerId,
            currentUserName: widget.passengerName,
            otherUserName: driverName,
            userRole: 'passenger',
          ),
        ),
      );
    }
  }

  Future<void> _callDriver() async {
    HapticFeedback.lightImpact();
    if (_driverContactNumber != null && _driverContactNumber!.isNotEmpty) {
      final url = 'tel:$_driverContactNumber';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _endContract() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('End Contract', style: TextStyle(color: Colors.black)),
        content: const Text('Are you sure you want to end this contract?', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End Contract', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && _acceptedOffers.isNotEmpty) {
      try {
        setState(() { _loading = true; });
        final offer = _acceptedOffers.first;
        await ChatService.deleteAcceptedOffer(
          chatId: offer['chatId'],
          messageId: offer['messageId'],
          driverId: offer['driverId'],
          driverName: offer['driverName'],
          passengerId: widget.passengerId,
          passengerName: widget.passengerName,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract ended successfully.'), backgroundColor: Colors.red),
        );
        Navigator.of(context).pop(); // Go back to passenger home
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ending contract: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() { _loading = false; });
        }
      }
    }
  }

  void _shareTripDetails() {
    final driverName = _acceptedDriverProfile?['driverName'] ?? 'Driver';
    final fromLocation = _acceptedDriverProfile?['fromLocation'] ?? '';
    final toLocation = _acceptedDriverProfile?['toLocation'] ?? '';
    final pickupTime = _acceptedOfferData?['pickupTime'] ?? '';
    
    final shareText = '''
🚗 EasyRide Trip Details

Driver: $driverName
From: $fromLocation
To: $toLocation
Pickup Time: $pickupTime
Status: $_tripStatus

Track my ride in real-time!
''';
    
    Share.share(shareText, subject: 'My EasyRide Trip');
  }

  void _showDriverRating() {
    final rating = _acceptedDriverProfile?['rating'] ?? 0.0;
    final reviewCount = _acceptedDriverProfile?['reviewCount'] ?? 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Driver Rating', style: TextStyle(color: Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 24,
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              '${rating.toStringAsFixed(1)} ($reviewCount reviews)',
              style: const TextStyle(color: Colors.black, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    if (_acceptedDriverProfile == null || _acceptedOfferData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Active Contract', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: const Center(
          child: Text(
            'No active contract found',
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
        ),
      );
    }

    final driverName = _acceptedDriverProfile?['driverName'] ?? 'Driver';
    final car = _acceptedDriverProfile?['car'] ?? '';
    final pickup = _acceptedOfferData?['pickupLocation'] ?? _acceptedDriverProfile?['fromLocation'] ?? '';
    final pickupTime = _acceptedOfferData?['pickupTime'] ?? '';
    
    // Fix pricing field names
    final seatCountRaw = _acceptedOfferData?['seatCount'];
    final seatCount = seatCountRaw is int ? seatCountRaw : (seatCountRaw is double ? seatCountRaw.toInt() : 1);
    final pricePerDayRaw = _acceptedOfferData?['pricePerDay'];
    final pricePerDay = pricePerDayRaw is int ? pricePerDayRaw.toDouble() : (pricePerDayRaw as double? ?? 0.0);
    final selectedDays = (_acceptedOfferData?['selectedDays'] as List<dynamic>? ?? []).length;
    final totalPrice = pricePerDay * seatCount * selectedDays;
    
    final fromLocation = _acceptedDriverProfile?['fromLocation'] ?? '';
    final toLocation = _acceptedDriverProfile?['toLocation'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Active Contract', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Go to Home',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => PassengerHomeView(
                    passengerId: widget.passengerId,
                    passengerName: widget.passengerName,
                    profile: widget.profile,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SlideTransition(
        position: _slideAnimation,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trip Status Card with Animation
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _tripStatus == 'En Route' ? _pulseAnimation.value : 1.0,
                                                 child: Container(
                           width: double.infinity,
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(
                             color: Colors.black,
                             borderRadius: BorderRadius.circular(16),
                             boxShadow: [
                               BoxShadow(
                                 color: Colors.black.withOpacity(0.1),
                                 blurRadius: 10,
                                 offset: const Offset(0, 4),
                               ),
                             ],
                           ),
                           child: Column(
                             children: [
                               Row(
                                 children: [
                                   Icon(
                                     _getStatusIcon(),
                                     color: Colors.white,
                                     size: 24,
                                   ),
                                   const SizedBox(width: 12),
                                   Expanded(
                                     child: Text(
                                       _tripStatus,
                                       style: const TextStyle(
                                         color: Colors.white,
                                         fontSize: 20,
                                         fontWeight: FontWeight.bold,
                                       ),
                                     ),
                                   ),
                                   if (_estimatedArrivalMinutes > 0)
                                     Container(
                                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                       decoration: BoxDecoration(
                                         color: Colors.white.withOpacity(0.2),
                                         borderRadius: BorderRadius.circular(20),
                                       ),
                                       child: Text(
                                         '${_estimatedArrivalMinutes} min',
                                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                       ),
                                     ),
                                 ],
                               ),
                               if (_estimatedArrivalMinutes > 0) ...[
                                 const SizedBox(height: 12),
                                 LinearProgressIndicator(
                                   value: (30 - _estimatedArrivalMinutes) / 30,
                                   backgroundColor: Colors.white.withOpacity(0.3),
                                   valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                 ),
                               ],
                             ],
                           ),
                         ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                                     // Driver Profile Card with Enhanced Design and Rating
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: Colors.black, width: 1),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.1),
                           blurRadius: 10,
                           offset: const Offset(0, 4),
                         ),
                       ],
                     ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                                                         Container(
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 border: Border.all(color: Colors.black, width: 2),
                               ),
                               child: CircleAvatar(
                                 radius: 30,
                                 backgroundColor: Colors.grey[200],
                                 backgroundImage: (_acceptedDriverProfile?['profileImageUrl'] != null && 
                                     (_acceptedDriverProfile?['profileImageUrl'] as String).isNotEmpty)
                                     ? NetworkImage(_acceptedDriverProfile!['profileImageUrl'])
                                     : null,
                                 child: (_acceptedDriverProfile?['profileImageUrl'] == null || 
                                     (_acceptedDriverProfile?['profileImageUrl'] as String).isEmpty)
                                     ? const Icon(Icons.person, color: Colors.black, size: 30)
                                     : null,
                               ),
                             ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                                                                 child: Text(
                                           driverName,
                                           style: const TextStyle(
                                             color: Colors.black,
                                             fontSize: 20,
                                             fontWeight: FontWeight.bold,
                                           ),
                                         ),
                                       ),
                                       if (_acceptedDriverProfile?['isVerified'] == true)
                                         const VerificationBadge(isVerified: true, size: 20),
                                     ],
                                   ),
                                   if (car.isNotEmpty)
                                                                           Text(
                                        car,
                                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                                      ),
                                  // Driver Rating
                                  if (_acceptedDriverProfile?['rating'] != null)
                                    InkWell(
                                      onTap: _showDriverRating,
                                      child: Row(
                                        children: [
                                          ...List.generate(5, (index) {
                                            final rating = _acceptedDriverProfile?['rating'] ?? 0.0;
                                            return Icon(
                                              index < rating ? Icons.star : Icons.star_border,
                                              color: Colors.amber,
                                              size: 16,
                                            );
                                          }),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${(_acceptedDriverProfile?['rating'] ?? 0.0).toStringAsFixed(1)}',
                                            style: const TextStyle(color: Colors.amber, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                                                 // Contact Information with Enhanced UI
                         if (_driverContactNumber != null && _driverContactNumber!.isNotEmpty)
                           Container(
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: Colors.grey[100],
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: Colors.grey[300]!),
                             ),
                             child: Row(
                               children: [
                                 Container(
                                   padding: const EdgeInsets.all(8),
                                   decoration: BoxDecoration(
                                     color: Colors.black,
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   child: const Icon(Icons.phone, color: Colors.white, size: 16),
                                 ),
                                 const SizedBox(width: 12),
                                 Expanded(
                                   child: Text(
                                     _driverContactNumber!,
                                     style: const TextStyle(color: Colors.black, fontSize: 16),
                                   ),
                                 ),
                                 InkWell(
                                   onTap: _callDriver,
                                   borderRadius: BorderRadius.circular(8),
                                   child: Container(
                                     padding: const EdgeInsets.all(8),
                                     decoration: BoxDecoration(
                                       color: Colors.green,
                                       borderRadius: BorderRadius.circular(8),
                                     ),
                                     child: const Icon(Icons.call, color: Colors.white, size: 16),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                                     // Trip Details Card with Enhanced Design
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: Colors.black, width: 1),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.1),
                           blurRadius: 10,
                           offset: const Offset(0, 4),
                         ),
                       ],
                     ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                                 Row(
                           children: [
                             Container(
                               padding: const EdgeInsets.all(8),
                               decoration: BoxDecoration(
                                 color: Colors.black,
                                 borderRadius: BorderRadius.circular(8),
                               ),
                               child: const Icon(Icons.route, color: Colors.white, size: 20),
                             ),
                             const SizedBox(width: 12),
                             const Text(
                               'Trip Details',
                               style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                             ),
                           ],
                         ),
                        const SizedBox(height: 16),
                        
                        // Route Information with Enhanced Icons
                        _buildRouteInfo(
                          icon: Icons.location_on,
                          iconColor: Colors.green,
                          title: 'From',
                          location: fromLocation,
                        ),
                        const SizedBox(height: 12),
                        _buildRouteInfo(
                          icon: Icons.location_on,
                          iconColor: Colors.red,
                          title: 'To',
                          location: toLocation,
                        ),
                        
                        if (pickup.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildRouteInfo(
                            icon: Icons.my_location,
                            iconColor: Colors.blue,
                            title: 'Pickup',
                            location: pickup,
                          ),
                        ],
                        
                        if (pickupTime.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildRouteInfo(
                            icon: Icons.access_time,
                            iconColor: Colors.orange,
                            title: 'Pickup Time',
                            location: pickupTime,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                                     // Pricing Card with Enhanced Design
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(20),
                     decoration: BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(16),
                       border: Border.all(color: Colors.black, width: 1),
                       boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.1),
                           blurRadius: 10,
                           offset: const Offset(0, 4),
                         ),
                       ],
                     ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                                 Row(
                           children: [
                             Container(
                               padding: const EdgeInsets.all(8),
                               decoration: BoxDecoration(
                                 color: Colors.black,
                                 borderRadius: BorderRadius.circular(8),
                               ),
                               child: const Icon(Icons.payment, color: Colors.white, size: 20),
                             ),
                             const SizedBox(width: 12),
                             const Text(
                               'Pricing',
                               style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                             ),
                           ],
                         ),
                        const SizedBox(height: 16),
                        
                        _buildPricingRow(
                          icon: Icons.airline_seat_recline_normal,
                          iconColor: Colors.blue,
                          label: 'Seats',
                          value: '$seatCount',
                        ),
                        
                        const SizedBox(height: 12),
                                                 _buildPricingRow(
                           icon: Icons.attach_money,
                           iconColor: Colors.green,
                           label: 'Per Day',
                           value: 'Rs. ${pricePerDay.toStringAsFixed(0)}',
                         ),
                        
                        const SizedBox(height: 12),
                        _buildPricingRow(
                          icon: Icons.calendar_today,
                          iconColor: Colors.purple,
                          label: 'Days',
                          value: '$selectedDays',
                        ),
                        
                        const Divider(color: Colors.grey, height: 24),
                        
                                                 _buildPricingRow(
                           icon: Icons.payment,
                           iconColor: Colors.orange,
                           label: 'Total',
                           value: 'Rs. ${totalPrice.toStringAsFixed(0)}',
                           isTotal: true,
                         ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                                     // Enhanced Action Buttons
                   Row(
                     children: [
                       Expanded(
                         child: _buildActionButton(
                           icon: Icons.chat,
                           label: 'Chat with Driver',
                           color: Colors.black,
                           onPressed: _navigateToChat,
                         ),
                       ),
                       const SizedBox(width: 16),
                       Expanded(
                         child: _buildActionButton(
                           icon: Icons.share,
                           label: 'Share Trip',
                           color: Colors.grey[700]!,
                           onPressed: _shareTripDetails,
                         ),
                       ),
                       const SizedBox(width: 16),
                       Expanded(
                         child: _buildActionButton(
                           icon: Icons.cancel,
                           label: 'End Contract',
                           color: Colors.red,
                           onPressed: _endContract,
                         ),
                       ),
                     ],
                   ),
                ],
              ),
                         ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String location,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              Text(
                location,
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isTotal = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.black,
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        shadowColor: color.withOpacity(0.2),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_tripStatus) {
      case 'En Route':
        return Colors.black;
      case 'Arrived':
        return Colors.black;
      case 'In Progress':
        return Colors.black;
      case 'Completed':
        return Colors.black;
      default:
        return Colors.black;
    }
  }

  List<Color> _getStatusGradient() {
    return [
      Colors.black,
      Colors.black.withOpacity(0.8),
    ];
  }

  IconData _getStatusIcon() {
    switch (_tripStatus) {
      case 'En Route':
        return Icons.directions_car;
      case 'Arrived':
        return Icons.location_on;
      case 'In Progress':
        return Icons.trending_up;
      case 'Completed':
        return Icons.check_circle;
      default:
        return Icons.directions_car;
    }
  }
} 