import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClinicCasesScreen extends StatefulWidget {
  const ClinicCasesScreen({super.key});

  @override
  State<ClinicCasesScreen> createState() => _ClinicCasesScreenState();
}

class _ClinicCasesScreenState extends State<ClinicCasesScreen> {
  final Color _bgGrey = const Color(0xffF8F9FA);
  final Color _textDark = Colors.black87;
  final Color _textLight = Colors.grey.shade500;
  final Color _primaryBlue = const Color(0xff5D8ED5); // Blue for Clinics
  final Color _dangerRed = const Color(0xfff46363);

  bool _isClaiming = false;
  String? _myClinicId;

  // ==========================================
  // LOGIC: Resolve / Close a Case
  // ==========================================
  Future<void> _markCaseResolved(String caseId, String reason) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      await Supabase.instance.client.from('cases').update({
        'status': 'resolved', // Or 'closed' depending on your DB Enum
        'close_reason': reason.trim(),
        'closed_at': DateTime.now().toUtc().toIso8601String(),
        'closed_by': user.id,
      }).eq('id', caseId);

      if (mounted) {
        Navigator.pop(context); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case successfully resolved! Great job.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error closing case: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // UI: Show Closing Dialog
  // ==========================================
  void _showUpdateStatusDialog(String caseId) {
    final TextEditingController reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text("Resolve Case", style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Add a quick note about the treatment or outcome before closing this case.", style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade600)),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                        child: TextField(
                          controller: reasonController,
                          maxLines: 3,
                          decoration: const InputDecoration(border: InputBorder.none, hintText: "e.g., Surgery successful, resting now."),
                          style: GoogleFonts.nunito(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: GoogleFonts.nunito(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff5D8ED5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                      onPressed: isSubmitting
                          ? null
                          : () {
                        if (reasonController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add a closing note.")));
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        _markCaseResolved(caseId, reasonController.text);
                      },
                      child: isSubmitting
                          ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Mark Resolved", style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  // Real-time stream of cases
  final _casesStream = Supabase.instance.client
      .from('cases')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  @override
  void initState() {
    super.initState();
    _fetchMyClinicId();
  }

  // 1. Fetch the Clinic ID linked to this logged-in User
  Future<void> _fetchMyClinicId() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('clinics')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() => _myClinicId = data['id']);
      }
    } catch (e) {
      debugPrint("Error fetching clinic ID: $e");
    }
  }

  // ==========================================
  // LOGIC: Accept a Case
  // ==========================================
  Future<void> _acceptCase(String caseId) async {
    if (_myClinicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wait for your clinic profile to load.')));
      return;
    }

    setState(() => _isClaiming = true);

    try {
      // 🚨 ATOMIC UPDATE: Only update if it hasn't been assigned to someone else yet!
      final response = await Supabase.instance.client
          .from('cases')
          .update({
        'assigned_to_type': 'clinic',
        'assigned_to_id': _myClinicId, // Assign to me!
        'status': 'in_progress',       // Escalate the status
      })
          .eq('id', caseId)
          .isFilter('assigned_to_id', null) // Prevents double-booking!
          .select();

      if (response.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Too late! Another clinic accepted this case.'), backgroundColor: Colors.orange));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case accepted! Please prepare for arrival.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  String _getTimeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return "Unknown";
    Duration diff = DateTime.now().difference(DateTime.parse(dateTimeStr).toLocal());
    if (diff.inHours > 0) return "${diff.inHours} hrs ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes} min ago";
    return "Just now";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // HEADER
            // ==========================================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.medical_services_rounded, color: _primaryBlue, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Medical & Transport", style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: _textDark)),
                        Text("Cases secured by shelters", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // STREAM BUILDER FOR LISTS
            // ==========================================
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _casesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

                  final allCases = snapshot.data ?? [];

                  // 🚨 FILTER 1: Open cases that a shelter has claimed, but no clinic has accepted
                  final openPoolCases = allCases.where((c) =>
                  c['claimed_by_type'] == 'shelter' &&
                      c['assigned_to_id'] == null
                  ).toList();

                  // 🚨 FILTER 2: Cases assigned specifically to this clinic
                  final myAcceptedCases = allCases.where((c) =>
                  c['assigned_to_id'] == _myClinicId
                  ).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // --- SECTION 1: SECURED BY SHELTER (Awaiting Clinic) ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Awaiting Clinic", style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
                                Text("Shelter approved, needs medical/transport", style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _textLight)),
                              ],
                            ),
                            Text("${openPoolCases.length} waiting", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryBlue)),
                          ],
                        ),
                        const SizedBox(height: 15),

