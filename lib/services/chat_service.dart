import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _chatsCollection = 'chats';
  static const String _messagesCollection = 'messages';

  // Create a new chat between passenger and driver
  static Future<String> createChat({
    required String passengerId,
    required String passengerName,
    required String driverId,
    required String driverName,
    required String routeId,
    required double matchPercentage,
  }) async {
    try {
      // Check if chat already exists
      final existingChat = await _firestore
          .collection(_chatsCollection)
          .where('passengerId', isEqualTo: passengerId)
          .where('driverId', isEqualTo: driverId)
          .get();

      if (existingChat.docs.isNotEmpty) {
        return existingChat.docs.first.id;
      }

      // Create new chat
      final chatDoc = await _firestore.collection(_chatsCollection).add({
        'passengerId': passengerId,
        'passengerName': passengerName,
        'driverId': driverId,
        'driverName': driverName,
        'routeId': routeId,
        'matchPercentage': matchPercentage,
        'status': 'active', // active, completed, cancelled
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'unreadCount': 0,
      });

      return chatDoc.id;
    } catch (e) {
      rethrow;
    }
  }

  // Send a message (text or offer)
  static Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String message,
    String type = 'text',
    Map<String, dynamic>? offerData,
  }) async {
    try {
      // Add message to messages subcollection
      final messageData = {
        'senderId': senderId,
        'senderName': senderName,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      };
      if (type == 'offer' && offerData != null) {
        messageData['type'] = 'offer';
        messageData['offerData'] = offerData;
      }
      await _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .add(messageData);

      // Update chat with last message info
      await _firestore.collection(_chatsCollection).doc(chatId).update({
        'lastMessage': type == 'offer' ? 'Ride offer sent' : message,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCount': FieldValue.increment(1),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update offer status (accept/reject)
  static Future<void> updateOfferStatus({
    required String chatId,
    required String messageId,
    required String status, // 'accepted' or 'rejected'
  }) async {
    try {
      // Get the current chat data
      final chatDoc = await _firestore.collection(_chatsCollection).doc(chatId).get();
      if (!chatDoc.exists) return;
      final chatData = chatDoc.data()!;
      final driverId = chatData['driverId'];
      final passengerId = chatData['passengerId'];

      if (status == 'accepted') {
        // Check for existing active contract between this driver and passenger
        final existing = await _firestore
          .collection(_chatsCollection)
          .where('driverId', isEqualTo: driverId)
          .where('passengerId', isEqualTo: passengerId)
          .where('status', isEqualTo: 'accepted')
          .get();
        // If there is already an active contract (other than this chat), prevent accepting another
        if (existing.docs.any((doc) => doc.id != chatId)) {
          throw Exception('There is already an active contract with this passenger.');
        }
      }

      // Get the current message data
      final messageDoc = await _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .doc(messageId)
          .get();

      if (messageDoc.exists) {
        final messageData = messageDoc.data()!;
        final offerData = Map<String, dynamic>.from(messageData['offerData'] as Map<String, dynamic>);
        offerData['status'] = status;

        // Update the message with the new offer data
        await _firestore
            .collection(_chatsCollection)
            .doc(chatId)
            .collection(_messagesCollection)
            .doc(messageId)
            .update({
          'offerData': offerData,
        });

        // If accepted, update chat status and send a notification message
        if (status == 'accepted') {
          await _firestore.collection(_chatsCollection).doc(chatId).update({
            'status': 'accepted',
          });
          await sendMessage(
            chatId: chatId,
            senderId: 'system',
            senderName: 'System',
            message: 'Offer accepted! The ride contract is now active.',
          );
        } else if (status == 'rejected') {
          await sendMessage(
            chatId: chatId,
            senderId: 'system',
            senderName: 'System',
            message: 'Offer rejected.',
          );
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get chat messages
  static Stream<QuerySnapshot> getChatMessages(String chatId) {
    return _firestore
        .collection(_chatsCollection)
        .doc(chatId)
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Get messages stream (alias for getChatMessages for consistency)
  static Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return getChatMessages(chatId);
  }

  // Get chats for a user (passenger or driver)
  static Stream<QuerySnapshot> getUserChats(String userId, String userRole) {
    if (userRole == 'passenger') {
      return _firestore
          .collection(_chatsCollection)
          .where('passengerId', isEqualTo: userId)
          .orderBy('lastMessageAt', descending: true)
          .snapshots();
    } else {
      return _firestore
          .collection(_chatsCollection)
          .where('driverId', isEqualTo: userId)
          .orderBy('lastMessageAt', descending: true)
          .snapshots();
    }
  }

  // Mark messages as read
  static Future<void> markChatAsRead(String chatId) async {
    try {
      await _firestore.collection(_chatsCollection).doc(chatId).update({
        'unreadCount': 0,
      });
    } catch (e) {
      // Do nothing
    }
  }

  // Get chat by ID
  static Future<Map<String, dynamic>?> getChatById(String chatId) async {
    try {
      final doc = await _firestore.collection(_chatsCollection).doc(chatId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update chat status
  static Future<void> updateChatStatus(String chatId, String status) async {
    try {
      await _firestore.collection(_chatsCollection).doc(chatId).update({
        'status': status,
      });
    } catch (e) {
      // Do nothing
    }
  }

  // Get offers for a driver by status (e.g., 'accepted', 'cancelled')
  static Future<List<Map<String, dynamic>>> getOffersForDriver(String driverId, String status) async {
    try {
      List<Map<String, dynamic>> offers = [];
      // Get all chats for this driver
      final chats = await _firestore
          .collection(_chatsCollection)
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: status)
          .get();

      for (final chatDoc in chats.docs) {
        final chatId = chatDoc.id;
        // Get all messages in this chat
        final messages = await _firestore
            .collection(_chatsCollection)
            .doc(chatId)
            .collection(_messagesCollection)
            .where('type', isEqualTo: 'offer')
            .get();

        for (final messageDoc in messages.docs) {
          final messageData = messageDoc.data();
          final offerData = messageData['offerData'] as Map<String, dynamic>?;
          if (offerData != null && offerData['status'] == status) {
            // Get chat data to include passenger info
            final chatData = chatDoc.data();
            offers.add({
              'chatId': chatId,
              'messageId': messageDoc.id,
              'passengerId': chatData['passengerId'],
              'passengerName': chatData['passengerName'],
              'offerData': offerData,
              'timestamp': messageData['timestamp'],
            });
          }
        }
      }
      return offers;
    } catch (e) {
      return [];
    }
  }

  // Get offers for a passenger by status (e.g., 'accepted', 'cancelled')
  static Future<List<Map<String, dynamic>>> getOffersForPassenger(String passengerId, String status) async {
    try {
      List<Map<String, dynamic>> offers = [];
      // Get all chats for this passenger
      final chats = await _firestore
          .collection(_chatsCollection)
          .where('passengerId', isEqualTo: passengerId)
          .where('status', isEqualTo: status)
          .get();

      for (final chatDoc in chats.docs) {
        final chatId = chatDoc.id;
        // Get all messages in this chat
        final messages = await _firestore
            .collection(_chatsCollection)
            .doc(chatId)
            .collection(_messagesCollection)
            .where('type', isEqualTo: 'offer')
            .get();

        for (final messageDoc in messages.docs) {
          final messageData = messageDoc.data();
          final offerData = messageData['offerData'] as Map<String, dynamic>?;
          if (offerData != null && offerData['status'] == status) {
            // Get chat data to include driver info
            final chatData = chatDoc.data();
            offers.add({
              'chatId': chatId,
              'messageId': messageDoc.id,
              'driverId': chatData['driverId'],
              'driverName': chatData['driverName'],
              'offerData': offerData,
              'timestamp': messageData['timestamp'],
            });
          }
        }
      }
      return offers;
    } catch (e) {
      return [];
    }
  }

  // Get passenger route for accepted offer
  static Future<Map<String, dynamic>?> getPassengerRoute(String passengerId) async {
    try {
      // Get the most recent route for this passenger
      final routes = await FirebaseService.getRoutesByPassengerId(passengerId);
      if (routes.isNotEmpty) {
        return routes.first;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get passenger profile data including contact number
  static Future<Map<String, dynamic>?> getPassengerProfile(String passengerId) async {
    try {
      // Get passenger profile from users collection
      final users = FirebaseService.firestore.collection('users');
      
      // Try to find by email first
      var snap = await users.where('email', isEqualTo: passengerId).get();
      if (snap.docs.isEmpty) {
        // Try to find by number if email search failed
        snap = await users.where('number', isEqualTo: passengerId).get();
      }
      
      if (snap.docs.isNotEmpty) {
        final userData = snap.docs.first.data();
        return {
          'name': userData['name'] ?? 'Unknown',
          'email': userData['email'] ?? '',
          'number': userData['number'] ?? '',
          'profileImageUrl': userData['profileImageUrl'] ?? '',
          'role': userData['role'] ?? 'passenger',
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Delete accepted offer and notify passenger
  static Future<void> deleteAcceptedOffer({
    required String chatId,
    required String messageId,
    required String driverId,
    required String driverName,
    required String passengerId,
    required String passengerName,
  }) async {
    try {
      // Update the offer status to 'cancelled'
      await _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .doc(messageId)
          .update({
        'offerData.status': 'cancelled',
      });

      // Send a notification message to the passenger
      await sendMessage(
        chatId: chatId,
        senderId: driverId,
        senderName: driverName,
        message: 'Contract ended: Your ride request has been cancelled by the driver.',
      );

      // Update chat status to cancelled
      await updateChatStatus(chatId, 'cancelled');
    } catch (e) {
      rethrow;
    }
  }

  // Complete trip and notify passenger
  static Future<void> completeTrip({
    required String chatId,
    required String messageId,
    required String driverId,
    required String driverName,
    required String passengerId,
    required String passengerName,
  }) async {
    try {
      // Update the offer status to 'completed'
      await _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .doc(messageId)
          .update({
        'offerData.status': 'completed',
      });

      // Send a notification message to the passenger
      await sendMessage(
        chatId: chatId,
        senderId: driverId,
        senderName: driverName,
        message: 'Trip completed! Thank you for choosing our service. You can now review your driver.',
      );

      // Update chat status to completed
      await updateChatStatus(chatId, 'completed');
    } catch (e) {
      rethrow;
    }
  }
} 