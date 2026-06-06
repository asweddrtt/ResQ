import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'lost_found_report_screen.dart';

class LostFoundScreen extends StatefulWidget {
  const LostFoundScreen({super.key});

  @override
  State<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends State<LostFoundScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];

  final MapController _mapController = MapController();
  final LatLng _defaultLocation = const LatLng(30.0074, 31.4913);

  // Active filter — matches animal_type or special keys
  String _activeFilter = 'All';
  final List<String> _filters = ['All', 'Dog', 'Cat', 'Bird', 'Lost', 'Found'];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  // Filter helper
  List<Map<String, dynamic>> get _filteredReports {
    if (_activeFilter == 'All') return _reports;
    if (_activeFilter == 'Lost') return _reports.where((r) => r['type'] == 'lost').toList();
    if (_activeFilter == 'Found') return _reports.where((r) => r['type'] == 'found').toList();
    return _reports.where((r) => (r['animal_type'] ?? '').toString().toLowerCase() == _activeFilter.toLowerCase()).toList();
  }

  Future<void> _fetchReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // Pull data from left join or two queries.
      // Since lost_found_reports is empty initially, we focus on safe querying.
      final response = await supabase
          .from('lost_found_reports')
          .select('*, lost_found_photos(bucket, path)')
          .order('created_at', ascending: false);

      setState(() {
        _reports = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching lost and found records: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load reports")),
        );
      }
    }
  }

  String _timeAgo(String isoString) {
    DateTime time = DateTime.parse(isoString);
    Duration diff = DateTime.now().difference(time);
    if (diff.inDays > 1) {
      return "Seen ${diff.inDays} days ago";
    } else if (diff.inDays == 1) {
      return "Seen yesterday";
    } else if (diff.inHours >= 1) {
      return "Seen ${diff.inHours}h ago";
    } else if (diff.inMinutes >= 1) {
      return "Seen ${diff.inMinutes}m ago";
    } else {
      return "Seen just now";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // SCROLLABLE CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // 1. APP BAR HEADER
                    // ==========================================
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xffffa94d),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.search, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Lost & Found",
                                style: GoogleFonts.nunito(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                "Help bring missing pets back home",
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Notification Bell (simple - no fake count)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                          ),
                          child: const Icon(Icons.notifications_none_outlined, color: Colors.black54, size: 20),
                        ),
                        const SizedBox(width: 10),
                        // Profile Avatar
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xff5bb381),
                          child: Icon(Icons.person, color: Colors.white, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ==========================================
                    // 2. SEARCH BAR & NEAR ME
                    // ==========================================
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5),
                              ],
                            ),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Search lost pets by name, breed, or area",
                                hintStyle: GoogleFonts.nunito(color: Colors.grey[400], fontSize: 13),
                                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Near Me Button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xffffa94d),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(color: const Color(0xffffa94d).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.my_location_outlined, color: Colors.black87, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                "Near me",
                                style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ==========================================
                    // 3. MAP PREVIEW
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Map preview", style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        Text("Lost & found pins near you", style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _defaultLocation,
                              initialZoom: 13.0,
                              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.yourcompany.resq',
                              ),
                              MarkerLayer(
                                markers: _reports
                                    .where((r) => r['location_lat'] != null && r['location_lng'] != null)
                                    .map((r) {
                                  final isLost = r['type'] == 'lost';
                                  return Marker(
                                    point: LatLng(
                                      (r['location_lat'] as num).toDouble(),
                                      (r['location_lng'] as num).toDouble(),
                                    ),
                                    width: 28, height: 28,
                                    child: Icon(
                                      Icons.location_on,
                                      color: isLost ? Colors.red : const Color(0xff5bb381),
                                      size: 28,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          // "Open Map" Overlay Button
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xff2d3436), // Dark slate
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.open_in_full, color: Colors.white, size: 14),
                                  const SizedBox(width: 5),
                                  Text("Open map", style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Map Legend
                    Row(
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text("Lost", style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(width: 15),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xff5bb381), shape: BoxShape.circle)),
                            const SizedBox(width: 5),
                            Text("Found", style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ==========================================
                    // 4. FILTER CHIPS
                    // ==========================================
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _filters.map((filter) {
                          bool isActive = _activeFilter == filter;
                          return GestureDetector(
                            onTap: () => setState(() => _activeFilter = filter),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xffffa94d) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isActive ? const Color(0xffffa94d) : Colors.grey.shade300),
                              ),
                              child: Text(
                                filter,
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.black87 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 25),

                    // ==========================================
                    // 5. RECENTLY REPORTED LIST
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Recently reported",
                          style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                        Text(
                          '${_filteredReports.length} reports',
                          style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // List display logic
                    if (_isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (_filteredReports.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Text(
                            "Nothing to show here for now.\nNo lost or found pets reported yet.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _filteredReports.length,
                        itemBuilder: (context, index) {
                          final report = _filteredReports[index];
                          
                          // Handle missing fields (since DB schema only has limited columns, we use fallbacks)
                          final animalType = report['animal_type'] ?? "Unknown Animal";
                          final desc = report['description'] ?? "No details provided";
                          final locationStr = report['location_text'] ?? "Unknown Area";
                          
                          // Time logic
                          final timeString = _timeAgo(report['created_at']);

                          // Fetch primary image URL if any
                          String? imageUrl;
                          if (report['lost_found_photos'] != null && report['lost_found_photos'] is List && report['lost_found_photos'].isNotEmpty) {
                            var photo = report['lost_found_photos'][0];
                            imageUrl = Supabase.instance.client.storage.from(photo['bucket']).getPublicUrl(photo['path']);
                          }

                          // Badging logic based on "type"
                          final isLost = report['type'] == 'lost';
                          final badgeLabel = isLost ? "Lost" : "Found";
                          final badgeColor = isLost ? Colors.red.withOpacity(0.8) : const Color(0xff5bb381).withOpacity(0.8);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Pet Image Area
                                      Container(
                                        height: 90,
                                        width: 90,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(15),
                                          image: imageUrl != null
                                              ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: imageUrl == null
                                            ? const Icon(Icons.pets, color: Colors.grey, size: 40)
                                            : null,
                                      ),
                                      const SizedBox(width: 15),
                                      // Pet Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    animalType, // No name in DB, using type
                                                    style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w900),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xffffa94d),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(isLost ? Icons.search : Icons.check_circle_outline, size: 12, color: Colors.black87),
                                                      const SizedBox(width: 4),
                                                      Text(badgeLabel, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              desc,
                                              style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                                      const SizedBox(width: 4),
                                                      Expanded(child: Text(locationStr, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                                    ],
                                                  ),
                                                ),
                                                Text(timeString, style: GoogleFonts.nunito(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Action Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _buildCardAction(Icons.phone_outlined, "Contact owner"),
                                      const SizedBox(width: 10),
                                      _buildCardAction(Icons.info_outline, "Details"),
                                      const SizedBox(width: 10),
                                      _buildCardAction(Icons.share_outlined, "Share"),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ==========================================
            // 6. BOTTOM FLOATING ACTION ROW
            // ==========================================
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: BoxDecoration(
                color: const Color(0xffF8F9FA),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  )
                ]
              ),
              child: GestureDetector(
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LostFoundReportScreen()),
                  );
                  if (result == true) _fetchReports();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xff5bb381), // Match the green button from sketch
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff5bb381).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Report lost / found pet",
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAction(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.black54),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
        ],
      ),
    );
  }
}
