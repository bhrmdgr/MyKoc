// lib/pages/communication/messages/messages_view.dart
import 'package:easy_localization/easy_localization.dart'; // Eklendi
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mykoc/pages/communication/messages/messages_view_model.dart';
import 'package:mykoc/pages/communication/chat_room/chat_room_view.dart';

class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  late MessagesViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MessagesViewModel();
    _viewModel.initialize();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Consumer<MessagesViewModel>(
                builder: (context, viewModel, child) {
                  if (viewModel.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (viewModel.chatRooms.isEmpty) {
                    return _buildEmptyState();
                  }

                  // Grup sohbetlerini en üste getir
                  final sortedRooms = [...viewModel.chatRooms];
                  sortedRooms.sort((a, b) {
                    // Önce type'a göre sırala (class_group önce gelsin)
                    if (a.type == 'class_group' && b.type != 'class_group') {
                      return -1;
                    }
                    if (a.type != 'class_group' && b.type == 'class_group') {
                      return 1;
                    }
                    // Aynı type ise lastMessageTime'a göre sırala
                    if (a.lastMessageTime == null) return 1;
                    if (b.lastMessageTime == null) return -1;
                    return b.lastMessageTime!.compareTo(a.lastMessageTime!);
                  });

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: sortedRooms.length,
                    itemBuilder: (context, index) {
                      final chatRoom = sortedRooms[index];
                      return _buildConversationItem(chatRoom, viewModel);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Text(
            'messages'.tr(), // ✅ GÜNCELLENDİ
            style: const TextStyle(
              fontSize: 32,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'no_messages_yet'.tr(), // ✅ GÜNCELLENDİ
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'start_chatting_hint'.tr(), // ✅ GÜNCELLENDİ
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem(chatRoom, MessagesViewModel viewModel) {
    final isGroup = chatRoom.type == 'class_group';
    final displayName = viewModel.getOtherParticipantName(chatRoom);
    final imageUrl = viewModel.getOtherParticipantImage(chatRoom);
    final initials = viewModel.getOtherParticipantInitials(chatRoom);
    final unreadCount = chatRoom.getUnreadCountForUser(viewModel.currentUserId ?? '');
    final timeText = viewModel.getRelativeTime(chatRoom.lastMessageTime);
    final lastMessageText = chatRoom.lastMessage ?? 'no_messages_yet'.tr(); // ✅ GÜNCELLENDİ

    final isDirect = chatRoom.type == 'direct';
    final canDelete = isDirect;

    final chatCard = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatRoomView(
                chatRoomId: chatRoom.id,
                chatRoomName: displayName,
                isGroup: isGroup,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isGroup
                            ? [const Color(0xFF6366F1), const Color(0xFF8B5CF6)]
                            : [const Color(0xFF9CA3AF), const Color(0xFF6B7280)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: (imageUrl != null && imageUrl.isNotEmpty)
                        ? ClipOval(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                        : Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isGroup) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.people_outline_rounded,
                            size: 16,
                            color: Colors.grey[500],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessageText,
                      style: TextStyle(
                        fontSize: 14,
                        color: unreadCount > 0
                            ? const Color(0xFF6B7280)
                            : Colors.grey[500],
                        fontWeight: unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_back,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (canDelete) {
      return Dismissible(
        key: Key(chatRoom.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          return await _showDeleteChatDialog(chatRoom, viewModel);
        },
        background: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_outline, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                'delete'.tr(), // ✅ GÜNCELLENDİ
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        child: chatCard,
      );
    }

    return chatCard;
  }

  Future<bool> _showDeleteChatDialog(chatRoom, MessagesViewModel viewModel) async {
    final displayName = viewModel.getOtherParticipantName(chatRoom);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'delete_chat'.tr(), // ✅ JSON'daki 'delete_chat' anahtarıyla eşleştirildi
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'delete_chat_confirm'.tr(args: [displayName]), // ✅ GÜNCELLENDİ (Parametreli)
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'delete_chat_info'.tr(), // ✅ GÜNCELLENDİ
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'cancel'.tr(), // ✅ GÜNCELLENDİ
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(false);

              if (!mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => WillPopScope(
                  onWillPop: () async => false,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                    ),
                  ),
                ),
              );

              final success = await viewModel.deleteChatRoom(
                chatRoom.id,
                chatRoom.type,
              );

              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            success
                                ? 'chat_deleted_success'.tr(args: [displayName]) // ✅ GÜNCELLENDİ
                                : 'chat_deleted_failed'.tr(), // ✅ GÜNCELLENDİ
                          ),
                        ),
                      ],
                    ),
                    backgroundColor:
                    success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'delete'.tr(), // ✅ GÜNCELLENDİ
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}