                        if (openPoolCases.isEmpty)
                          _buildEmptyState("No pending cases right now.")
                        else
                          ...openPoolCases.map((c) => _buildCaseCard(c, isOpenPool: true)),

                        const SizedBox(height: 35),

                        // --- SECTION 2: MY ACCEPTED CASES ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("My Active Cases", style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
                                Text("Animals you are currently treating", style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _textLight)),
                              ],
                            ),
                            Text("${myAcceptedCases.length} active", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green)),
                          ],
                        ),
                        const SizedBox(height: 15),

                        if (myAcceptedCases.isEmpty)
                          _buildEmptyState("You haven't accepted any cases yet.")
                        else
                          ...myAcceptedCases.map((c) => _buildCaseCard(c, isOpenPool: false)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Center(child: Text(message, style: GoogleFonts.nunito(color: _textLight, fontWeight: FontWeight.w600))),
    );
  }

  Widget _buildCaseCard(Map<String, dynamic> caseData, {required bool isOpenPool}) {
    final String id = caseData['id'] ?? '';
    final String shortId = "CASE-${id.length > 4 ? id.substring(0, 4).toUpperCase() : id}";
    final String animalType = caseData['animal_type'] ?? 'Unknown';
    final String severity = caseData['severity'] ?? 'moderate';
    final String status = caseData['status'] ?? 'new'; // 🚨 Grab the status!
    final String description = caseData['description'] ?? 'No description provided.'; // 🚨 Grab the description!
    final String timeAgo = _getTimeAgo(caseData['claimed_at'] ?? caseData['created_at']);

    Color severityColor = severity == 'emergency' ? _dangerRed : (severity == 'low' ? Colors.green : const Color(0xffd97706));
    return Container(
      margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Reported $animalType", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: _textDark)),
              _buildBadge(severity.toUpperCase(), severityColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(shortId, style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
          Text("Shelter Secured: $timeAgo", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
          // 🚨 THE APPEND-ONLY DESCRIPTION BOX
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Case Notes", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: _textDark)),
                    // 🚨 Changed to an "Add Comment" icon pointing to the new dialog
                    if (!isOpenPool && status != 'resolved' && status != 'closed')
                      GestureDetector(
                        onTap: () => _showAddNoteDialog(id, description),
                        child: Icon(Icons.add_comment, size: 18, color: _primaryBlue),
                      )
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          if (isOpenPool)
            InkWell(
              onTap: _isClaiming ? null : () => _acceptCase(id),
              borderRadius: BorderRadius.circular(25),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: _primaryBlue, borderRadius: BorderRadius.circular(25)),
                child: Center(
                  child: _isClaiming
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("Accept Case", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            )
          else
            InkWell(
              onTap: () => _showUpdateStatusDialog(id),
              borderRadius: BorderRadius.circular(25),
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _primaryBlue), borderRadius: BorderRadius.circular(25)),
                child: Center(
                  child: Text("Update Medical Status", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryBlue)),
                ),
              ),
            ),
        ],
      ),
    );
  }


// ==========================================
  // LOGIC: Append New Note to Description
  // ==========================================
  Future<void> _addCaseNote(String caseId, String oldDescription, String newNote) async {
    try {
      // 🚨 Format the new string: Old text + line breaks + Update Tag + New Text
      final String combinedDescription = '$oldDescription\n\n[Update]: ${newNote.trim()}';

      await Supabase.instance.client.from('cases').update({
        'description': combinedDescription,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', caseId);

      if (mounted) {
        Navigator.pop(context); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding note: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // UI: Show "Add Update" Dialog
  // ==========================================
  void _showAddNoteDialog(String caseId, String currentDescription) {
    final TextEditingController noteController = TextEditingController(); // Starts completely empty!
    bool isSubmitting = false;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text("Add Case Update", style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. READ-ONLY HISTORY
                        Text("Previous Notes:", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 100),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                          child: SingleChildScrollView(
                            child: Text(currentDescription, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade700)),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // 2. NEW NOTE INPUT
                        Text("New Update:", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300)
                          ),
                          child: TextField(
                            controller: noteController,
                            maxLines: 3,
                            decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: "e.g., Bloodwork came back clear...",
                                hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400, fontSize: 13)
                            ),
                            style: GoogleFonts.nunito(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: GoogleFonts.nunito(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff5D8ED5), // Blue for Clinic!
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () {
                        if (noteController.text.trim().isEmpty) return;
                        setDialogState(() => isSubmitting = true);
                        _addCaseNote(caseId, currentDescription, noteController.text);
                      },
                      child: isSubmitting
                          ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Add Note", style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }
}