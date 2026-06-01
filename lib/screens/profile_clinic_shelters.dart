import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganizationProfileScreen extends StatefulWidget {
  const OrganizationProfileScreen({super.key});

  @override
  State<OrganizationProfileScreen> createState() => _OrganizationProfileScreenState();
}

class _OrganizationProfileScreenState extends State<OrganizationProfileScreen> {
  // ==========================================
  // STATE VARIABLES
  // ==========================================
  bool _isLoading = true;
  bool _isSaving = false;
  String? _tableName; // Will be 'shelters' or 'clinics'
  String _status = 'pending';
  String _licenseNumber = '';

  // Controllers for editable fields
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  final Color _primaryGreen = const Color(0xff5bb381);
  final Color _bgGrey = const Color(0xffF8F9FA);

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  // ==========================================
  // 1. FETCH DATA (Smart Detection)
  // ==========================================
  Future<void> _fetchProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Check if user is a shelter
      var data = await Supabase.instance.client.from('shelters').select().eq('user_id', user.id).maybeSingle();

      if (data != null) {
        _tableName = 'shelters';
      } else {
        // If not a shelter, check if user is a clinic
        data = await Supabase.instance.client.from('clinics').select().eq('user_id', user.id).maybeSingle();
        if (data != null) _tableName = 'clinics';
      }

      // Populate UI if data was found
      if (data != null && mounted) {
        setState(() {
          // 🚨 ADDED QUESTION MARKS HERE TO FIX THE NULL ERROR 🚨
          _nameCtrl.text = data?['name'] ?? '';
          _phoneCtrl.text = data?['phone'] ?? '';
          _cityCtrl.text = data?['city'] ?? '';
          _addressCtrl.text = data?['address'] ?? '';
          _descCtrl.text = data?['description'] ?? '';
          _licenseNumber = data?['license_number'] ?? 'Not provided';
          _status = data?['status'] ?? 'pending';
          _isLoading = false;
        });
      } else {
        // Fallback if no profile exists
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 2. SAVE CHANGES TO DB
  // ==========================================
  Future<void> _saveChanges() async {
    if (_tableName == null) return;

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;

      await Supabase.instance.client.from(_tableName!).update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('user_id', user!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==========================================
  // 3. LOGOUT
  // ==========================================
  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/sign_in'); // Adjust to your actual login route
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        backgroundColor: _bgGrey,
        elevation: 0,
        title: Text("Organization Profile", style: GoogleFonts.nunito(color: Colors.black87, fontWeight: FontWeight.w900)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tableName == null
          ? _buildNoProfileState()
          : _buildProfileForm(),
    );
  }

  // ==========================================
  // UI: PROFILE FORM
  // ==========================================
  Widget _buildProfileForm() {
    final bool isApproved = _status == 'approved';
    final Color badgeColor = isApproved ? _primaryGreen : const Color(0xffffa94d);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Status
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                Container(height: 70, width: 70, decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.business, color: badgeColor, size: 30)),
                const SizedBox(height: 12),
                Text(_tableName == 'shelters' ? "Shelter Account" : "Clinic Account", style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isApproved ? Icons.check_circle : Icons.timer, size: 14, color: badgeColor),
                      const SizedBox(width: 6),
                      Text(_status.toUpperCase(), style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w900, color: badgeColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          Text("Public Details", style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 15),

          _buildLabel("Organization Name"),
          _buildTextField(controller: _nameCtrl, icon: Icons.business),
          const SizedBox(height: 15),

          _buildLabel("Phone Number"),
          _buildTextField(controller: _phoneCtrl, icon: Icons.phone_outlined, isPhone: true),
          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_buildLabel("City / Area"), _buildTextField(controller: _cityCtrl, icon: Icons.location_city)])),
            ],
          ),
          const SizedBox(height: 15),

          _buildLabel("Street Address"),
          _buildTextField(controller: _addressCtrl, icon: Icons.map_outlined),
          const SizedBox(height: 15),

          _buildLabel("About Us / Description"),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
            child: TextField(
              controller: _descCtrl,
              maxLines: 4,
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: InputBorder.none, hintText: "Describe your services..."),
            ),
          ),
          const SizedBox(height: 25),

          // Read-Only Section
          Text("Registration Details", style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Medical / Operating License", style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_licenseNumber, style: GoogleFonts.nunito(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text("License numbers cannot be edited after initial registration. Contact support for changes.", style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Save Button
          InkWell(
            onTap: _isSaving ? null : _saveChanges,
            child: Container(
              height: 55, width: double.infinity,
              decoration: BoxDecoration(color: _isSaving ? Colors.grey : _primaryGreen, borderRadius: BorderRadius.circular(30)),
              child: Center(
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Save Changes", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ==========================================
  // HELPER WIDGETS
  // ==========================================
  Widget _buildNoProfileState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Text("No organization profile found for this user.", textAlign: TextAlign.center, style: GoogleFonts.nunito(color: Colors.grey.shade600, fontSize: 16)),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(text, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required IconData icon, bool isPhone = false}) {
    return Container(
      height: 50, padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
              style: GoogleFonts.nunito(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
        ],
      ),
    );
  }
}