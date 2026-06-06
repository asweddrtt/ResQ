import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../go_router/routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  String _userName = "Loading...";
  String _userRole = "Volunteer";

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

// ==========================================
  // LOGIC: Fetch User Data
  // ==========================================
  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('users')
          .select('full_name, role') // 🚨 CHANGED: Match your actual DB columns!
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          // 🚨 CHANGED: Map to full_name
          _userName = (data['full_name'] ?? 'ResQ User').toString().trim();
          if (_userName.isEmpty) _userName = "ResQ User";

          _userRole = (data['role'] ?? 'volunteer').toString();
          // Capitalize first letter of role
          _userRole = _userRole[0].toUpperCase() + _userRole.substring(1);

          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // LOGIC: Logout
  // ==========================================
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      context.go('/sign_in'); // 🚨 Sends them back to login!
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 1. HEADER
              // ==========================================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xffffa94d).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_outline, color: Color(0xffffa94d), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Profile",
                        style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                      ),
                    ],
                  ),
                  // 🚨 CHANGED: Empty circle is now a Logout Button!
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // ==========================================
              // 2. USER INFO CARD
              // ==========================================
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundColor: Color(0xff5bb381),
                      child: Icon(Icons.person, color: Colors.white, size: 35),
                    ),
                    const SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _isLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(_userName, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text(
                            "$_userRole",
                            style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              _buildProfileTag(Icons.campaign, "Active"),
                              const SizedBox(width: 10),
                              _buildProfileTag(Icons.favorite_border, "Rescuer"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ==========================================
              // 3. MY ACTIVITY SECTION
              // ==========================================
              Text("My Activity", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade300)),
              const SizedBox(height: 15),

              _buildMenuTile(icon: Icons.flag_outlined,onTap: _showMyReports, title: "My Reports", subtitle: "Track lost/found submissions and updates", trailingWidget: _buildStatusPill("Active", const Color(0xff5bb381), Colors.white)),
              _buildMenuTile(icon: Icons.inbox_outlined, title: "Messages",
                  onTap: () => context.push(AppRoutes.messages),
                  subtitle: "Chats with rescuers & vets", trailingWidget: _buildStatusPill("Inbox", const Color(0xffffa94d), Colors.black87)),
              _buildMenuTile(icon: Icons.support_agent, title: "Contact Support",
                  onTap: () => context.push(AppRoutes.supportChat),
                  subtitle: "contact customer support", trailingWidget: _buildStatusPill("Inbox",  Colors.green, Colors.black87)),
              const SizedBox(height: 25),

              // ==========================================
              // 4. PREFERENCES SECTION
              // ==========================================
              Text("Preferences", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.blueGrey.shade300)),
              const SizedBox(height: 15),

              _buildMenuTile(icon: Icons.notifications_none_outlined,onTap: () {
                setState(() {
                  _notificationsEnabled = !_notificationsEnabled;
                });
              }, title: "Notifications", subtitle: "Nearby alerts, matches, updates",
                  trailingWidget: Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _notificationsEnabled ? const Color(0xff5bb381) : Colors.red,
                          borderRadius: BorderRadius.circular(15)),
                      child: Text(_notificationsEnabled ? "ON" : "OFF", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)))),
              _buildMenuTile(icon: Icons.shield_outlined, title: "Account & Security", subtitle: "Phone, email, password",onTap: _showAccountSecurity),
              _buildMenuTile(
                icon: Icons.volunteer_activism_outlined, // Changed icon to match donation vibe
                title: "Make a Donation",
                subtitle: "Support our platform and partners",
                onTap: _showDonationSheet,
              ),
              const SizedBox(height: 30),

              // ==========================================
              // 5. BOTTOM ACTION BUTTONS
              // ==========================================
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(color: const Color(0xffffa94d), borderRadius: BorderRadius.circular(25)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit_outlined, color: Colors.black87, size: 18),
                            const SizedBox(width: 8),
                            Text("Edit Profile", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: InkWell(
                      // 🚨 CHANGED: Wires directly to your report case screen!
                      onTap: () => context.push('/report_case'),
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(color: const Color(0xff5bb381), borderRadius: BorderRadius.circular(25)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text("New Report", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================

  // ==========================================
  // LOGIC: Show Donation Bottom Sheet
  // ==========================================
  // ==========================================
  // LOGIC: Show Donation Bottom Sheet
  // ==========================================
  void _showDonationSheet() {
    final TextEditingController amountController = TextEditingController();
    String? selectedCaseId; // Changed from selectedOrg
    bool isProcessing = false;

    // Fetch cases instead of shelters/clinics
    Future<List<Map<String, dynamic>>> fetchCases() async {
      final supabase = Supabase.instance.client;
      // You can add a filter here like .eq('status', 'new') if you only want open cases
      final response = await supabase.from('cases').select('id, animal_type, description');
      return List<Map<String, dynamic>>.from(response);
    }

    final Future<List<Map<String, dynamic>>> casesFuture = fetchCases();

    // Helper future to fetch all organizations
    Future<List<String>> fetchOrganizations() async {
      final supabase = Supabase.instance.client;
      final shelters = await supabase.from('shelters').select('name');
      final clinics = await supabase.from('clinics').select('name');

      // 🚨 FIX 1: Use a Set to automatically remove duplicate names
      Set<String> orgs = {};

      for (var s in shelters) {
        final name = s['name']?.toString().trim();
        if (name != null && name.isNotEmpty) orgs.add(name);
      }
      for (var c in clinics) {
        final name = c['name']?.toString().trim();
        if (name != null && name.isNotEmpty) orgs.add(name);
      }
      return orgs.toList()..sort(); // Convert back to list and sort
    }

    // 🚨 FIX 2: Store the future once so it doesn't rebuild on every state change
    final Future<List<String>> orgsFuture = fetchOrganizations();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setSheetState) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
                child: Container(
                  height: MediaQuery.of(sheetContext).size.height * 0.6,
                  padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 20),
                      Text("Make a Donation", style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
                      Text("Support the rescue community", style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 25),

                      // AMOUNT INPUT
                      Text("Amount (EGP)", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.attach_money, color: Color(0xff5bb381)),
                          hintText: "0.00",
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xff5bb381), width: 2)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // CASE DROPDOWN
                      Text("Direct my donation to a case (Optional)", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: casesFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Color(0xff5bb381)));
                          }

                          List<Map<String, dynamic>> casesList = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            ),
                            hint: Text("General Platform Fund", style: GoogleFonts.nunito(color: Colors.grey.shade500)),
                            value: selectedCaseId,
                            isExpanded: true,
                            items: casesList.map((caseData) {
                              // Create a label using the animal type and description
                              final animal = caseData['animal_type'] ?? 'Unknown Animal';
                              final desc = caseData['description'] ?? 'No description';

                              return DropdownMenuItem<String>(
                                value: caseData['id'].toString(), // Use the case ID as the actual value
                                child: Text(
                                  "$animal - $desc",
                                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setSheetState(() => selectedCaseId = val),
                          );
                        },
                      ),


                      const Spacer(),

                      // PAY BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff5bb381),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 0,
                          ),
                          onPressed: isProcessing ? null : () async {
                            final amountText = amountController.text.trim();
                            final amount = double.tryParse(amountText);

                            if (amount == null || amount <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid amount", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
                              return;
                            }

                            setSheetState(() => isProcessing = true);

                            try {
                              debugPrint("--- STRIPE FLOW START ---");
                              debugPrint("1. Calling Supabase Edge Function...");

                              final response = await Supabase.instance.client.functions.invoke(
                                'payment-intent',
                                body: {'amount': amount},
                              ).timeout(const Duration(seconds: 30));

                              debugPrint("2. Function Response received: ${response.data}");

                              final clientSecret = response.data['clientSecret'];
                              final transactionId = response.data['transactionId'];

                              if (clientSecret == null) {
                                throw Exception("Edge function did not return a clientSecret.");
                              }

                              debugPrint("3. Initializing Stripe Payment Sheet...");
                              await Stripe.instance.initPaymentSheet(
                                paymentSheetParameters: SetupPaymentSheetParameters(
                                  paymentIntentClientSecret: clientSecret,
                                  merchantDisplayName: 'ResQ App',
                                ),
                              );

                              debugPrint("4. Presenting Payment Sheet to user...");
                              await Stripe.instance.presentPaymentSheet();

                              debugPrint("5. Payment successful! Saving to database...");
                              final user = Supabase.instance.client.auth.currentUser;
                              await Supabase.instance.client.from('donations').insert({
                                'donor_user_id': user?.id, // Captures the current user
                                'case_id': selectedCaseId, // Maps to the selected dropdown value
                                'amount': amount,
                                'status': 'completed',
                                'payment_method': 'stripe',
                                'transaction_id': transactionId,
                                'currency': 'EGP',
                                'notes': selectedCaseId != null ? 'Directed to specific case' : 'General Platform Fund',

                              }).timeout(const Duration(seconds: 10));

                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Donation successful! Thank you!"), backgroundColor: Color(0xff5bb381))
                                );
                              }
                            } on StripeException catch (e) {
                              // 🚨 ADDED: More detailed Stripe logging
                              debugPrint("💳 --- STRIPE ERROR ---");
                              debugPrint("Message: ${e.error.localizedMessage}");
                              debugPrint("Code: ${e.error.code}");
                              debugPrint("Stripe Error Details: ${e.error}");
                              debugPrint("------------------------");

                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Payment cancelled or failed."), backgroundColor: Colors.orange)
                                );
                              }
                            } catch (e, stackTrace) {
                              // 🚨 ADDED: StackTrace to see EXACTLY where the code broke
                              debugPrint("❌ --- GENERAL ERROR ---");
                              debugPrint("Error type: ${e.runtimeType}");
                              debugPrint("Error message: $e");
                              debugPrint("StackTrace:\n$stackTrace");
                              debugPrint("------------------------");

                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent)
                                );
                              }
                            } finally {
                              debugPrint("--- STRIPE FLOW END ---");
                              if (sheetContext.mounted) {
                                setSheetState(() => isProcessing = false);
                              }
                            }
                          },
                          child: isProcessing
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text("Proceed to Payment", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
        );
      },
    );
  }

  Widget _buildProfileTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xffffa94d), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.black87),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87)),
        ],
      ),
    );
  }

