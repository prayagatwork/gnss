import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surface,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 760;
            return SingleChildScrollView(
              padding: Responsive.screenPadding(context),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Grid metrics (8 cards)
                    Wrap(
                      spacing: Responsive.elementSpacing(context),
                      runSpacing: Responsive.elementSpacing(context),
                      children: [
                        _MetricCard('Latitude', _formatCoord(fix?.latitudeDeg)),
                        _MetricCard(
                            'Longitude', _formatCoord(fix?.longitudeDeg)),
                        _MetricCard('Altitude (MSL)',
                            _formatNumber(fix?.altitudeM, suffix: ' m')),
                        _BearingCard(fix?.headingDeg),
                        _MetricCard('Speed',
                            _formatNumber(fix?.speedKmh, suffix: ' km/h')),
                        _MetricCard(
                          'Accuracy',
                          fix?.hdop == null
                              ? '--'
                              : 'HDOP ${fix!.hdop!.toStringAsFixed(1)}',
                        ),
                        _MetricCard(
                          'Last Update',
                          fix == null ? '--' : _formatTime(fix.receivedAtUtc),
                        ),
                        _MetricCard(
                          'Path',
                          '${(session.totalDistance / 1000).toStringAsFixed(3)} km',
                        ),
                      ],
                    ),

                    SizedBox(height: Responsive.elementSpacing(context)),

                    // 2. Map Panel
                    SizedBox(
                      height: compactHeight
                          ? Responsive.relativeHeight(context, 0.35,
                              min: 250, max: 350)
                          : Responsive.relativeHeight(context, 0.45,
                              min: 300, max: 500),
                      child: _MapPanel(session: session),
                    ),

                    const SizedBox(height: 10),
                    _StatusLine(session: session),
                    const SizedBox(height: 12),

                    // 3. Action Buttons
                    _ActionBar(session: session),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- Helper Methods ---

  String _formatCoord(double? value) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(6)}°';
  }

  String _formatNumber(double? value, {required String suffix}) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(1)}$suffix';
  }

  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    String p(int value) => value.toString().padLeft(2, '0');
    return '${p(local.hour)}:${p(local.minute)}:${p(local.second)}';
  }
}

class _MapPanel extends StatelessWidget {
  final GnssSessionState session;
  const _MapPanel({required this.session});

  @override
  Widget build(BuildContext context) {
    final fix = session.currentFix;
    final hasLocation = fix?.latitudeDeg != null && fix?.longitudeDeg != null;
    final center = hasLocation
        ? LatLng(fix!.latitudeDeg!, fix.longitudeDeg!)
        : const LatLng(28.6139, 77.2090);
    final path = session.pathPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.skytrack.gnss',
                ),
                if (path.length > 1)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: path,
                        strokeWidth: 4,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                if (hasLocation)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 40),
                      ),
                    ],
                  ),
              ],
            ),
            if (!hasLocation)
              const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Searching for GNSS Signal..."),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final GnssSessionState session;
  const _StatusLine({required this.session});

  @override
  Widget build(BuildContext context) {
    return Text(
      "12 GPS, 8 GLONASS, 3 Other, 0 SBAS",
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    );
  }
}

class _ActionBar extends ConsumerWidget {
  final GnssSessionState session;
  const _ActionBar({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 16,
      runSpacing: 14,
      children: [
        _BigActionButton(
          icon: Icons.add_location,
          label: 'Add Waypoint',
          color: Colors.blue.shade800,
          onTap: () {
            final added = ref.read(gnssSessionProvider.notifier).addWaypoint();
            if (!added) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No valid location to add.')),
              );
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Waypoint recorded.')),
            );
          },
        ),
        _BigActionButton(
          icon: session.isRecording
              ? (session.isPaused ? Icons.play_arrow : Icons.pause)
              : Icons.play_arrow,
          label: session.isRecording
              ? (session.isPaused ? 'Resume' : 'Pause')
              : 'Start Path',
          color: session.isRecording ? Colors.orange : Colors.green.shade700,
          onTap: () {
            if (!session.isRecording) {
              showDialog(
                  context: context, builder: (_) => const StartPathDialog());
            } else {
              ref.read(gnssSessionProvider.notifier).togglePause();
            }
          },
        ),
        _BigActionButton(
          icon: session.isRecording ? Icons.stop : Icons.share,
          label: session.isRecording ? 'Finish Path' : 'Share Location',
          color:
              session.isRecording ? Colors.red.shade700 : Colors.grey.shade700,
          onTap: () {
            if (session.isRecording) {
              ref.read(gnssSessionProvider.notifier).stopRecording();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PathSummaryScreen(
                          points: session.pathPoints,
                          totalDistanceMeters: session.totalDistance)));
            } else {
              final fix = session.currentFix;
              if (fix?.latitudeDeg != null) {
                Clipboard.setData(ClipboardData(
                    text: "${fix!.latitudeDeg}, ${fix.longitudeDeg}"));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Location copied.")));
              }
            }
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  const _MetricCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 60) /
        Responsive.dashboardColumns(context);
    return SizedBox(
      width: width.clamp(142, 280),
      height: 86,
      child: Card(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BearingCard extends StatelessWidget {
  final double? heading;
  const _BearingCard(this.heading);

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 60) /
        Responsive.dashboardColumns(context);
    return SizedBox(
      width: width.clamp(142, 280),
      height: 86,
      child: Card(
        elevation: 1,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: (heading ?? 0) * math.pi / 180,
              child: const Icon(Icons.navigation, color: Colors.blue, size: 28),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Bearing",
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text("${heading?.toStringAsFixed(1) ?? '--'}°",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BigActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            CircleAvatar(
                radius: 30,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 30)),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
