import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShelterRequestsScreen extends StatefulWidget {
  const ShelterRequestsScreen({super.key});

  @override
  State<ShelterRequestsScreen> createState() => _ShelterRequestsScreenState();
}

class _ShelterRequestsScreenState extends State<ShelterRequestsScreen> {
  final Color _bgGrey = const Color(0xffF8F9FA);
  final Color _textDark = Colors.black87;
  final Color _textLight = Colors.grey.shade500;
  final Color _primaryGreen = const Color(0xff5bb381);

  int _selectedTabIndex = 0; // 0: Pending, 1: Approved, 2: Rejected, 3: Interview

  String? _myShelterId;
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  // ==========================================
  // 🚨 THE RELATIONAL DATABASE QUERY
  // ==========================================
  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Get My Shelter ID
      if (_myShelterId == null) {
        final shelterData = await supabase.from('shelters').select('id').eq('user_id', user.id).maybeSingle();
        if (shelterData != null) _myShelterId = shelterData['id'];
      }

      if (_myShelterId == null) {
        setState(() => _isLoading = false);
        return; // User has no shelter profile
      }

      // 2. Fetch Requests + Animal Data + User Data in ONE query
      final data = await supabase
          .from('adoption_requests')
          .select('''
            id, status, created_at, decision_reason, applicant_user_id,
            animal:animals!inner ( name, age, breed, shelter_id ),
            applicant:users!adoption_requests_applicant_user_id_fkey ( full_name, phone )
          ''')
          .eq('animals.shelter_id', _myShelterId!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching requests: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // UPDATE STATUS LOGIC
  // ==========================================
  // ==========================================
  // UPDATE STATUS & CREATE CHAT LOGIC
  // ==========================================
  Future<void> _updateStatus(String requestId, String newStatus, {String? applicantUserId}) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      // 1. Update the adoption request status
      await Supabase.instance.client
          .from('adoption_requests')
          .update({
        'status': newStatus,
        'decided_by': currentUserId,
        'decided_at': DateTime.now().toUtc().toIso8601String(),
      })
          .eq('id', requestId);

      // 2. If Approved, Create the Chat automatically
      if (newStatus == 'approved' && applicantUserId != null && currentUserId != null) {
        final convoResponse = await Supabase.instance.client
            .from('conversations')
            .insert({})
            .select('id')
            .single();

        final String conversationId = convoResponse['id'];

        // Add both participants
        await Supabase.instance.client.from('conversation_participants').insert([
          {'conversation_id': conversationId, 'user_id': currentUserId},
          {'conversation_id': conversationId, 'user_id': applicantUserId},
        ]);

        // Drop the automated welcome message
        await Supabase.instance.client.from('messages').insert({
          'conversation_id': conversationId,
          'sender_user_id': currentUserId,
          'body': 'Hello! We have approved your adoption request. Let\'s discuss the next steps here.',
        });
      }

      // Refresh the list to show the change
      _fetchRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request updated to $newStatus'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating: $e'), backgroundColor: Colors.red));
    }
  }

  // Helper to format the time
  String _getTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return "Unknown time";
    Duration diff = DateTime.now().difference(DateTime.parse(dateTimeStr).toLocal());
    if (diff.inDays > 1) return "${diff.inDays} days ago";
    if (diff.inDays == 1) return "Yesterday";
    if (diff.inHours > 0) return "${diff.inHours} hrs ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes} min ago";
    return "Just now";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      body: SafeArea(
        // 🚨 Pull-to-refresh wrapped around the main body!
        child: RefreshIndicator(
          onRefresh: _fetchRequests,
          color: _primaryGreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 1. HEADER
              // ==========================================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Adoption Requests", style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: _textDark)),
                          const SizedBox(height: 2),
                          Text("Review and manage incoming requests", style: GoogleFonts.nunito(fontSize: 12, color: _textLight, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), shape: BoxShape.circle), child: const Icon(Icons.search, color: Colors.black87, size: 20)),
                        const SizedBox(width: 10),
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), shape: BoxShape.circle), child: const Icon(Icons.tune, color: Colors.black87, size: 20)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ==========================================
              // 3. DYNAMIC REQUEST CARDS LIST
              // ==========================================
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildRequestsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestsList() {
    final filteredRequests = _requests.where((req) {
      final status = req['status'] ?? 'pending';
      if (_selectedTabIndex == 0) return status == 'pending';
      if (_selectedTabIndex == 1) return status == 'approved';
      if (_selectedTabIndex == 2) return status == 'rejected';
      if (_selectedTabIndex == 3) return status == 'interview_scheduled' || status == 'interview';
      return false;
    }).toList();

    if (filteredRequests.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, color: Colors.grey.shade300, size: 40),
                const SizedBox(height: 12),
                Text("No requests found", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark)),
                const SizedBox(height: 4),
                Text("Pull down to refresh and check for new adoption applications.", textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final req = filteredRequests[index];
        final animal = req['animal'] ?? {};
        final applicant = req['applicant'] ?? {};

        final String reqId = req['id'] ?? '';
        final String shortId = "RQ-${reqId.length > 4 ? reqId.substring(0, 4).toUpperCase() : reqId}";
        final String status = req['status'] ?? 'pending';
        final String timeAgo = _getTimeAgo(req['created_at']);

        // Safe extraction
        final String applicantName = applicant['full_name'] ?? 'Unknown User';
        final String applicantPhone = applicant['phone'] ?? 'No phone provided';
        final String petName = animal['name'] ?? 'Unknown Pet';
        final String petAge = animal['age'] ?? '';
        final String petBreed = animal['breed'] ?? '';

        // Dynamic Styling Based on Status
        Color badgeBgColor = const Color(0xfffef08a);
        Color badgeTextColor = const Color(0xffb45309);
        String badgeText = "Pending";
        String primaryBtnText = "Approve";
        IconData primaryBtnIcon = Icons.check;
        bool showReject = true;
        final String applicantUserId = req['applicant_user_id'] ?? '';

        if (status == 'approved') {
          badgeBgColor = const Color(0xffdcfce7); badgeTextColor = const Color(0xff15803d); badgeText = "Approved";
          primaryBtnText = "View Details"; primaryBtnIcon = Icons.description_outlined; showReject = false;
        } else if (status == 'rejected') {
          badgeBgColor = const Color(0xfffee2e2); badgeTextColor = const Color(0xffb91c1c); badgeText = "Rejected";
          primaryBtnText = "View Details"; primaryBtnIcon = Icons.description_outlined; showReject = false;
        } else if (status == 'interview' || status == 'interview_scheduled') {
          badgeBgColor = const Color(0xffdbeafe); badgeTextColor = const Color(0xff1d4ed8); badgeText = "Interview scheduled";
          primaryBtnText = "Final Approve"; primaryBtnIcon = Icons.check_circle_outline; showReject = true;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: _buildRequestCard(
            rawId: reqId,
            name: applicantName,
            badgeText: badgeText,
            badgeBgColor: badgeBgColor,
            badgeTextColor: badgeTextColor,
            applicantId: applicantUserId,
            petInfo: "Request for: $petName • $petAge • $petBreed",
            submittedTime: "Submitted: $timeAgo",
            requestId: "ID: $shortId",
            phone: applicantPhone,
            description: "Adoption request application received via ResQ platform.", // You can add an actual description column later!
            primaryButtonText: primaryBtnText,
            primaryButtonIcon: primaryBtnIcon,
            showRejectButton: showReject,
          ),
        );
      },
    );
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  Widget _buildTab(String text, int index) {
    bool isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _primaryGreen : Colors.grey.shade300),
        ),
        child: Text(
          text,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard({
    required String rawId,
    required String name,
    required String applicantId, // 🚨 Add this here
    required String badgeText,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required String petInfo,
    required String submittedTime,
    required String requestId,
    required String phone,
    required String description,
    required String primaryButtonText,
    required IconData primaryButtonIcon,
    required bool showRejectButton,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(12)), child: Text(badgeText, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: badgeTextColor))),
            ],
          ),
          const SizedBox(height: 6),
          Text(petInfo, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _textLight)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(submittedTime, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
              Text(requestId, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: _textLight)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 16, color: _textDark),
              const SizedBox(width: 6),
              Text(phone, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark)),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700, height: 1.4)),
          const SizedBox(height: 15),

          // Action Buttons
          Row(
            children: [
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () {},
                  child: Container(
                    height: 45, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.visibility_outlined, color: _textDark, size: 16), const SizedBox(width: 4), Text("View", style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: _textDark))]),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 🚨 Dynamic Primary Button
              Expanded(
                flex: showRejectButton ? 3 : 4,
                child: InkWell(
                  onTap: () {
                    if (primaryButtonText == "Approve" || primaryButtonText == "Final Approve") {
                      _updateStatus(rawId, 'approved', applicantUserId: applicantId); // 🚨 Pass it here
                    } else if (primaryButtonText == "Schedule\nInterview") {
                      _updateStatus(rawId, 'interview_scheduled');
                    }
                  },
                  child: Container(
                    height: 45, decoration: BoxDecoration(color: _primaryGreen, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(primaryButtonIcon, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(primaryButtonText, textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1)),
                      ],
                    ),
                  ),
                ),
              ),

              // 🚨 Reject Button
              if (showRejectButton) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: InkWell(
                    onTap: () => _updateStatus(rawId, 'rejected'),
                    child: Container(
                      height: 45, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.close, color: Colors.black87, size: 16), const SizedBox(width: 4), Text("Reject", style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87))]),
                    ),
                  ),
                ),
              ],
            ],
          )
        ],
      ),
    );
  }
}