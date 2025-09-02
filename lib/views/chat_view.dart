import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import '../widgets/chat_offer_widget.dart';
import '../utils/color_utils.dart';
import 'profile_view.dart';
import '../services/firebase_service.dart'; // Added import for FirebaseService
import '../widgets/verification_badge.dart';
import '../services/review_service.dart';
import '../widgets/review_form_widget.dart';
import '../models/review.dart';
import 'driver_reviews_view.dart';
import 'driver_public_profile_view.dart';

class ChatView extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String currentUserName;
  final String otherUserName;
  final String userRole; // 'passenger' or 'driver'
  
  const ChatView({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherUserName,
    required this.userRole,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Mark chat as read when opened
    ChatService.markChatAsRead(widget.chatId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await ChatService.sendMessage(
        chatId: widget.chatId,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        message: message,
      );

      _messageController.clear();
      
      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendOffer(Map<String, dynamic> offerData) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ChatService.sendMessage(
        chatId: widget.chatId,
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        message: '', // or a summary if you want
        type: 'offer',
        offerData: offerData,
      );

      // Scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending offer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptOffer(String messageId) async {
    try {
      await ChatService.updateOfferStatus(
        chatId: widget.chatId,
        messageId: messageId,
        status: 'accepted',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer accepted!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting offer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectOffer(String messageId) async {
    try {
      await ChatService.updateOfferStatus(
        chatId: widget.chatId,
        messageId: messageId,
        status: 'rejected',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offer rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rejecting offer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showOfferDialog() {
    // Get match percentage and routeId from chat data
    ChatService.getChatById(widget.chatId).then((chatData) {
      if (chatData != null) {
        final matchPercentage = chatData['matchPercentage'] as double? ?? 0.0;
        final routeId = chatData['routeId'] as String? ?? '';
        showDialog(
          context: context,
          builder: (context) => ChatOfferWidget(
            chatId: widget.chatId,
            senderId: widget.currentUserId,
            senderName: widget.currentUserName,
            matchPercentage: matchPercentage,
            onSendOffer: _sendOffer,
            routeId: routeId,
          ),
        );
      }
    });
  }

  void _editOffer(Map<String, dynamic> offerData, String messageId) {
    // Get match percentage and routeId from chat data
    ChatService.getChatById(widget.chatId).then((chatData) {
      if (chatData != null) {
        final matchPercentage = chatData['matchPercentage'] as double? ?? 0.0;
        final routeId = chatData['routeId'] as String? ?? '';
        showDialog(
          context: context,
          builder: (context) => ChatOfferWidget(
            chatId: widget.chatId,
            senderId: widget.currentUserId,
            senderName: widget.currentUserName,
            matchPercentage: matchPercentage,
            onSendOffer: _sendOffer,
            existingOffer: offerData,
            routeId: routeId,
          ),
        );
      }
    });
  }

  Widget _buildMessageWidget(Map<String, dynamic> message, String messageId) {
    final senderId = message['senderId'] as String? ?? '';
    final senderName = message['senderName'] as String? ?? 'Unknown';
    final messageText = message['message'] as String? ?? '';
    final timestamp = message['timestamp'] as Timestamp?;
    final type = message['type'] as String? ?? 'text';
    
    final isMyMessage = senderId == widget.currentUserId;
    
    // Handle different message types
    if (type == 'offer') {
      final offerData = message['offerData'] as Map<String, dynamic>? ?? {};
      return ChatOfferDisplayWidget(
        offerData: offerData,
        isMyMessage: isMyMessage,
        userRole: widget.userRole,
        onAccept: () => _acceptOffer(messageId),
        onReject: () => _rejectOffer(messageId),
        onEdit: () => _editOffer(offerData, messageId),
      );
    }
    
    // Regular text message
    return Container(
      margin: EdgeInsets.only(
        left: isMyMessage ? 50 : 8,
        right: isMyMessage ? 8 : 50,
        top: 4,
        bottom: 4,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMyMessage ? ColorUtils.softWhite.withOpacity(0.12) : Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMyMessage)
            Text(
              senderName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          Text(
            messageText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (timestamp != null)
            Text(
              _formatTimestamp(timestamp),
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showDriverProfile() async {
    // Fetch chat document to get driverId
    final chatData = await ChatService.getChatById(widget.chatId);
    if (chatData != null && chatData['driverId'] != null) {
      final driverId = chatData['driverId'];
      
      // Fetch driver profile data
      final users = FirebaseService.firestore.collection('users');
      final snap = await users.where('email', isEqualTo: driverId).get();
      Map<String, dynamic>? driverProfile;
      
      if (snap.docs.isNotEmpty) {
        driverProfile = snap.docs.first.data();
      } else {
        final snap2 = await users.where('number', isEqualTo: driverId).get();
        if (snap2.docs.isNotEmpty) {
          driverProfile = snap2.docs.first.data();
        }
      }
      
      if (driverProfile != null) {
        _showShareableProfileDialog(driverProfile);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver profile not found'), backgroundColor: Colors.red),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver profile not found'), backgroundColor: Colors.red),
      );
    }
  }

  void _showReviewForm() async {
    // Fetch chat document to get driverId
    final chatData = await ChatService.getChatById(widget.chatId);
    if (chatData != null && chatData['driverId'] != null) {
      final driverId = chatData['driverId'];
      
      // Check if this is a completed trip
      final hasCompletedTrip = await ReviewService.hasCompletedTrip(
        widget.currentUserId,
        driverId,
      );
      
      if (!hasCompletedTrip) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can only review drivers after completing a trip'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Check if passenger has already reviewed this driver
      final hasReviewed = await ReviewService.hasPassengerReviewedDriver(
        widget.currentUserId,
        driverId,
      );
      
      if (hasReviewed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already reviewed this driver'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Show review form
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ReviewFormWidget(
          driverId: driverId,
          driverName: widget.otherUserName,
          passengerId: widget.currentUserId,
          passengerName: widget.currentUserName,
          routeId: chatData['routeId'],
          tripDate: DateTime.now().toIso8601String().split('T')[0], // Today's date
          isVerified: true, // Completed trips are verified
          onReviewSubmitted: () {
            // Optionally refresh the chat or show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thank you for your review!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit review'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showShareableProfileDialog(Map<String, dynamic> driverProfile) {
    final driverName = driverProfile['name'] ?? 'Driver';
    final driverNumber = driverProfile['number'] ?? '';
    final profileImageUrl = driverProfile['profileImageUrl'] ?? '';
    final carImageUrls = List<String>.from(driverProfile['carImageUrls'] ?? []);
    final driverId = driverProfile['email'] ?? driverProfile['number'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Image
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.3),
                    width: 4,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                  backgroundColor: Colors.grey[900],
                  child: profileImageUrl.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                ),
              ),
              
              // Driver Name with Verification Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    driverName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  if (driverProfile['isVerified'] == true)
                    const VerificationBadge(isVerified: true, size: 20),
                ],
              ),
              
              // Driver Rating (if available)
              FutureBuilder<double>(
                future: ReviewService.getDriverAverageRating(driverId),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data! > 0) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            snapshot.data!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              // Contact Number
              if (driverNumber.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '📞 $driverNumber',
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                ),
              ],
              
              // Driver Reviews Section
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Driver Reviews',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<Review>>(
                      stream: ReviewService.getDriverReviews(driverId),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text(
                            'Error loading reviews',
                            style: TextStyle(color: Colors.red),
                          );
                        }
                        
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final reviews = snapshot.data ?? [];
                        
                        if (reviews.isEmpty) {
                          return const Text(
                            'No reviews yet',
                            style: TextStyle(color: Colors.grey),
                          );
                        }
                        
                        // Calculate average rating
                        double averageRating = 0.0;
                        if (reviews.isNotEmpty) {
                          int totalRating = 0;
                          for (var review in reviews) {
                            totalRating += review.rating;
                          }
                          averageRating = totalRating / reviews.length;
                        }
                        
                        return Column(
                          children: [
                            // Average Rating
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  averageRating.toStringAsFixed(1),
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
                                  '(${reviews.length} reviews)',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            
                            // Recent Reviews (show up to 3)
                            ...reviews.take(3).map((review) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        review.passengerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: List.generate(5, (index) => Icon(
                                          index < review.rating ? Icons.star : Icons.star_border,
                                          color: Colors.amber,
                                          size: 16,
                                        )),
                                      ),
                                    ],
                                  ),
                                  if (review.comment.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      review.comment,
                                      style: const TextStyle(color: Colors.grey),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            )),
                            
                            // View All Reviews Button
                            if (reviews.length > 3) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => DriverReviewsView(
                                        driverId: driverId,
                                        driverName: driverName,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'View All Reviews',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              
              // Car Photos
              if (carImageUrls.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Car Photos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: carImageUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          carImageUrls[idx],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
              ],
              
              // Verification Status Section
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Verification Status',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // CNIC Verification
                        Column(
                          children: [
                            const Icon(Icons.credit_card, color: Colors.white, size: 24),
                            const SizedBox(height: 4),
                            const Text('CNIC', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            if (driverProfile['isVerified'] == true)
                              const VerificationBadge(isVerified: true, size: 16)
                            else
                              const VerificationBadge(isVerified: false, size: 16),
                          ],
                        ),
                        // License Verification
                        Column(
                          children: [
                            const Icon(Icons.badge, color: Colors.white, size: 24),
                            const SizedBox(height: 4),
                            const Text('License', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            if (driverProfile['isVerified'] == true)
                              const VerificationBadge(isVerified: true, size: 16)
                            else
                              const VerificationBadge(isVerified: false, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => DriverPublicProfileView(
                              driverId: driverId,
                              driverName: driverName,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'View Driver Profile',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.matteBlack,
      appBar: AppBar(
        title: Text(widget.otherUserName, style: const TextStyle(color: Colors.white)),
        backgroundColor: ColorUtils.matteBlack,
        foregroundColor: ColorUtils.softWhite,
        elevation: 0,
        actions: [
          if (widget.userRole == 'passenger') ...[
            IconButton(
              onPressed: _showDriverProfile,
              icon: const Icon(Icons.info_outline, color: Colors.white),
              tooltip: 'View Driver Profile',
            ),
            IconButton(
              onPressed: _showReviewForm,
              icon: const Icon(Icons.star, color: Colors.amber),
              tooltip: 'Review Driver',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ChatService.getMessagesStream(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error loading messages', style: TextStyle(color: Colors.white)),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final messages = snapshot.data?.docs ?? [];

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    return _buildMessageWidget(message, messages[index].id);
                  },
                );
              },
            ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ColorUtils.matteBlack,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                if (widget.userRole == 'passenger')
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      onPressed: _showOfferDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('OFFER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[900],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 