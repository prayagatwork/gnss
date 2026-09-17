import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/path_point.dart';
import 'gnss_session_controller.dart';

class PathSummaryScreen extends ConsumerStatefulWidget {
  final List<PathPoint> points;
  final double totalDistanceMeters;

  const PathSummaryScreen({
    super.key,
    required this.points,
    required this.totalDistanceMeters,
  });

  @override
  ConsumerState<PathSummaryScreen> createState() => _PathSummaryScreenState();
}

class _PathSummaryScreenState extends ConsumerState<PathSummaryScreen> {
  final _nameController = TextEditingController(text: 'DIST 01');
  bool _closePolygon = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final first = points.isEmpty ? null : points.first.timestamp;
    final maxAltitude = points.isEmpty
        ? null
        : points.map((point) => point.altitude).reduce(
              (a, b) => a > b ? a : b,
            );

    return Scaffold(
      appBar: AppBar(title: const Text('Finish Path')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Path Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _statRow('Start Time:', _formatDateTime(first)),
                  _statRow(
                    'Distance:',
                    '${widget.totalDistanceMeters.toStringAsFixed(2)} m',
                  ),
                  _statRow(
                    'Max Altitude:',
                    maxAltitude == null
                        ? '--'
                        : '${maxAltitude.toStringAsFixed(2)} m',
                  ),
                  CheckboxListTile(
                    title: const Text('Enclose the lines to form a polygon'),
                    value: _closePolygon,
                    onChanged: (value) =>
                        setState(() => _closePolygon = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
            const Divider(),
            const Text(
              'Select Point(s)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: points.isEmpty
                  ? const Center(child: Text('No path points recorded.'))
                  : ListView.builder(
                      itemCount:
                          _closePolygon ? points.length + 1 : points.length,
                      itemBuilder: (context, index) {
                        final point = index == points.length
                            ? points.first
                            : points[index];
                        final label = index == points.length
                            ? '${index + 1}. Close polygon'
                            : '${index + 1}. ${_formatClock(point.timestamp)}';
                        return ListTile(
                          leading: const Checkbox(value: true, onChanged: null),
                          title: Text(label),
                          subtitle: Text(
                            '${point.latitude.toStringAsFixed(6)}, '
                            '${point.longitude.toStringAsFixed(6)} | '
                            '${point.altitude.toStringAsFixed(2)} m',
                          ),
                          dense: true,
                        );
                      },
                    ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref.read(gnssSessionProvider.notifier).clearLog();
                        if (!context.mounted) return;
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: points.isEmpty
                          ? null
                          : () async {
                              final path = await ref
                                  .read(gnssSessionProvider.notifier)
                                  .saveLog();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(path == null
                                      ? 'No recorded path to save.'
                                      : 'Saved to $path'),
                                ),
                              );
                              Navigator.pop(context);
                            },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(label),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '--';
    final local = dt.toLocal();
    String p(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${p(local.month)}-${p(local.day)} '
        '${p(local.hour)}:${p(local.minute)}:${p(local.second)}';
  }

  String _formatClock(DateTime dt) {
    final local = dt.toLocal();
    String p(int value) => value.toString().padLeft(2, '0');
    return '${p(local.hour)}:${p(local.minute)}:${p(local.second)}';
  }
}
