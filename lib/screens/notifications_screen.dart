import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // The join automatically grabs title and body! No need for a second query.
      final data = await _supabase.from('notification_deliveries')
          .select('''
            id,
            read_at,
            notifications (
              title,
              body,
              created_at
            )
          ''')
          .eq('user_id', userId);

      // Sort safely
      final sortedData = List<Map<String, dynamic>>.from(data);
      sortedData.sort((a, b) {
        final dateAStr = a['notifications']?['created_at'];
        final dateBStr = b['notifications']?['created_at'];

        final dateA = dateAStr != null ? DateTime.parse(dateAStr) : DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = dateBStr != null ? DateTime.parse(dateBStr) : DateTime.fromMillisecondsSinceEpoch(0);

        return dateB.compareTo(dateA); // Newest first
      });

      if (mounted) {
        setState(() {
          _notifications = sortedData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String deliveryId, int index) async {
    if (_notifications[index]['read_at'] != null) return; // Already read

    setState(() => _notifications[index]['read_at'] = DateTime.now().toIso8601String());

    try {
      await _supabase
          .from('notification_deliveries')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', deliveryId);
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff5bb381).withOpacity(0.2), // Using the green from your reference
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications, color: Color(0xff5bb381), size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Notifications", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
            Text("Stay updated", style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.black, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
        ],
      ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xff5bb381)))
            : _notifications.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_off_outlined, size: 50, color: Colors.grey[300]),
              const SizedBox(height: 10),
              Text(
                "No notifications yet!",
                style: GoogleFonts.nunito(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final delivery = _notifications[index];
            final notif = delivery['notifications'] ?? {};
            final isRead = delivery['read_at'] != null;

            return GestureDetector(
              onTap: () => _markAsRead(delivery['id'], index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20), // Matched to reference radius
                  border: Border.all(
                    color: isRead ? Colors.grey[200]! : const Color(0xff5bb381).withOpacity(0.5),
                    width: isRead ? 1 : 1.5,
                  ),
                  boxShadow: [
                    if (!isRead)
                      BoxShadow(
                        color: const Color(0xff5bb381).withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Clean unread indicator dot
                    Container(
                      margin: const EdgeInsets.only(top: 6, right: 12),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRead ? Colors.transparent : const Color(0xff5bb381),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notif['title'] ?? 'Alert',
                            style: GoogleFonts.nunito(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 16,
                              color: isRead ? Colors.black87 : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notif['body'] ?? '',
                            style: GoogleFonts.nunito(
                              color: Colors.grey[600],
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
    );
  }
}