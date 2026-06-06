import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class SupportChatScreen extends StatefulWidget {
  final String? subject;
  const SupportChatScreen({super.key, this.subject});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  static const String _supabaseUrl = 'https://dgwrsfjpxuvgqrbhhjro.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRnd3JzZmpweHV2Z3FyYmhoanJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzNDUzMTYsImV4cCI6MjA4NjkyMTMxNn0.g9IBC8ZjBOYWpa4-k6FWA6qiEV0CvZcqd5AG8JZLyPE';

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ImagePicker _picker = ImagePicker();

  // Ticket is NOT created on open — only on first message send
  bool _isSending = false;
  bool _isUploading = false;
  bool _isCreatingThread = false;
  String? _conversationId;
  String? _ticketId;
  bool _ratingShown = false;

  final Color _green  = const Color(0xff5bb381);
  final Color _orange = const Color(0xffffa94d);

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Called only when user sends first message
  Future<bool> _ensureThread() async {
    if (_conversationId != null) return true; // already created
    setState(() => _isCreatingThread = true);
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Not logged in');
      final subject = widget.subject?.isNotEmpty == true ? widget.subject! : 'New support request';
      final uri = Uri.parse('$_supabaseUrl/functions/v1/support-open-thread');
      final resp = await http.post(uri,
        headers: {'Authorization': 'Bearer ${session.accessToken}', 'Content-Type': 'application/json'},
        body: jsonEncode({'subject': subject}),
      );
      if (resp.statusCode != 200) throw Exception('Server error ${resp.statusCode}');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      _conversationId = data['conversation_id'] as String?;
      _ticketId       = data['ticket_id'] as String?;
      if (_conversationId == null) throw Exception('No conversation ID');
      if (mounted) setState(() {});
      return true;
    } catch (e) {
      _snack('Could not connect to support. Try again.', Colors.red);
      return false;
    } finally {
      if (mounted) setState(() => _isCreatingThread = false);
    }
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    final body = text?.trim() ?? '';
    if (body.isEmpty && imageUrl == null) return;
    if (_isSending) return;

    // Create thread on first message
    final ok = await _ensureThread();
    if (!ok) return;

    setState(() => _isSending = true);
    _msgCtrl.clear();

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': _conversationId,
        'sender_user_id': userId,
        'body': imageUrl != null ? '📷 [Image] $imageUrl' : body,
      });
      _scrollToBottom();
    } catch (e) {
      _snack('Failed to send. Try again.', Colors.red);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    final ok = await _ensureThread();
    if (!ok) return;

    setState(() => _isUploading = true);
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Not logged in');
      final ext   = file.path.split('.').last.toLowerCase();
      final ct    = ext == 'png' ? 'image/png' : 'image/jpeg';
      final path  = 'support/$_conversationId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await File(file.path).readAsBytes();

      try {
        await Supabase.instance.client.storage.from('support_attachments')
            .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: ct, upsert: false));
      } catch (_) {
        await http.post(
          Uri.parse('$_supabaseUrl/storage/v1/object/support_attachments/${Uri.encodeComponent(path)}'),
          headers: {'Authorization': 'Bearer ${session.accessToken}', 'apikey': _anonKey, 'Content-Type': ct},
          body: bytes,
        );
      }
      final url = Supabase.instance.client.storage.from('support_attachments').getPublicUrl(path);
      await _sendMessage(imageUrl: url);
    } catch (e) {
      _snack('Failed to upload image.', Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: GoogleFonts.nunito()), backgroundColor: color, duration: const Duration(seconds: 2)));
  }

  void _showRatingDialog() {
    if (_ratingShown || _ticketId == null) return;
    _ratingShown = true;
    int selectedRating = 0;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(children: [
            Icon(Icons.star_rounded, color: _orange, size: 40),
            const SizedBox(height: 8),
            Text('Rate your experience', style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 17)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('How was our support?', style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setDialog(() => selectedRating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: _orange, size: 38,
                  ),
                ),
              )),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: commentCtrl,
                maxLines: 2,
                style: GoogleFonts.nunito(fontSize: 13),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Leave a comment (optional)',
                  hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400, fontSize: 13),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Skip', style: GoogleFonts.nunito(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedRating > 0 ? _green : Colors.grey.shade300,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: selectedRating == 0 ? null : () async {
                try {
                  await Supabase.instance.client.from('ticket_ratings').insert({
                    'ticket_id': _ticketId,
                    'user_id': Supabase.instance.client.auth.currentUser?.id,
                    'rating': selectedRating,
                    'comment': commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _snack('Thank you for your feedback! 🙏', _green);
                } catch (e) {
                  _snack('Error submitting rating.', Colors.red);
                }
              },
              child: Text('Submit', style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _green.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(Icons.support_agent, color: _green, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Support', style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 16)),
            Text('ResQ Help Team', style: GoogleFonts.nunito(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
      body: Column(children: [

        // Status banner — only show if thread exists
        if (_conversationId != null && _ticketId != null)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: Supabase.instance.client.from('support_tickets')
                .stream(primaryKey: ['id']).eq('id', _ticketId!),
            builder: (context, snap) {
              final status = snap.data?.isNotEmpty == true ? snap.data!.first['status'] as String? : null;

              if (status == 'resolved' && !_ratingShown) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _showRatingDialog());
              }

              Color bannerColor;
              IconData bannerIcon;
              String bannerText;

              if (status == 'resolved') {
                bannerColor = _green;
                bannerIcon  = Icons.check_circle_outline;
                bannerText  = 'Ticket resolved! Tap to rate your experience.';
              } else if (status == 'closed') {
                bannerColor = Colors.grey;
                bannerIcon  = Icons.lock_outline;
                bannerText  = 'This ticket has been closed.';
              } else {
                bannerColor = _green;
                bannerIcon  = Icons.check_circle_outline;
                bannerText  = 'Connected! Our team will reply soon.';
              }

              return GestureDetector(
                onTap: status == 'resolved' ? _showRatingDialog : null,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bannerColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: bannerColor.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    Icon(bannerIcon, color: bannerColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(bannerText,
                        style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87))),
                  ]),
                ),
              );
            },
          ),

        // Messages area
        Expanded(child: _conversationId == null
            ? _buildWelcome()
            : _buildMessages()),

        // Input bar
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _green.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.support_agent, color: _green, size: 48),
          ),
          const SizedBox(height: 20),
          Text('Hello! 👋', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 8),
          Text('How can we help you today?\nType your message below to start.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('Average response time: under 1 hour',
                  style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildMessages() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', _conversationId!)
          .order('created_at', ascending: true),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(child: Text('Say hi! We\'re here to help.',
              style: GoogleFonts.nunito(color: Colors.grey.shade400)));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (ctx, i) {
            final msg   = messages[i];
            final isMe  = msg['sender_user_id'] == currentUserId;
            final body  = msg['body'] as String? ?? '';
            final time  = _formatTime(msg['created_at']);
            final isImg = body.startsWith('📷 [Image] ');
            final imgUrl = isImg ? body.replaceFirst('📷 [Image] ', '') : null;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Row(children: [
                        CircleAvatar(radius: 10, backgroundColor: _orange.withOpacity(0.2),
                            child: Icon(Icons.support_agent, size: 12, color: _orange)),
                        const SizedBox(width: 6),
                        Text('Support Team', style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                      ]),
                    ),
                  Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width * 0.72),
                          decoration: BoxDecoration(
                            color: isMe ? _green : Colors.grey.shade100,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 18),
                            ),
                          ),
                          child: isImg
                              ? ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 18),
                            ),
                            child: Image.network(imgUrl!, width: 200, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Padding(padding: const EdgeInsets.all(12),
                                    child: Text('Image unavailable', style: GoogleFonts.nunito(color: isMe ? Colors.white : Colors.black87)))),
                          )
                              : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Text(body, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: isMe ? Colors.white : Colors.black87)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(time, style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
      child: Row(children: [
        // Image button
        GestureDetector(
          onTap: _isUploading ? null : _pickAndSendImage,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: _isUploading
                ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                : Icon(Icons.image_outlined, color: Colors.grey.shade500, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        // Text field
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(28)),
            child: TextField(
              controller: _msgCtrl,
              style: GoogleFonts.nunito(fontSize: 14),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(text: _msgCtrl.text),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send button
        GestureDetector(
          onTap: (_isSending || _isCreatingThread) ? null : () => _sendMessage(text: _msgCtrl.text),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (_isSending || _isCreatingThread) ? Colors.grey.shade300 : _orange,
              shape: BoxShape.circle,
            ),
            child: (_isSending || _isCreatingThread)
                ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt   = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}