// 🚨 CHANGED: Added onTap and wrapped in InkWell
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailingWidget,
    VoidCallback? onTap, // <-- Added this
  }) {
    return InkWell(
      onTap: onTap, // <-- Added this
      borderRadius: BorderRadius.circular(25),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.black87, size: 24),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
                  Text(subtitle, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
                ],
              ),
            ),
            if (trailingWidget != null) trailingWidget,
          ],
        ),
      ),
    );
  }
  Widget _buildStatusPill(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
      child: Text(text, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w800, color: textColor)),
    );
  }

  // ==========================================
  // LOGIC: Show My Reports Bottom Sheet
  // ==========================================
  void _showMyReports() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final user = Supabase.instance.client.auth.currentUser;

        return Container(
          height: MediaQuery.of(context).size.height * 0.75, // Takes up 75% of the screen
          padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              Text("My Reports", style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 15),

              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: Supabase.instance.client
                      .from('cases')
                      .select()
                      .eq('reported_by', user?.id ?? '')
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xff5bb381)));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error loading reports", style: GoogleFonts.nunito()));
                    }

                    final cases = snapshot.data;
                    if (cases == null || cases.isEmpty) {
                      return Center(child: Text("You haven't reported any cases yet.", style: GoogleFonts.nunito(color: Colors.grey)));
                    }

                    return ListView.builder(
                      itemCount: cases.length,
                      itemBuilder: (context, index) {
                        final report = cases[index];
                        final rawDate = DateTime.parse(report['created_at']);
                        final dateStr = "${rawDate.year}-${rawDate.month.toString().padLeft(2, '0')}-${rawDate.day.toString().padLeft(2, '0')}";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    report['animal_type'] ?? 'Unknown Animal',
                                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    dateStr,
                                    style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                report['description'] ?? 'No description provided.',
                                style: GoogleFonts.nunito(fontSize: 13, color: Colors.black87),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildStatusPill(
                                      (report['status'] ?? 'Unknown').toString().toUpperCase(),
                                      report['status'] == 'new' ? Colors.blue.shade50 : Colors.green.shade50,
                                      report['status'] == 'new' ? Colors.blue : Colors.green
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusPill(
                                      (report['severity'] ?? 'Unknown').toString().toUpperCase(),
                                      report['severity'] == 'emergency' ? Colors.red.shade50 : Colors.orange.shade50,
                                      report['severity'] == 'emergency' ? Colors.red : Colors.orange
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAccountSecurity() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) { // 🚨 CHANGED: renamed context to avoid collisions
        final user = Supabase.instance.client.auth.currentUser;

        return Container(
          height: MediaQuery.of(bottomSheetContext).size.height * 0.55,
          padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              Text("Account & Security", style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 🚨 CHANGED: Wired up Supabase password reset
                      _buildMenuTile(
                        icon: Icons.lock_outline,
                        title: "Change Password",
                        subtitle: "Send a password reset email",
                        onTap: () async {
                          final email = user?.email;
                          if (email == null) return;

                          try {
                            await Supabase.instance.client.auth.resetPasswordForEmail(email);
                            if (bottomSheetContext.mounted) {
                              Navigator.pop(bottomSheetContext); // Close the bottom sheet
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Password reset email sent!"),
                                  backgroundColor: Color(0xff5bb381),
                                ),
                              );
                            }
                          } catch (e) {
                            if (bottomSheetContext.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error sending email: $e"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      // 🚨 CHANGED: Wired up Update Email with a Dialog
                      _buildMenuTile(
                        icon: Icons.email_outlined,
                        title: "Update Email",
                        subtitle: user?.email ?? "No email linked",
                        onTap: () {
                          final emailController = TextEditingController();
                          showDialog(
                            context: bottomSheetContext,
                            builder: (dialogContext) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: Text("Update Email", style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
                              content: TextField(
                                controller: emailController,
                                decoration: InputDecoration(
                                  hintText: "Enter new email",
                                  hintStyle: GoogleFonts.nunito(color: Colors.grey),
                                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xff5bb381))),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text("Cancel", style: GoogleFonts.nunito(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final newEmail = emailController.text.trim();
                                    if (newEmail.isEmpty) return;

                                    try {
                                      await Supabase.instance.client.auth.updateUser(
                                        UserAttributes(email: newEmail),
                                      );
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext); // Close dialog
                                        Navigator.pop(bottomSheetContext); // Close bottom sheet
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Confirmation link sent to your new email!"),
                                            backgroundColor: Color(0xff5bb381),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    }
                                  },
                                  child: Text("Update", style: GoogleFonts.nunito(color: const Color(0xff5bb381), fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // 🚨 CHANGED: Biometric Login removed completely

                      // 🚨 CHANGED: Wired up Delete Account with a Confirmation Dialog
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () {
                          showDialog(
                            context: bottomSheetContext,
                            builder: (dialogContext) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: Text("Delete Account?", style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: Colors.redAccent)),
                              content: Text(
                                "This action cannot be undone. All your data will be permanently lost.",
                                style: GoogleFonts.nunito(color: Colors.black87),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text("Cancel", style: GoogleFonts.nunito(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      // Note: Actual deletion requires setting up an RPC function in Supabase.
                                      // await Supabase.instance.client.rpc('delete_user');

                                      await Supabase.instance.client.auth.signOut();

                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext); // Close dialog
                                        context.go('/sign_in'); // Send back to login
                                      }
                                    } catch (e) {
                                      if (dialogContext.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
                                        );
                                      }
                                    }
                                  },
                                  child: Text("Delete", style: GoogleFonts.nunito(color: Colors.redAccent, fontWeight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                        label: Text(
                            "Delete Account",
                            style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.redAccent)
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}