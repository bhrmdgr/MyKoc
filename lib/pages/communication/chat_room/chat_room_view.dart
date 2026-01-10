  import 'package:easy_localization/easy_localization.dart';
  import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:mykoc/pages/communication/chat_room/chat_room_view_model.dart';
  import 'package:mykoc/pages/profile/student_profile_page.dart';
  import 'package:mykoc/pages/profile/mentor_profile_page.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:file_picker/file_picker.dart';
  import 'package:dio/dio.dart';
  import 'package:path_provider/path_provider.dart';
  import 'package:open_filex/open_filex.dart';
  import 'dart:io';

  class ChatRoomView extends StatefulWidget {
    final String chatRoomId;
    final String chatRoomName;
    final bool isGroup;
    final String? otherUserName;
    final String? otherUserImageUrl;

    const ChatRoomView({
      super.key,
      required this.chatRoomId,
      required this.chatRoomName,
      this.isGroup = false,
      this.otherUserName,
      this.otherUserImageUrl,
    });

    @override
    State<ChatRoomView> createState() => _ChatRoomViewState();
  }

  class _ChatRoomViewState extends State<ChatRoomView> {
    late ChatRoomViewModel _viewModel;
    final TextEditingController _messageController = TextEditingController();
    final ScrollController _scrollController = ScrollController();
    final FocusNode _focusNode = FocusNode();

    @override
    void initState() {
      super.initState();
      _viewModel = ChatRoomViewModel();
      _viewModel.initialize(
        widget.chatRoomId,
        otherUserName: widget.otherUserName,
        otherUserImageUrl: widget.otherUserImageUrl,
      );
    }

    @override
    void dispose() {
      _messageController.dispose();
      _scrollController.dispose();
      _focusNode.dispose();
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
                child: Consumer<ChatRoomViewModel>(
                  builder: (context, viewModel, child) {
                    if (viewModel.messages.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      itemCount: viewModel.messages.length,
                      itemBuilder: (context, index) {
                        final message = viewModel.messages[index];
                        final showDate = viewModel.shouldShowDateHeader(index);

                        return Column(
                          children: [
                            if (showDate) _buildDateHeader(message.timestamp),
                            _buildMessageBubble(message, viewModel),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              _buildMessageInput(),
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
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: widget.isGroup ? null : () => _openOtherUserProfile(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.chatRoomName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!widget.isGroup) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ],
                          ],
                        ),
                        if (widget.isGroup)
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                size: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'group_chat'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: widget.isGroup
                      ? () => _showGroupInfo()
                      : () => _openOtherUserProfile(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Future<void> _openOtherUserProfile() async {
      final chatRoomData = _viewModel.chatRoomData;
      if (chatRoomData == null) return;

      final participantIds = List<String>.from(chatRoomData['participantIds'] ?? []);
      final currentUserId = _viewModel.currentUserId;

      String? otherUserId;
      for (var id in participantIds) {
        if (id != currentUserId) {
          otherUserId = id;
          break;
        }
      }

      if (otherUserId == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );

      // DOĞRUDAN FIRESTORE'DAN ROLE BİLGİSİNİ ÇEK
      String otherUserRole = 'student'; // Default
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();

        if (userDoc.exists) {
          otherUserRole = userDoc.data()?['role'] ?? 'student';
          debugPrint('✅ User role from Firestore: $otherUserRole for user: $otherUserId');
        }
      } catch (e) {
        debugPrint('❌ Error fetching user role: $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) return;
      Navigator.pop(context);

      if (otherUserRole == 'mentor') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MentorProfilePage(mentorId: otherUserId!),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentProfilePage(studentId: otherUserId!),
          ),
        );
      }
    }

    Future<void> _showGroupInfo() async {
      final chatRoomData = _viewModel.chatRoomData;
      if (chatRoomData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('loading_group_info'.tr()),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }

      final classId = chatRoomData['classId'] as String?;
      if (classId == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
          ),
        ),
      );

      try {
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .get();

        if (!mounted) return;
        Navigator.pop(context);

        if (!classDoc.exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('class_not_found'.tr()),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
          return;
        }

        final classData = classDoc.data()!;
        final className = classData['className'] ?? 'Class';
        final classType = classData['classType'] ?? 'Unknown';
        final mentorName = classData['mentorName'] ?? 'Unknown';
        final mentorId = classData['mentorId'] as String?;
        final studentCount = classData['studentCount'] ?? 0;

        final participantDetails = Map<String, dynamic>.from(
            chatRoomData['participantDetails'] ?? {}
        );
        final participants = participantDetails.entries.toList();

        _showGroupInfoDialog(
          className: className,
          classType: classType,
          mentorName: mentorName,
          mentorId: mentorId,
          studentCount: studentCount,
          participants: participants,
        );
      } catch (e) {
        debugPrint('❌ Error loading class info: $e');
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('failed_load_group_info'.tr()),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    }

    void _showGroupInfoDialog({
      required String className,
      required String classType,
      required String mentorName,
      required String? mentorId,
      required int studentCount,
      required List<MapEntry<String, dynamic>> participants,
    }) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              className,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            classType,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.people_outline,
                            size: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'members_count'.tr(args: [studentCount.toString()]),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'mentor_label'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: mentorId != null
                              ? () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MentorProfilePage(mentorId: mentorId),
                              ),
                            );
                          }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF6366F1),
                                  child: Text(
                                    mentorName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    mentorName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final entry = participants[index];
                      final userId = entry.key;
                      final userDetails = entry.value as Map<String, dynamic>;
                      final userName = userDetails['name'] ?? 'Unknown';
                      final userRole = userDetails['role'] ?? 'student';
                      final userImageUrl = userDetails['imageUrl'] as String?;

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          if (userRole == 'mentor') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    MentorProfilePage(mentorId: userId),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    StudentProfilePage(studentId: userId),
                              ),
                            );
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              if (userImageUrl != null && userImageUrl.isNotEmpty)
                                CircleAvatar(
                                  radius: 20,
                                  backgroundImage: NetworkImage(userImageUrl),
                                )
                              else
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: userRole == 'mentor'
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF10B981),
                                  child: Text(
                                    userName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (userRole == 'mentor')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child:  Text(
                                    'mentor_label'.tr(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                size: 20,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
              'no_messages_yet'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'start_conversation'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildDateHeader(DateTime date) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _viewModel.getDateHeader(date),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      );
    }

    Widget _buildMessageBubble(message, ChatRoomViewModel viewModel) {
      final isMe = viewModel.isMyMessage(message);
      final hasFile = message.fileUrl != null && message.fileUrl!.isNotEmpty;
      final messageText = message.text ?? '';

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe && widget.isGroup) ...[
                GestureDetector(
                  onTap: () async {
                    final userRole = await _getUserRole(message.senderId);

                    if (userRole == 'mentor') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MentorProfilePage(
                            mentorId: message.senderId,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentProfilePage(
                            studentId: message.senderId,
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.senderImageUrl != null &&
                            message.senderImageUrl!.isNotEmpty)
                          CircleAvatar(
                            radius: 10,
                            backgroundImage:
                            NetworkImage(message.senderImageUrl!),
                            backgroundColor: const Color(0xFF6366F1),
                          )
                        else
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: const Color(0xFF6366F1),
                            child: Text(
                              (message.senderName ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          message.senderName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: const Color(0xFF6366F1).withOpacity(0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  )
                      : null,
                  color: isMe ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasFile) ...[
                      _buildFilePreview(message, isMe),
                      if (messageText.isNotEmpty) const SizedBox(height: 8),
                    ],
                    if (messageText.isNotEmpty)
                      Text(
                        messageText,
                        style: TextStyle(
                          fontSize: 15,
                          color: isMe ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          viewModel.getMessageTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe
                                ? Colors.white.withOpacity(0.7)
                                : Colors.grey[500],
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.readBy != null && message.readBy.length > 1
                                ? Icons.done_all
                                : Icons.done,
                            size: 14,
                            color: message.readBy != null && message.readBy.length > 1
                                ? Colors.blue[200]
                                : Colors.white.withOpacity(0.7),
                          ),
                        ],
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

    Widget _buildFilePreview(message, bool isMe) {
      final extension = message.fileType?.toLowerCase() ?? '';
      final isImage = extension == 'image' ||
          message.fileUrl?.toLowerCase().contains('.jpg') == true ||
          message.fileUrl?.toLowerCase().contains('.jpeg') == true ||
          message.fileUrl?.toLowerCase().contains('.png') == true;

      if (isImage) {
        return GestureDetector(
          onTap: () => _showFullScreenImage(message.fileUrl!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              message.fileUrl!,
              width: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 200,
                  height: 150,
                  color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, size: 48),
                );
              },
            ),
          ),
        );
      }

      return GestureDetector(
        onTap: () => _downloadFile(message.fileUrl!, message.fileName),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(message.fileType),
                color: isMe ? Colors.white : const Color(0xFF6366F1),
                size: 32,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.fileName ?? 'document'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isMe ? Colors.white : const Color(0xFF1F2937),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.fileType?.toUpperCase() ?? 'file'.tr().toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? Colors.white.withOpacity(0.7)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.download,
                color: isMe ? Colors.white : const Color(0xFF6366F1),
                size: 20,
              ),
            ],
          ),
        ),
      );
    }

    IconData _getFileIcon(String? fileType) {
      switch (fileType) {
        case 'document':
          return Icons.description;
        case 'video':
          return Icons.video_file;
        case 'image':
          return Icons.image;
        default:
          return Icons.insert_drive_file;
      }
    }

    Widget _buildMessageInput() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: Color(0xFF6366F1)),
                onPressed: () => _showAttachmentOptions(),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: 'type_message_hint'.tr(),
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 15,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Consumer<ChatRoomViewModel>(
                builder: (context, viewModel, child) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: viewModel.isSending
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: viewModel.isSending ? null : () => _sendMessage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    void _showAttachmentOptions() {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo, color: Color(0xFF6366F1)),
                title: Text('photo'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF6366F1)),
                title: Text('camera'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.description, color: Color(0xFF6366F1)),
                title: Text('document'.tr()),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
            ],
          ),
        ),
      );
    }

    Future<void> _pickImage() async {
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (image != null) {
          await _sendFileMessage(File(image.path));
        }
      } catch (e) {
        debugPrint('❌ Error picking image: $e');
        _showErrorSnackBar('failed_load_image'.tr());
      }
    }

    Future<void> _takePhoto() async {
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );

        if (image != null) {
          await _sendFileMessage(File(image.path));
        }
      } catch (e) {
        debugPrint('❌ Error taking photo: $e');
        _showErrorSnackBar('failed_load_image'.tr());
      }
    }

    Future<void> _pickDocument() async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
        );

        if (result != null && result.files.single.path != null) {
          await _sendFileMessage(File(result.files.single.path!));
        }
      } catch (e) {
        debugPrint('❌ Error picking document: $e');
        _showErrorSnackBar('failed_send_file'.tr());
      }
    }

    Future<void> _sendMessage() async {
      final text = _messageController.text.trim();
      if (text.isEmpty) return;

      _messageController.clear();
      _focusNode.unfocus();

      final success = await _viewModel.sendMessage(
        messageText: text,
      );

      if (!success && mounted) {
        _showErrorSnackBar('failed_send_message'.tr());
      }
    }

    Future<void> _sendFileMessage(File file) async {
      final success = await _viewModel.sendMessage(
        messageText: '',
        file: file,
      );

      if (!success && mounted) {
        _showErrorSnackBar('failed_send_file'.tr());
      }
    }

    void _showFullScreenImage(String imageUrl) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () => _downloadImage(imageUrl),
                ),
              ],
            ),
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'failed_load_image'.tr(),
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> _downloadImage(String imageUrl) async {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'MyKoc_Image_$timestamp.jpg';

        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        final filePath = '${directory!.path}/$fileName';

        final dio = Dio();
        await dio.download(imageUrl, filePath);

        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'image_saved'.tr(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'download_folder'.tr(),
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error downloading image: $e');

        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        _showErrorSnackBar('failed_download_image'.tr(args: [e.toString()]));
      }
    }

    Future<void> _downloadFile(String fileUrl, String? fileName) async {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
            ),
          ),
        );

        final decodedFileName = fileName ??
            Uri.decodeComponent(fileUrl.split('/').last.split('?').first);

        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        final filePath = '${directory!.path}/$decodedFileName';

        final dio = Dio();
        await dio.download(
          fileUrl,
          filePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              debugPrint(
                  'Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
            }
          },
        );

        if (mounted) Navigator.pop(context);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'file_downloaded'.tr(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'download_folder'.tr(),
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'open'.tr(),
                textColor: Colors.white,
                onPressed: () async {
                  final result = await OpenFilex.open(filePath);
                  if (result.type != ResultType.done) {
                    _showErrorSnackBar('cannot_open_file'.tr());
                  }
                },
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error downloading file: $e');

        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        _showErrorSnackBar('${'failed_download_file'.tr()}: ${e.toString()}');
      }
    }

    Future<String> _getUserRole(String userId) async {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          return userDoc.data()?['role'] ?? 'student';
        }
        return 'student';
      } catch (e) {
        debugPrint('❌ Error getting user role: $e');
        return 'student';
      }
    }

    void _showErrorSnackBar(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }