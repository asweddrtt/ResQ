import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../go_router/routes.dart';

class MessagesScreen extends StatefulWidget {
  bool? isShelter;
   MessagesScreen({
    this.isShelter,
    super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  // ==========================================
  // LOGIC: Fetch real inbox data
  // ==========================================
  Future<List<Map<String, dynamic>>> _fetchInbox() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // 1. Get all conversations the current user is part of
      final myParticipants = await Supabase.instance.client
          .from('conversation_participants')
          .select('conversation_id')
          .eq('user_id', userId);

      if (myParticipants.isEmpty) return [];

      List<Map<String, dynamic>> inboxList = [];

      for (var p in myParticipants) {
        final convoId = p['conversation_id'] as String;

        // 2. Get the OTHER participant in this conversation
        final otherParticipant = await Supabase.instance.client
            .from('conversation_participants')
            .select('user_id')
            .eq('conversation_id', convoId)
            .neq('user_id', userId)
            .maybeSingle();

        String chatName = "Unknown User";
        if (otherParticipant != null) {
          final otherUserId = otherParticipant['user_id'];

          final userData = await Supabase.instance.client
              .from('users')
              .select('full_name, role')
              .eq('id', otherUserId)
              .maybeSingle();

          if (userData != null) {
            // 🚨 ADDED: Check if the user is a shelter
            if (userData['role'] == 'shelter') {
              // Fetch name using the user_id foreign key in the shelters table
              final shelterData = await Supabase.instance.client
                  .from('shelters')
                  .select('name')
                  .eq('user_id', otherUserId)
                  .maybeSingle();

              if (shelterData != null && shelterData['name'] != null) {
                chatName = shelterData['name'].toString().trim();
              }
            } else if (userData['full_name'] != null) {
              // Normal user, use full_name
              chatName = userData['full_name'].toString().trim();
            }

            // Final fallback just in case the shelter name was also empty
            if (chatName.isEmpty) chatName = "Unknown User";
          }
        }

        // 3. Get the latest message for the preview
        final latestMsg = await Supabase.instance.client
            .from('messages')
            .select('body, created_at')
            .eq('conversation_id', convoId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        String lastMessageText = "Say hi!";
        String timeText = "";

        if (latestMsg != null) {
          lastMessageText = latestMsg['body'] ?? "Attachment";
          final rawDate = DateTime.parse(latestMsg['created_at']);
          timeText = "${rawDate.month}/${rawDate.day}"; // Simple date format
        }

        inboxList.add({
          "id": convoId,
          "name": chatName,
          "message": lastMessageText,
          "time": timeText,
        });
      }

      return inboxList;
    } catch (e) {
      debugPrint("Error fetching inbox: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: widget.isShelter! ?  IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => context.pop(),
        ): null,
        title: Text("Messages", style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchInbox(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xff5bb381)));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error loading messages.", style: GoogleFonts.nunito(color: Colors.red)));
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return Center(child: Text("No messages yet.", style: GoogleFonts.nunito(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              return InkWell(
                // 🚨 Passes the exact dynamic data into the Chat Room
                onTap: () => context.push(AppRoutes.chatRoom, extra: {
                  'name': chat['name'],
                  'id': chat['id'],
                }),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xff5bb381).withOpacity(0.2),
                        child: const Icon(Icons.person, color: Color(0xff5bb381)),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(chat['name'], style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800)),
                                Text(chat['time'], style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              chat['message'],
                              style: GoogleFonts.nunito(fontSize: 13, color: Colors.black87),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}