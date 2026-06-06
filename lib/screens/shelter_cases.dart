import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShelterCasesScreen extends StatefulWidget {
  final bool isReadOnly; // 🚨 Add this flag
  const ShelterCasesScreen({super.key, this.isReadOnly = false});

  @override
  State<ShelterCasesScreen> createState() => _ShelterCasesScreenState();
}

class _ShelterCasesScreenState extends State<ShelterCasesScreen> {
  final Color _bgGrey = const Color(0xffF8F9FA);
  final Color _textDark = Colors.black87;
  final Color _textLight = Colors.grey.shade500;
  final Color _primaryGreen = const Color(0xff5bb381);
  final Color _primaryOrange = const Color(0xffffa94d);
  final Color _dangerRed = const Color(0xfff46363);

  int _selectedTabIndex = 0;
  String? _myShelterId;
  bool _isClaiming = false;

  // 🚨 NEW: State variable for the "See all" toggle
  bool _showAllOpenCases = false;

  // Real-time stream of ALL cases
  final _casesStream = Supabase.instance.client
      .from('cases')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  @override
  void initState() {
    super.initState();
    _myShelterId = Supabase.instance.client.auth.currentUser?.id;
  }

  // ==========================================
  // LOGIC: Claim a Case
  // ==========================================
  Future<void> _claimCase(String caseId) async {
    if (_myShelterId == null) return;

    setState(() => _isClaiming = true);

    try {
      final response = await Supabase.instance.client
          .from('cases')
          .update({
        'status': 'assigned',
        'claimed_by_id': _myShelterId,
        'claimed_by_type': 'shelter',
        'claimed_at': DateTime.now().toUtc().toIso8601String(),
      })
          .eq('id', caseId)
          .eq('status', 'new')
          .select();

      if (response.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Too late! Another shelter claimed this case.'), backgroundColor: Colors.orange),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case claimed successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error claiming case: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

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
        child: Column(
          children: [
            // ==========================================
            // STATIC HEADER
            // ==========================================
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: _primaryOrange.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.warning_amber_rounded, color: _primaryOrange, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text("Rescue Operations", style: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w900, color: _textDark)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  final allCases = snapshot.data ?? [];
                  final String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

                  // 🚨 FILTER ALL OPEN CASES
                  final openPoolCases = allCases.where((c) => c['status'] == 'new').toList();

                  // 🚨 SLICE THE LIST IF TOGGLE IS OFF (Show max 3)
                  final displayedOpenCases = _showAllOpenCases ? openPoolCases : openPoolCases.take(3).toList();

                  final myAssignedCases = allCases.where((c) {
                    final status = c['status'];
                    final claimedById = c['claimed_by_id'];
                    return (status == 'assigned' || status == 'in_progress') && claimedById == currentUserId;
                  }).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // --- SECTION 1: OPEN POOL ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Open Pool", style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
                                Text("Available cases needing rescue", style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _textLight)),
                              ],
                            ),
                            // 🚨 THE NEW "SEE ALL" TOGGLE BUTTON
                            if (openPoolCases.length > 3)
                              GestureDetector(
                                onTap: () => setState(() => _showAllOpenCases = !_showAllOpenCases),
                                child: Text(
                                  _showAllOpenCases ? "Show less" : "See all (${openPoolCases.length})",
                                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: _primaryOrange),
                                ),
                              )
                            else
                              Text("${openPoolCases.length} available", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryOrange)),
                          ],
                        ),
                        const SizedBox(height: 15),

                        if (openPoolCases.isEmpty)
                          _buildEmptyState("No open cases right now.")
                        else
                        // 🚨 Use the 'displayedOpenCases' list here instead of the full list
                          ...displayedOpenCases.map((c) => _buildCaseCard(c, isOpenPool: true)),

                        const SizedBox(height: 35),

                        // --- SECTION 2: MY CASES ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("My Assigned Cases", style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: _textDark)),
                                Text("Cases you have committed to", style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _textLight)),
                              ],
                            ),
                            Text("${myAssignedCases.length} active", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _primaryGreen)),
                          ],
                        ),
                        const SizedBox(height: 15),

                        if (myAssignedCases.isEmpty)
                          _buildEmptyState("You haven't claimed any cases yet.")
                        else
                          ...myAssignedCases.map((c) => _buildCaseCard(c, isOpenPool: false)),
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
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Center(
        child: Text(message, style: GoogleFonts.nunito(color: _textLight, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildCaseCard(Map<String, dynamic> caseData, {required bool isOpenPool}) {
    final String id = caseData['id'] ?? '';
    final String shortId = "CASE-${id.length > 4 ? id.substring(0, 4).toUpperCase() : id}";
    final String animalType = caseData['animal_type'] ?? 'Unknown';
    final String severity = caseData['severity'] ?? 'moderate';
    final String timeAgo = _getTimeAgo(caseData['created_at']);

    // 🚨 Extracting the new details!
    final String locationText = caseData['location_text'] ?? 'Pinned on map (Coordinates available)';
    final String description = caseData['description'] ?? 'No additional details provided.';
    // If you want to use the coordinates later for map routing:
    // final double? lat = caseData['location_lat'];
    // final double? lng = caseData['location_lng'];

    Color severityColor = severity == 'emergency' ? _dangerRed : (severity == 'low' ? _primaryGreen : const Color(0xffd97706));

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
              Text("Reported $animalType", style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900, color: _textDark)),
              _buildBadge(severity.toUpperCase(), severityColor),
            ],
          ),
          const SizedBox(height: 4),
          Text("$shortId • Reported: $timeAgo", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _textLight)),
          const SizedBox(height: 15),

          // 🚨 NEW: LOCATION INDICATOR ROW
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locationText,
                  style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 🚨 NEW: DESCRIPTION/NOTES BOX
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Case Details", style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: _textDark)),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // BUTTONS

          if (isOpenPool)
          // BUTTONS
            if (!widget.isReadOnly) ...[ // 🚨 Only show buttons if NOT read-only
              if (isOpenPool)
                InkWell(
                  onTap: _isClaiming ? null : () => _showClaimConfirmationDialog(caseData),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: _primaryOrange, borderRadius: BorderRadius.circular(25)),
                    child: Center(
                      child: _isClaiming
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Claim Case", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                )
              else
                InkWell(
                  onTap: () => _showManageCaseDialog(caseData),
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: _primaryGreen, borderRadius: BorderRadius.circular(25)),
                    child: Center(
                      child: Text("Update Status", style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ),
            ] // 🚨 Close the read-only check
        ],
      ),
    );
  }

  // ==========================================
  // LOGIC: Update Assigned Case Details
  // ==========================================
  Future<void> _updateAssignedCase(String caseId, String currentDescription, String? newNote, String newSeverity) async {
    try {
      // 🚨 Append the new note if they typed one
      String finalDescription = currentDescription;
      if (newNote != null && newNote.trim().isNotEmpty) {
        finalDescription = '$currentDescription\n\n[Shelter Update]: ${newNote.trim()}';
      }

      await Supabase.instance.client.from('cases').update({
        'severity': newSeverity,
        'description': finalDescription,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', caseId);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating case: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==========================================
  // UI: Show Manage Case Dialog
  // ==========================================
  void _showManageCaseDialog(Map<String, dynamic> caseData) {
    final String id = caseData['id'] ?? '';
    final String currentDesc = caseData['description'] ?? '';
    String selectedSeverity = caseData['severity'] ?? 'moderate';

    final TextEditingController noteController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text("Manage Case", style: GoogleFonts.nunito(fontWeight: FontWeight.w900)),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. UPDATE SEVERITY
                          Text("Update Severity", style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildDialogSeverityOption("emergency", selectedSeverity, _dangerRed, () => setDialogState(() => selectedSeverity = 'emergency')),
                              const SizedBox(width: 8),
                              _buildDialogSeverityOption("moderate", selectedSeverity, const Color(0xffffc107), () => setDialogState(() => selectedSeverity = 'moderate')),
                              const SizedBox(width: 8),
                              _buildDialogSeverityOption("low", selectedSeverity, _primaryGreen, () => setDialogState(() => selectedSeverity = 'low')),
                            ],
                          ),
                          const SizedBox(height: 25),

                          // 2. ADD NOTE (APPEND-ONLY)
                          Text("Add Update Note", style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          Text("This will be added to the permanent case log.", style: GoogleFonts.nunito(fontSize: 10, color: Colors.grey.shade500)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300)
                            ),
                            child: TextField(
                              controller: noteController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "e.g., Animal stabilized, ready for clinic transport...",
                                  hintStyle: GoogleFonts.nunito(color: Colors.grey.shade400, fontSize: 13)
                              ),
                              style: GoogleFonts.nunito(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: GoogleFonts.nunito(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () {
                        setDialogState(() => isSubmitting = true);
                        _updateAssignedCase(id, currentDesc, noteController.text, selectedSeverity);
                      },
                      child: isSubmitting
                          ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Save Changes", style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              }
          );
        }
    );
  }

  // Small helper for the severity pills inside the dialog
  Widget _buildDialogSeverityOption(String level, String currentSelected, Color color, VoidCallback onTap) {
    bool isSelected = level == currentSelected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.transparent),
          ),
          child: Center(
            child: Text(
              level[0].toUpperCase() + level.substring(1),
              style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : color
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // LOGIC: Fetch Photos for Dialog
  // ==========================================
  Future<List<String>> _fetchCasePhotos(String caseId) async {
    try {
      final data = await Supabase.instance.client
          .from('case_photos')
          .select('bucket, path')
          .eq('case_id', caseId);

      List<String> urls = [];
      for (var row in data) {
        final bucket = row['bucket'];
        final path = row['path'];
        final url = Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
        urls.add(url);
      }
      return urls;
    } catch (e) {
      debugPrint("Error fetching photos: $e");
      return [];
    }
  }

  // ==========================================
  // UI: Show Claim Confirmation Dialog
  // ==========================================
  void _showClaimConfirmationDialog(Map<String, dynamic> caseData) {
    final String id = caseData['id'] ?? '';
    final String animalType = caseData['animal_type'] ?? 'Unknown';
    final String severity = caseData['severity'] ?? 'moderate';
    final String locationText = caseData['location_text'] ?? '';
    final double? lat = caseData['location_lat'];
    final double? lng = caseData['location_lng'];
    final String description = caseData['description'] ?? 'No description provided.';

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Review & Claim Case", style: GoogleFonts.nunito(fontWeight: FontWeight.w900, color: _textDark)),
              content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🚨 1. PHOTOS (Dynamic FutureBuilder)
                            FutureBuilder<List<String>>(
                                future: _fetchCasePhotos(id),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting) {
                                    return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
                                  }

                                  final photos = snapshot.data ?? [];

                                  if (photos.isEmpty) {
                                    return Container(
                                      height: 120, width: double.infinity,
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade400, size: 30),
                                          const SizedBox(height: 8),
                                          Text("No photos uploaded", style: GoogleFonts.nunito(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  }

                                  // Photo Carousel
                                  return SizedBox(
                                      height: 120,
                                      child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: photos.length,
                                          itemBuilder: (context, index) {
                                            return Container(
                                              width: 120,
                                              margin: const EdgeInsets.only(right: 10),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(15),
                                                image: DecorationImage(image: NetworkImage(photos[index]), fit: BoxFit.cover),
                                              ),
                                            );
                                          }
                                      )
                                  );
                                }
                            ),
                            const SizedBox(height: 20),

                            // 🚨 2. CASE DETAILS
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Animal: $animalType", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 15)),
                                _buildBadge(severity.toUpperCase(), severity == 'emergency' ? _dangerRed : (severity == 'low' ? _primaryGreen : const Color(0xffd97706))),
                              ],
                            ),
                            const SizedBox(height: 15),

                            // 🚨 3. LOCATION
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 16, color: Colors.redAccent),
                                const SizedBox(width: 6),
                                Text("Location Data", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(locationText.isEmpty ? "No address provided" : locationText, style: GoogleFonts.nunito(fontSize: 13, color: Colors.black87)),
                            if (lat != null && lng != null)
                              Text("Lat: $lat, Lng: $lng", style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),

                            // 🚨 4. DESCRIPTION
                            Row(
                              children: [
                                const Icon(Icons.description, size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 6),
                                Text("Description", style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                              child: Text(description, style: GoogleFonts.nunito(fontSize: 13, color: Colors.black87)),
                            ),
                          ]
                      )
                  )
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text("Cancel", style: GoogleFonts.nunito(color: Colors.grey.shade600, fontWeight: FontWeight.bold))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    _claimCase(id);     // Trigger the claim function!
                  },
                  child: Text("Confirm & Claim", style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ]
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