import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatScreen extends StatefulWidget {
  final String chatName;
  final String conversationId; // 🚨 ADDED: To fetch the right messages

  const ChatScreen({
    super.key,
    required this.chatName,
    required this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  // 🚨 Dummy data for the UI - we will replace this with a Supabase Stream next!
  final List<Map<String, dynamic>> _dummyMessages = [
    {"isMe": false, "text": "I'm at the location, where exactly did you see the cat?"},
    {"isMe": true, "text": "Right behind the old gas station, near the dumpsters!"},
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // 🚨 CHANGED: Real Supabase Insert Logic
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear(); // Clear UI immediately for good UX

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_user_id': userId,
        'body': text,
        // created_at is handled automatically by your database default
      });
    } catch (e) {
      debugPrint("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send message"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xff5bb381).withOpacity(0.2),
              child: const Icon(Icons.person, color: Color(0xff5bb381), size: 20),
            ),
            const SizedBox(width: 10),
            Text(widget.chatName, style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ==========================================
          // 1. MESSAGE LIST (Live Stream)
          // ==========================================
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('conversation_id', widget.conversationId)
                  .order('created_at', ascending: false) // Fetch newest first
                  .map((maps) => maps),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xff5bb381)));
                }

                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading messages."));
                }

                final messages = snapshot.data ?? [];
                final currentUserId = Supabase.instance.client.auth.currentUser?.id;

                if (messages.isEmpty) {
                  return Center(child: Text("Say hi!", style: GoogleFonts.nunito(color: Colors.grey)));
                }

                return ListView.builder(
                  reverse: true, // 🚨 Pushes messages to the bottom
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_user_id'] == currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xff5bb381) : Colors.grey.shade100,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isMe ? 20 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 20),
                          ),
                        ),
                        child: Text(
                          msg['body'] ?? '',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isMe ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ==========================================
          // 2. BOTTOM INPUT AREA
          // ==========================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10).copyWith(bottom: MediaQuery.of(context).padding.bottom + 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.nunito(),
                      decoration: InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: GoogleFonts.nunito(color: Colors.grey),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Color(0xffffa94d), shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
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