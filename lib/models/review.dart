import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String driverId;
  final String passengerId;
  final String passengerName;
  final int rating;
  final String comment;
  final String? tripDate;
  final String? routeId;
  final DateTime createdAt;
  final bool isVerified;

  Review({
    required this.id,
    required this.driverId,
    required this.passengerId,
    required this.passengerName,
    required this.rating,
    required this.comment,
    this.tripDate,
    this.routeId,
    required this.createdAt,
    required this.isVerified,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      id: doc.id,
      driverId: data['driverId'] ?? '',
      passengerId: data['passengerId'] ?? '',
      passengerName: data['passengerName'] ?? '',
      rating: data['rating'] ?? 0,
      comment: data['comment'] ?? '',
      tripDate: data['tripDate'],
      routeId: data['routeId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isVerified: data['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'driverId': driverId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'rating': rating,
      'comment': comment,
      'tripDate': tripDate,
      'routeId': routeId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isVerified': isVerified,
    };
  }
} 