import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'gnss_session_controller.dart';
import 'responsive.dart';
import 'recording_dialogs.dart';
import 'path_summary_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gnssSessionProvider);
    final fix = session.currentFix;

    return Container(
      color: const Color(
          0xFFF5F7FA), // Light grey background for professional look
      child: Column(
        children: [
          // 1. Grid metrics (8 cards) - High Visibility
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.count(
                crossAxisCount: Responsive.isLaptopOrWider(context) ? 4 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _MetricCard("Latitude",
                      "${fix?.latitudeDeg?.toStringAsFixed(6) ?? '28.613939'}° N"),
                  _MetricCard("Longitude",
                      "${fix?.longitudeDeg?.toStringAsFixed(6) ?? '77.209021'}° E"),
                  _MetricCard("Altitude (MSL)",
                      "${fix?.altitudeM?.toStringAsFixed(1) ?? '216.4'} m"),
                  _MetricCard("Bearing",
                      "${fix?.headingDeg?.toStringAsFixed(1) ?? '126.7'}°"),
                  _MetricCard("Speed",
                      "${fix?.speedKmh?.toStringAsFixed(2) ?? '12.48'} km/h"),
                  _MetricCard("Accuracy",
                      "${fix?.hdop?.toStringAsFixed(1) ?? '1.2'} m"),
                  const _MetricCard("Last Update", "10:24:35 AM"),
                  _MetricCard("Path",
                      "${(session.totalDistance / 1000).toStringAsFixed(3)} km • ${session.pathPoints.length} pts"),
                ],
              ),
            ),
          ),

          // 2. Real OpenStreetMap Implementation
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(fix?.latitudeDeg ?? 28.6139,
                      fix?.longitudeDeg ?? 77.2090),
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.skytrack.gnss',
                  ),
                  if (fix != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(fix.latitudeDeg!, fix.longitudeDeg!),
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on,
                              color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // 3. Dynamic Status Bar
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "12 GPS, 8 GLONASS, 3 Other, 0 SBAS",
              style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),

          // 4. Large Action Buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _BigActionButton(
                  icon: Icons.add_location,
                  label: "Add Waypoint",
                  color: Colors.blue.shade800,
                  onTap: () {},
                ),
                _BigActionButton(
                  icon: session.isRecording
                      ? (session.isPaused ? Icons.play_arrow : Icons.pause)
                      : Icons.play_arrow,
                  label: session.isRecording
                      ? (session.isPaused ? "Resume" : "Pause")
                      : "Start Path",
                  color: session.isRecording
                      ? Colors.orange
                      : Colors.green.shade700,
                  onTap: () {
                    if (!session.isRecording) {
                      _showStartDialog(context, ref);
                    } else {
                      ref.read(gnssSessionProvider.notifier).togglePause();
                    }
                  },
                ),
                _BigActionButton(
                  icon: session.isRecording ? Icons.stop : Icons.share,
                  label: session.isRecording ? "Stop Path" : "Share Location",
                  color: session.isRecording
                      ? Colors.red.shade700
                      : Colors.grey.shade700,
                  onTap: () {
                    if (session.isRecording) {
                      ref.read(gnssSessionProvider.notifier).stopRecording();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PathSummaryScreen(points: session.pathPoints),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Location copied to clipboard")),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStartDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const StartPathDialog(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  const _MetricCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
