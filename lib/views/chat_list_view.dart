import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/chat_service.dart';
import 'chat_view.dart';
import '../utils/color_utils.dart';

class ChatListTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String chatId;
  final String userRole;
  final String userId;
  final String userName;
  final VoidCallback onTap;

  const ChatListTile({
    Key? key,
    required this.chat,
    required this.chatId,
    required this.userRole,
    required this.userId,
    required this.userName,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final passengerName = chat['passengerName'] as String? ?? '';
    final driverName = chat['driverName'] as String? ?? '';
    final lastMessage = chat['lastMessage'] as String? ?? '';
    final lastMessageAt = chat['lastMessageAt'] as Timestamp?;
    final unreadCount = chat['unreadCount'] as int? ?? 0;
    final matchPercentage = chat['matchPercentage'] as double? ?? 0.0;
    final status = chat['status'] as String? ?? 'active';
    String otherPersonName = userRole == 'passenger' ? driverName : passengerName;
    // Format time
    String timeString = '';
    if (lastMessageAt != null) {
      final now = DateTime.now();
      final messageTime = lastMessageAt.toDate();
      final difference = now.difference(messageTime);
      if (difference.inDays > 0) {
        timeString = '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        timeString = '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        timeString = '${difference.inMinutes}m ago';
      } else {
        timeString = 'Just now';
      }
    }
    return Card(
      color: ColorUtils.matteBlack,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey[900],
          child: Text(
            otherPersonName.isNotEmpty ? otherPersonName[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                otherPersonName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lastMessage.isNotEmpty) ...[
              Text(
                lastMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unreadCount > 0 ? Colors.white : Colors.grey[400],
                  fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                if (userRole == 'passenger') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getMatchColor(matchPercentage),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${matchPercentage.toStringAsFixed(1)}% match',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  timeString,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        trailing: unreadCount > 0
            ? Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getMatchColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    if (percentage >= 40) return Colors.yellow.shade700;
    return Colors.red;
  }
}

// Main ChatListView remains, but uses ChatListTile
class ChatListView extends StatefulWidget {
  final String userId;
  final String userName;
  final String userRole; // 'passenger' or 'driver'
  const ChatListView({
    super.key,
    required this.userId,
    required this.userName,
    required this.userRole,
  });
  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.matteBlack,
      appBar: AppBar(
        title: Text(
          widget.userRole == 'passenger' ? 'Driver Chats' : 'Passenger Chats',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: ColorUtils.matteBlack,
        foregroundColor: ColorUtils.softWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: ChatService.getUserChats(widget.userId, widget.userRole),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Error loading chats', style: TextStyle(color: Colors.white)),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data?.docs ?? [];
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('No chats yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    widget.userRole == 'passenger'
                        ? 'Start chatting with drivers when you find matching routes!'
                        : 'Passengers will start chats when they find your routes!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data() as Map<String, dynamic>;
              final chatId = chats[index].id;
              return ChatListTile(
                chat: chat,
                chatId: chatId,
                userRole: widget.userRole,
                userId: widget.userId,
                userName: widget.userName,
                onTap: () {
                  String otherPersonName = widget.userRole == 'passenger' ? (chat['driverName'] ?? '') : (chat['passengerName'] ?? '');
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatView(
                        chatId: chatId,
                        currentUserId: widget.userId,
                        currentUserName: widget.userName,
                        otherUserName: otherPersonName,
                        userRole: widget.userRole,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
} 