import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../services/review_service.dart';
import '../widgets/verification_badge.dart';
import '../models/review.dart';
import '../widgets/review_widget.dart';
import 'driver_reviews_view.dart';

class DriverPublicProfileView extends StatefulWidget {
  final String driverId;
  final String driverName;
  
  const DriverPublicProfileView({
    super.key,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<DriverPublicProfileView> createState() => _DriverPublicProfileViewState();
}

class _DriverPublicProfileViewState extends State<DriverPublicProfileView> {
  Map<String, dynamic>? profile;
  bool loading = true;
  List<String> _carImageUrls = [];
  double _averageRating = 0.0;
  int _reviewCount = 0;
  bool _reviewsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final users = FirebaseService.firestore.collection('users');
      final snap = await users.where('email', isEqualTo: widget.driverId).get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        setState(() {
          profile = data;
          loading = false;
          _carImageUrls = List<String>.from(data['carImageUrls'] ?? []);
        });
        await _loadReviewStats();
      } else {
        final snap2 = await users.where('number', isEqualTo: widget.driverId).get();
        if (snap2.docs.isNotEmpty) {
          final data = snap2.docs.first.data();
          setState(() {
            profile = data;
            loading = false;
            _carImageUrls = List<String>.from(data['carImageUrls'] ?? []);
          });
          await _loadReviewStats();
        } else {
          setState(() { loading = false; });
          await _loadReviewStats();
        }
      }
    } catch (e) {
      setState(() { 
        loading = false; 
        profile = null;
      });
      await _loadReviewStats();
    }
  }

  Future<void> _loadReviewStats() async {
    try {
      final averageRating = await ReviewService.getDriverAverageRating(widget.driverId);
      final reviewCount = await ReviewService.getDriverReviewCount(widget.driverId);
      
      if (mounted) {
        setState(() {
          _averageRating = averageRating;
          _reviewCount = reviewCount;
          _reviewsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reviewsLoading = false;
        });
      }
    }
  }

  Widget _buildCarPhotosSection() {
    if (_carImageUrls.isEmpty) return const SizedBox();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Car Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _carImageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _carImageUrls[idx],
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 90,
                        height: 90,
                        color: Colors.grey[800],
                        child: const Icon(Icons.error, color: Colors.white),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Reviews', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              const Spacer(),
              if (_reviewCount > 3)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DriverReviewsView(
                          driverId: widget.driverId,
                          driverName: profile?['name'] ?? widget.driverName,
                        ),
                      ),
                    );
                  },
                  child: const Text('View All', style: TextStyle(color: Colors.blue)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_reviewsLoading)
            const Center(child: CircularProgressIndicator())
          else if (_reviewCount == 0)
            const Text('No reviews yet', style: TextStyle(color: Colors.grey))
          else ...[
            // Rating summary
            Row(
              children: [
                Text(
                  _averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.star, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Text(
                  '($_reviewCount reviews)',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Recent reviews
            StreamBuilder<List<Review>>(
              stream: ReviewService.getDriverReviews(widget.driverId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Text('Error loading reviews', style: TextStyle(color: Colors.red));
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final reviews = snapshot.data ?? [];
                if (reviews.isEmpty) {
                  return const Text('No reviews yet', style: TextStyle(color: Colors.grey));
                }
                
                return Column(
                  children: reviews.take(3).map((review) => ReviewWidget(
                    review: review,
                    showPassengerName: true,
                  )).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF181818),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF181818),
        appBar: AppBar(
          title: Text(widget.driverName, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF181818),
        ),
        body: const Center(
          child: Text('Driver profile not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF181818),
      appBar: AppBar(
        title: Text(profile!['name'] ?? widget.driverName, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF181818),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Profile Image
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: profile!['profileImageUrl'] != null
                        ? NetworkImage(profile!['profileImageUrl'])
                        : null,
                    backgroundColor: Colors.grey[800],
                    child: profile!['profileImageUrl'] == null
                        ? const Icon(Icons.person, size: 50, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Driver Name with Verification Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        profile!['name'] ?? widget.driverName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (profile!['isVerified'] == true)
                        const VerificationBadge(isVerified: true, size: 20),
                    ],
                  ),
                  
                  // Contact Number (if available)
                  if (profile!['number'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '📞 ${profile!['number']}',
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                  ],
                  
                  // License Number (if available)
                  if (profile!['licenseNumber'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '🚗 License: ${profile!['licenseNumber']}',
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Car Photos Section
            _buildCarPhotosSection(),
            
            const SizedBox(height: 20),
            
            // Reviews Section
            _buildReviewsSection(),
            
            const SizedBox(height: 20),
            
            // Verification Status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verification Status',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.verified, color: Colors.green, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        profile!['isVerified'] == true ? 'Verified Driver' : 'Pending Verification',
                        style: TextStyle(
                          color: profile!['isVerified'] == true ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
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
} 