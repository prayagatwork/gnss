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
                          '${(session.totalDistance / 1000).toStringAsFixed(3)} km | '
                              '${session.pathPoints.length} pts',
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.elementSpacing(context)),
                    SizedBox(
                      height: compactHeight
                          ? Responsive.relativeHeight(context, 0.32,
                              min: 220, max: 320)
                          : Responsive.relativeHeight(context, 0.42,
                              min: 260, max: 460),
                      child: _MapPanel(session: session),
                    ),
                    const SizedBox(height: 10),
                    _StatusLine(session: session),
                    const SizedBox(height: 12),
                    _ActionBar(session: session),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatCoord(double? value) {
    if (value == null) return '--';
    return '${value.toStringAsFixed(6)} deg';
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
              key: ValueKey('${center.latitude},${center.longitude}'),
              options: MapOptions(initialCenter: center, initialZoom: 16),
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
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.location_on,
                          color: Theme.of(context).colorScheme.error,
                          size: 42,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (!hasLocation)
              Positioned(
                left: 12,
                top: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text('Waiting for valid GNSS location'),
                  ),
                ),
              ),
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
    final fix = session.currentFix;
    final parts = [
      'Status: ${session.status.name}',
      'Used: ${fix?.satellitesUsed ?? 0}',
      'In view: ${fix?.satellitesInView ?? 0}',
      'Quality: ${fix?.fixQuality ?? 'no_fix'}',
    ];
    final message = session.statusMessage;

    return Text(
      message == null || message.isEmpty ? parts.join(' | ') : message,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
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
                const SnackBar(content: Text('No valid point to add yet.')),
              );
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Waypoint added to current path.')),
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
                context: context,
                builder: (context) => const StartPathDialog(),
              );
              return;
            }
            ref.read(gnssSessionProvider.notifier).togglePause();
          },
        ),
        _BigActionButton(
          icon: session.isRecording ? Icons.stop : Icons.share,
          label: session.isRecording ? 'Finish Path' : 'Share Location',
          color:
              session.isRecording ? Colors.red.shade700 : Colors.grey.shade700,
          onTap: () async {
            if (session.isRecording) {
              ref.read(gnssSessionProvider.notifier).stopRecording();
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PathSummaryScreen(
                    points: session.pathPoints,
                    totalDistanceMeters: session.totalDistance,
                  ),
                ),
              );
              return;
            }

            final fix = session.currentFix;
            if (fix?.latitudeDeg == null || fix?.longitudeDeg == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No valid location to share.')),
              );
              return;
            }
            final text =
                '${fix!.latitudeDeg!.toStringAsFixed(6)}, ${fix.longitudeDeg!.toStringAsFixed(6)}';
            await Clipboard.setData(ClipboardData(text: text));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Location copied: $text')),
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width -
            Responsive.screenPadding(context).horizontal -
            Responsive.elementSpacing(context) * 3) /
        Responsive.dashboardColumns(context);
    return SizedBox(
      width: width.clamp(142, 280),
      height: 86,
      child: Card(
        elevation: 1,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
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
    final width = (MediaQuery.of(context).size.width -
            Responsive.screenPadding(context).horizontal -
            Responsive.elementSpacing(context) * 3) /
        Responsive.dashboardColumns(context);

    return SizedBox(
      width: width.clamp(142, 280),
      height: 86,
      child: Card(
        elevation: 1,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Transform.rotate(
                angle: (heading ?? 0) * math.pi / 180,
                child: Icon(
                  Icons.navigation,
                  color: Theme.of(context).colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bearing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        heading == null
                            ? '--'
                            : '${heading!.toStringAsFixed(1)} deg',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
