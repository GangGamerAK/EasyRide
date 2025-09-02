import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _reviewsCollection = 'reviews';

  // Create a new review
  static Future<String> createReview({
    required String driverId,
    required String passengerId,
    required String passengerName,
    required int rating,
    required String comment,
    String? tripDate,
    String? routeId,
    bool isVerified = false,
  }) async {
    try {
      final reviewData = {
        'driverId': driverId,
        'passengerId': passengerId,
        'passengerName': passengerName,
        'rating': rating,
        'comment': comment,
        'tripDate': tripDate,
        'routeId': routeId,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': isVerified,
      };

      final docRef = await _firestore.collection(_reviewsCollection).add(reviewData);
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  // Get all reviews for a driver
  static Stream<List<Review>> getDriverReviews(String driverId) {
    return _firestore
        .collection(_reviewsCollection)
        .where('driverId', isEqualTo: driverId)
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList();
          // Sort by createdAt descending in memory to avoid index requirement
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }

  // Get average rating for a driver
  static Future<double> getDriverAverageRating(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection(_reviewsCollection)
          .where('driverId', isEqualTo: driverId)
          .get();

      if (snapshot.docs.isEmpty) return 0.0;

      int totalRating = 0;
      int reviewCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rating = data['rating'] as int? ?? 0;
        totalRating += rating;
        reviewCount++;
      }

      return reviewCount > 0 ? totalRating / reviewCount : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // Get review count for a driver
  static Future<int> getDriverReviewCount(String driverId) async {
    try {
      final snapshot = await _firestore
          .collection(_reviewsCollection)
          .where('driverId', isEqualTo: driverId)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  // Check if a passenger has already reviewed a driver
  static Future<bool> hasPassengerReviewedDriver(String passengerId, String driverId) async {
    try {
      final snapshot = await _firestore
          .collection(_reviewsCollection)
          .where('passengerId', isEqualTo: passengerId)
          .where('driverId', isEqualTo: driverId)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Check if passenger has a completed trip with driver
  static Future<bool> hasCompletedTrip(String passengerId, String driverId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .where('passengerId', isEqualTo: passengerId)
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Update a review
  static Future<void> updateReview(String reviewId, {
    int? rating,
    String? comment,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      if (rating != null) updateData['rating'] = rating;
      if (comment != null) updateData['comment'] = comment;

      await _firestore.collection(_reviewsCollection).doc(reviewId).update(updateData);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a review
  static Future<void> deleteReview(String reviewId) async {
    try {
      await _firestore.collection(_reviewsCollection).doc(reviewId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Get reviews by passenger
  static Stream<List<Review>> getPassengerReviews(String passengerId) {
    return _firestore
        .collection(_reviewsCollection)
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Review.fromFirestore(doc)).toList());
  }
} 