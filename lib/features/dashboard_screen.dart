import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/gnss_fix.dart';
import '../domain/gnss_source.dart';
import 'gnss_session_controller.dart';
import 'responsive.dart';

/// Dashboard tab per spec 8.1, adjusted for the exe-only scope in the
/// client notes: "In exe dashboard map and merge data and 3 dots for
/// selecting" — skyplot/satellite view and Statistics are APK-only.
///
/// Map: OpenStreetMap tiles for the exe build (client notes: "we can use
/// openstreet map in exe"; Google Maps + subscription is APK-only).
/// A live north-pointing bearing indicator is shown per client notes.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

enum PathRecordingState { idle, recording, paused, finished }

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  PathRecordingState _pathState = PathRecordingState.idle;
  bool _enclosePolygon = false; // optional: join start+end point

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gnssSessionProvider);
    final fix = session.currentFix;
    final columns = Responsive.dashboardColumns(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = Responsive.isLaptopOrWider(context);
        return Padding(
          padding: EdgeInsets.all(Responsive.relativeWidth(context, 0.02, min: 8, max: 24)),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildMapArea(context, fix)),
                    SizedBox(width: Responsive.relativeWidth(context, 0.02, min: 8, max: 24)),
                    Expanded(
                      flex: 2,
                      child: _buildMetricsColumn(context, session, fix, columns),
                    ),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(
                      height: Responsive.relativeHeight(context, 0.4, min: 200, max: 500),
                      child: _buildMapArea(context, fix),
                    ),
                    const SizedBox(height: 12),
                    Expanded(child: _buildMetricsColumn(context, session, fix, columns)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMapArea(BuildContext context, GnssFix? fix) {
    // Placeholder for the OpenStreetMap widget (flutter_map + osm tiles).
    // Wired up in a later phase once the map package is pinned; kept as a
    // clearly-labeled placeholder so layout/UX can be reviewed now.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Text('OpenStreetMap view\n(flutter_map + OSM tiles)',
                  textAlign: TextAlign.center),
            ),
          ),
          Positioned(top: 12, right: 12, child: _NorthPointer(headingDeg: fix?.headingDeg)),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: _PathControls(
              state: _pathState,
              enclosePolygon: _enclosePolygon,
              onStart: () => setState(() => _pathState = PathRecordingState.recording),
              onPause: () => setState(() => _pathState = PathRecordingState.paused),
              onResume: () => setState(() => _pathState = PathRecordingState.recording),
              onFinish: () => setState(() => _pathState = PathRecordingState.finished),
              onEncloseChanged: (v) => setState(() => _enclosePolygon = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsColumn(
    BuildContext context,
    GnssSessionState session,
    GnssFix? fix,
    int columns,
  ) {
    final statusColor = _statusColor(context, session.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 12, color: statusColor),
            const SizedBox(width: 6),
            Text(_statusLabel(session.status),
                style: Theme.of(context).textTheme.titleMedium),
            if (session.isStale) ...[
              const SizedBox(width: 8),
              const Chip(label: Text('Stale')),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.count(
            crossAxisCount: columns,
            childAspectRatio: 1.6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _MetricCard('Latitude', _fmt(fix?.latitudeDeg, 6)),
              _MetricCard('Longitude', _fmt(fix?.longitudeDeg, 6)),
              _MetricCard('Altitude (MSL)', _fmt(fix?.altitudeM, 1, unit: 'm')),
              _MetricCard('Speed', _fmt(fix?.speedKmh, 2, unit: 'km/h')),
              _MetricCard('Heading', _fmt(fix?.headingDeg, 1, unit: '°')),
              _MetricCard('Fix', fix?.fixQuality ?? '—'),
              _MetricCard('Sats used', fix?.satellitesUsed?.toString() ?? '—'),
              _MetricCard('HDOP', _fmt(fix?.hdop, 1)),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(double? v, int decimals, {String? unit}) {
    if (v == null) return '—'; // spec: no-data shows dash, not zero
    final s = v.toStringAsFixed(decimals);
    return unit == null ? s : '$s $unit';
  }

  String _statusLabel(SourceStatus s) => switch (s) {
        SourceStatus.idle => 'Idle',
        SourceStatus.scanning => 'Scanning',
        SourceStatus.connecting => 'Connecting',
        SourceStatus.connected => 'Connected',
        SourceStatus.receiving => 'Receiving',
        SourceStatus.reconnecting => 'Reconnecting',
        SourceStatus.disconnected => 'Disconnected',
        SourceStatus.error => 'Error',
      };

  Color _statusColor(BuildContext context, SourceStatus s) => switch (s) {
        SourceStatus.receiving || SourceStatus.connected => Colors.green,
        SourceStatus.connecting || SourceStatus.scanning || SourceStatus.reconnecting =>
          Colors.orange,
        SourceStatus.error => Colors.red,
        _ => Colors.grey,
      };
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live bearing/north pointer per client notes.
class _NorthPointer extends StatelessWidget {
  final double? headingDeg;
  const _NorthPointer({this.headingDeg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: Transform.rotate(
        angle: -((headingDeg ?? 0) * 3.1415926535 / 180),
        child: Icon(Icons.navigation, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// Start / Pause / Resume / Finish path controls (client notes) plus the
/// optional "enclose in polygon" toggle that joins start and end points.
class _PathControls extends StatelessWidget {
  final PathRecordingState state;
  final bool enclosePolygon;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final ValueChanged<bool> onEncloseChanged;

  const _PathControls({
    required this.state,
    required this.enclosePolygon,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onEncloseChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            if (state == PathRecordingState.idle || state == PathRecordingState.finished)
              FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            if (state == PathRecordingState.recording) ...[
              OutlinedButton.icon(
                onPressed: onPause,
                icon: const Icon(Icons.pause),
                label: const Text('Pause'),
              ),
              OutlinedButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.stop),
                label: const Text('Finish path'),
              ),
            ],
            if (state == PathRecordingState.paused) ...[
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
              ),
              OutlinedButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.stop),
                label: const Text('Finish path'),
              ),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(value: enclosePolygon, onChanged: (v) => onEncloseChanged(v ?? false)),
                const Text('Enclose in polygon (optional)'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
