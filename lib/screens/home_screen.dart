import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import your actual screens!
import 'package:mobile_app/screens/report_case_screen.dart';
import 'package:mobile_app/screens/adoption_screen.dart';
import 'package:mobile_app/screens/lost_found_screen.dart';
import 'package:mobile_app/screens/profile_screen.dart';

import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ==========================================
  // SHARED STATE (Navigation)
  // ==========================================
  int _currentIndex = 0;

  // ==========================================
  // HOME SCREEN FEED STATE
  // ==========================================
  String _userName = 'User';
  bool _isLoading = true;

  List<Map<String, dynamic>> _recentCases = [];
  List<Map<String, dynamic>> _localShelters = [];
  List<Map<String, dynamic>> _partnerClinics = [];

  final Color _primaryOrange = const Color(0xffffa94d);
  final Color _primaryGreen = const Color(0xff5bb381);
  final Color _dangerRed = const Color(0xfff46363);

  @override
  void initState() {
    super.initState();
    _fetchHomeFeedData();
  }

  // ==========================================
  // DATABASE QUERIES (The Magic)
  // ==========================================
  Future<void> _fetchHomeFeedData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user != null) {
        // 1. Get User Name
        final userData = await supabase.from('users').select('full_name').eq('id', user.id).maybeSingle();
        if (userData != null && userData['full_name'] != null) {
          _userName = userData['full_name'].split(' ')[0]; // Get first name
        }
      }

      // 2. Get 3 Most Recent Urgent Cases (Open pool)
      final casesData = await supabase
          .from('cases')
          .select()
          .eq('status', 'new')
          .order('created_at', ascending: false)
          .limit(3);

      // 3. Get Approved Shelters
      final sheltersData = await supabase
          .from('shelters')
          .select()
          .eq('status', 'approved')
          .limit(5);

      // 4. Get Approved Clinics (Wait, if you don't have clinics yet, it won't crash, it just returns empty!)
      final clinicsData = await supabase
          .from('clinics')
          .select()
          .eq('status', 'approved')
          .limit(5);

      if (mounted) {
        setState(() {
          _recentCases = List<Map<String, dynamic>>.from(casesData);
          _localShelters = List<Map<String, dynamic>>.from(sheltersData);
          _partnerClinics = List<Map<String, dynamic>>.from(clinicsData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching home feed: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper for Time
  String _getTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return "Unknown time";
    Duration diff = DateTime.now().difference(DateTime.parse(dateTimeStr).toLocal());
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }

  // ==========================================
  // THE MAIN BUILD (MASTER SCAFFOLD)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeFeedTab(),      // Index 0
          const ReportCaseScreen(), // Index 1
          const AdoptionScreen(),   // Index 2
          const LostFoundScreen(),  // Index 3
          const ProfileScreen(),    // Index 4
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _primaryGreen,
        unselectedItemColor: Colors.black54,
        selectedLabelStyle: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.nunito(fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: "Report"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), label: "Adoption"),
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), label: "Lost"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }

  // ==========================================
  // THE NEW COMMUNITY FEED UI
  // ==========================================
  Widget _buildHomeFeedTab() {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),

      // 1. CLEAN APP BAR
      appBar: AppBar(

        centerTitle: false,

        leading: Image.asset("assets/images/logo.PNG", fit: BoxFit.cover),

        title: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text("Hi, $_userName!", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black)),

            Text("Ready to save a life today?", style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey)),

          ],

        ),
        actions: [
          IconButton(
            icon: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                child: const Icon(Icons.notifications_none_outlined, color: Colors.black87, size: 20)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),

      // 2. MAIN SCROLLING FEED
      body: RefreshIndicator(
        onRefresh: _fetchHomeFeedData,
        color: _primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.grey.shade200)),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search cases, shelters, vets...",
                    hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w600),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()))
              else ...[

                // --- SECTION 1: URGENT ALERTS ---
                _buildSectionHeader("Urgent Alerts", "See all"),
                const SizedBox(height: 15),
                if (_recentCases.isEmpty)
                  _buildEmptyState("No urgent cases nearby. You're all caught up!")
                else
                  ..._recentCases.map((c) => _buildCaseAlertCard(c)),

                const SizedBox(height: 35),

                // --- SECTION 2: LOCAL SHELTERS ---
                _buildSectionHeader("Local Shelters", "View map"),
                const SizedBox(height: 15),
                if (_localShelters.isEmpty)
                  _buildEmptyState("No approved shelters in your area yet.")
                else
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _localShelters.length,
                      itemBuilder: (context, index) => _buildPartnerCard(
                        title: _localShelters[index]['name'] ?? 'Shelter',
                        subtitle: _localShelters[index]['city'] ?? 'Local Area',
                        icon: Icons.other_houses_outlined,
                        color: _primaryGreen,
                      ),
                    ),
                  ),

                const SizedBox(height: 35),

                // --- SECTION 3: PARTNER CLINICS ---
                _buildSectionHeader("Partner Clinics", "View all"),
                const SizedBox(height: 15),
                if (_partnerClinics.isEmpty)
                  _buildEmptyState("No verified clinics available right now.")
                else
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _partnerClinics.length,
                      itemBuilder: (context, index) => _buildPartnerCard(
                        title: _partnerClinics[index]['name'] ?? 'Vet Clinic',
                        subtitle: _partnerClinics[index]['city'] ?? 'Local Area',
                        icon: Icons.medical_services_outlined,
                        color: Colors.blue.shade400,
                      ),
                    ),
                  ),

                const SizedBox(height: 40),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // UI HELPER WIDGETS
  // ==========================================

  Widget _buildSectionHeader(String title, String actionText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black87)),
        Text(actionText, style: GoogleFonts.nunito(fontSize: 12, color: _primaryOrange, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Center(child: Text(message, textAlign: TextAlign.center, style: GoogleFonts.nunito(color: Colors.grey.shade500, fontWeight: FontWeight.w600))),
    );
  }

  Widget _buildCaseAlertCard(Map<String, dynamic> caseData) {
    final animalType = caseData['animal_type'] ?? 'Animal';
    final severity = caseData['severity'] ?? 'moderate';
    final timeAgo = _getTimeAgo(caseData['created_at']);

    Color badgeColor = severity == 'emergency' ? _dangerRed : (severity == 'low' ? _primaryGreen : const Color(0xffd97706));

    return Container(
      margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 60, width: 60, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)), child: Icon(Icons.pets, color: Colors.grey.shade400)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Reported $animalType", style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87)),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(severity.toUpperCase(), style: GoogleFonts.nunito(fontSize: 9, color: badgeColor, fontWeight: FontWeight.w900)))
                  ],
                ),
                const SizedBox(height: 4),
                Text("Reported $timeAgo • Location Pinned", style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text("View Details", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryGreen)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 10, color: _primaryGreen),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPartnerCard({required String title, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      width: 130, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)),
          const Spacer(),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}