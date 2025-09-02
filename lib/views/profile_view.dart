import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/session_service.dart';
import '../widgets/verification_badge.dart';
import '../services/review_service.dart';
import '../models/review.dart';
import '../widgets/review_widget.dart';
import '../widgets/review_form_widget.dart';
import 'driver_reviews_view.dart';

class ProfileView extends StatefulWidget {
  final String userId; // email or number
  const ProfileView({super.key, required this.userId});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  Map<String, dynamic>? profile;
  bool loading = true;
  List<String> _carImageUrls = [];
  bool _carImagesLoading = false;
  double _averageRating = 0.0;
  int _reviewCount = 0;
  bool _reviewsLoading = true;
  
  bool get isOwnProfile {
    // You may want to use a session/user service for the current userId
    // For now, compare widget.userId to profile?['email'] or profile?['number']
    if (profile == null) return false;
    final currentId = profile?['email'] ?? profile?['number'];
    return widget.userId == currentId;
  }

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final users = FirebaseService.firestore.collection('users');
      final snap = await users.where('email', isEqualTo: widget.userId).get();
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        setState(() {
          profile = data;
          loading = false;
          _carImageUrls = List<String>.from(data['carImageUrls'] ?? []);
        });
        // Load review stats after profile is loaded
        await _loadReviewStats();
      } else {
        final snap2 = await users.where('number', isEqualTo: widget.userId).get();
        if (snap2.docs.isNotEmpty) {
          final data = snap2.docs.first.data();
          setState(() {
            profile = data;
            loading = false;
            _carImageUrls = List<String>.from(data['carImageUrls'] ?? []);
          });
          // Load review stats after profile is loaded
          await _loadReviewStats();
        } else {
          setState(() { loading = false; });
          // Load review stats even if profile not found
          await _loadReviewStats();
        }
      }
    } catch (e) {
      setState(() { 
        loading = false; 
        profile = null;
      });
      // Load review stats even if there's an error
      await _loadReviewStats();
    }
  }

  Future<void> _pickAndUploadCarImage() async {
    dynamic image;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) image = File(picked.path);
    if (image != null) {
      setState(() { _carImagesLoading = true; });
      final url = await FirebaseService.uploadImageToImgbb(image);
      setState(() {
        _carImageUrls.add(url);
      });
      await _saveCarImagesToFirestore();
      setState(() { _carImagesLoading = false; });
    }
  }

  Future<void> _removeCarImage(int index) async {
    setState(() { _carImageUrls.removeAt(index); });
    await _saveCarImagesToFirestore();
  }

  Future<void> _saveCarImagesToFirestore() async {
    final users = FirebaseService.firestore.collection('users');
    final snap = await users.where('email', isEqualTo: widget.userId).get();
    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first.reference;
      await doc.update({'carImageUrls': _carImageUrls});
    }
  }

  Future<void> _addOrEditImage(String type) async {
    // Check if driver is verified and trying to edit CNIC or license
    if (profile?['role'] == 'driver' && 
        profile?['isVerified'] == true && 
        (type == 'cnic' || type == 'license')) {
      // Show error message for verified drivers
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot edit ${type == 'cnic' ? 'CNIC' : 'license'} image after verification. Contact admin for changes.',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    dynamic image;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) image = File(picked.path);
    if (image != null) {
      final url = await FirebaseService.uploadImageToImgbb(image);
      final users = FirebaseService.firestore.collection('users');
      final snap = await users.where('email', isEqualTo: widget.userId).get();
      if (snap.docs.isNotEmpty) {
        final doc = snap.docs.first.reference;
        await doc.update({
          if (type == 'cnic') 'cnicImageUrl': url,
          if (type == 'license') 'licenseImageUrl': url,
        });
        _fetchProfile();
      }
    }
  }

  Future<void> _loadReviewStats() async {
    if (profile != null && profile!['role'] == 'driver') {
      try {
        final averageRating = await ReviewService.getDriverAverageRating(widget.userId);
        final reviewCount = await ReviewService.getDriverReviewCount(widget.userId);
        
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
    } else {
      setState(() {
        _reviewsLoading = false;
      });
    }
  }

  Widget _buildCarPhotosSection() {
    // Only show for drivers
    if (profile == null || profile!['role'] != 'driver') return const SizedBox();
    if (!isOwnProfile && _carImageUrls.isEmpty) return const SizedBox();
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
            child: Row(
              children: [
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _carImageUrls.length + (isOwnProfile && profile!['role'] == 'driver' && _carImageUrls.length < 4 ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, idx) {
                      if (idx < _carImageUrls.length) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                _carImageUrls[idx],
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            if (isOwnProfile && profile!['role'] == 'driver')
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeCarImage(idx),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                          ],
                        );
                      } else {
                        // Add button (only for own driver profile)
                        if (isOwnProfile && profile!['role'] == 'driver') {
                          return GestureDetector(
                            onTap: _carImagesLoading ? null : _pickAndUploadCarImage,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[400]!, width: 2),
                              ),
                              child: _carImagesLoading
                                  ? const Center(child: CircularProgressIndicator())
                                  : const Icon(Icons.add_a_photo, size: 32, color: Colors.black54),
                            ),
                          );
                        } else {
                          return const SizedBox();
                        }
                      }
                    },
                  ),
                ),
              ],
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
              const Icon(Icons.star, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Reviews',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              const Spacer(),
              if (_reviewsLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                Row(
                  children: [
                    Text(
                      '${_averageRating.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      '/5',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '($_reviewCount reviews)',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (_reviewsLoading)
            const Center(child: CircularProgressIndicator())
          else if (_reviewCount == 0)
            Center(
              child: Column(
                children: [
                  Icon(Icons.star_border, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    'No reviews yet',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ],
              ),
            )
          else
                         StreamBuilder<List<Review>>(
               stream: ReviewService.getDriverReviews(widget.userId),
               builder: (context, snapshot) {
                 if (snapshot.hasError) {
                   print('StreamBuilder error: ${snapshot.error}');
                   return Center(
                     child: Column(
                       children: [
                         Icon(Icons.error, size: 48, color: Colors.red[400]),
                         const SizedBox(height: 8),
                         Text(
                           'Error loading reviews',
                           style: TextStyle(color: Colors.red[400]),
                         ),
                         const SizedBox(height: 4),
                         Text(
                           '${snapshot.error}',
                           style: TextStyle(color: Colors.red[300], fontSize: 12),
                           textAlign: TextAlign.center,
                         ),
                       ],
                     ),
                   );
                 }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reviews = snapshot.data!;
                if (reviews.isEmpty) {
                  return Center(
                    child: Column(
                      children: [
                        Icon(Icons.star_border, size: 48, color: Colors.grey[600]),
                        const SizedBox(height: 8),
                        Text(
                          'No reviews yet',
                          style: TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: reviews.take(3).map((review) => ReviewWidget(
                    review: review,
                    showPassengerName: true,
                  )).toList(),
                );
              },
            ),
          if (_reviewCount > 3)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DriverReviewsView(driverId: widget.userId, driverName: profile?['name'] ?? 'Driver'),
                      ),
                    );
                  },
                  child: const Text(
                    'View All Reviews',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              const Text(
                'Loading Profile...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (profile == null) {
      return Scaffold(
        body: Center(child: Text('Profile not found', style: TextStyle(color: Colors.white))),
        backgroundColor: Colors.black,
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              top: 32.0,
              bottom: 120.0, // Extra bottom padding to account for logout button
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile image at the top with border
                Container(
                  margin: const EdgeInsets.only(top: 0, bottom: 16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                      width: 4,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: profile?['profileImageUrl'] != null ? NetworkImage(profile!['profileImageUrl']) : null,
                    backgroundColor: Colors.grey[900],
                    child: profile?['profileImageUrl'] == null ? const Icon(Icons.person, size: 60, color: Colors.white) : null,
                    onBackgroundImageError: (exception, stackTrace) {},
                  ),
                ),
                const SizedBox(height: 16),
                // --- Redesigned Profile Details Card ---
                Card(
                  color: Colors.grey[900],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                profile?['name'] ?? '',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            if (profile?['role'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: profile!['role'] == 'driver' ? Colors.blue[700] : Colors.green[700],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  profile!['role'].toUpperCase(),
                                  style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (profile?['email'] != null)
                          Row(
                            children: [
                              const Icon(Icons.email, color: Colors.white70, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  profile!['email'],
                                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        if (profile?['email'] != null) const SizedBox(height: 10),
                        if (profile?['number'] != null)
                          Row(
                            children: [
                              const Icon(Icons.phone, color: Colors.white70, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  profile!['number'],
                                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        if (profile?['number'] != null) const SizedBox(height: 10),
                        if (profile?['cnic'] != null)
                          Row(
                            children: [
                              const Icon(Icons.credit_card, color: Colors.white70, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  profile!['cnic'],
                                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                // --- End Redesigned Profile Details Card ---
                const SizedBox(height: 28),
                ...(profile != null && profile!['role'] == 'driver' ? [_buildCarPhotosSection()] : []),
                const SizedBox(height: 28),
                // Reviews Section (only for drivers)
                if (profile != null && profile!['role'] == 'driver') ...[
                  _buildReviewsSection(),
                  const SizedBox(height: 28),
                ],
                Divider(color: Colors.grey[700]),
                // CNIC Image Panel
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: profile?['cnicImageUrl'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              profile!['cnicImageUrl'],
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.credit_card, size: 40, color: Colors.white);
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator());
                              },
                            ),
                          )
                        : const Icon(Icons.credit_card, size: 40, color: Colors.white),
                  ),
                  title: Row(
                    children: [
                      const Text('CNIC Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      if (profile?['role'] == 'driver' && profile?['isVerified'] == true) ...[
                        const VerificationBadge(isVerified: true, size: 16),
                        const SizedBox(width: 4),
                        const Icon(Icons.lock, color: Colors.grey, size: 16),
                      ],
                    ],
                  ),
                  trailing: profile?['role'] == 'driver' && profile?['isVerified'] == true
                      ? IconButton(
                          icon: const Icon(Icons.lock, color: Colors.grey),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'CNIC image is locked after verification. Contact admin for changes.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          },
                        )
                      : profile?['cnicImageUrl'] == null
                          ? IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () => _addOrEditImage('cnic'))
                          : IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => _addOrEditImage('cnic')),
                ),
                Divider(color: Colors.grey[700]),
                // License Image Panel
                if (profile?['role'] == 'driver')
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: profile?['licenseImageUrl'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                profile!['licenseImageUrl'],
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.badge, size: 40, color: Colors.white);
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                              ),
                            )
                          : const Icon(Icons.badge, size: 40, color: Colors.white),
                    ),
                    title: Row(
                      children: [
                        const Text('License Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (profile?['role'] == 'driver' && profile?['isVerified'] == true) ...[
                          const VerificationBadge(isVerified: true, size: 16),
                          const SizedBox(width: 4),
                          const Icon(Icons.lock, color: Colors.grey, size: 16),
                        ],
                      ],
                    ),
                    trailing: profile?['role'] == 'driver' && profile?['isVerified'] == true
                        ? IconButton(
                            icon: const Icon(Icons.lock, color: Colors.grey),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'License image is locked after verification. Contact admin for changes.',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            },
                          )
                        : profile?['licenseImageUrl'] == null
                            ? IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () => _addOrEditImage('license'))
                            : IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: () => _addOrEditImage('license')),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomSheet: profile != null
          ? Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF181818), // matte black
                    foregroundColor: const Color(0xFFF8F8F8), // soft white
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    await SessionService.clearSession();
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    }
                  },
                ),
              ),
            )
          : null,
    );
  }
} 