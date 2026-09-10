import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../data/sources/windows_com_source.dart';
import '../domain/models/source_config.dart';
import 'gnss_session_controller.dart';
import 'responsive.dart';

/// "On the top right we need only 1 option more select GNSS device and then
/// we can select and make it working" — this is that flow, shown as a
/// dialog opened from the top-right AppBar action in main.dart, matching
/// spec 8.2 (Source Selection tab) for the exe scope: Windows COM +
/// Simulation only (Android BLE/SPP/internal is .apk scope).
class SourceSelectionDialog extends ConsumerStatefulWidget {
  const SourceSelectionDialog({super.key});

  @override
  ConsumerState<SourceSelectionDialog> createState() => _SourceSelectionDialogState();
}

class _SourceSelectionDialogState extends ConsumerState<SourceSelectionDialog> {
  SourceType _selectedType = SourceType.windowsCom;
  String? _selectedComPort;
  int _baudRate = 9600;
  String? _simulationFilePath;
  double _playbackSpeed = 1.0;
  List<Map<String, String?>> _ports = [];

  @override
  void initState() {
    super.initState();
    _refreshPorts();
  }

  void _refreshPorts() {
    setState(() {
      _ports = WindowsComSource.listPorts();
      if (_ports.isNotEmpty) _selectedComPort ??= _ports.first['name'];
    });
  }

  Future<void> _pickSimulationFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'log', 'nmea', 'csv'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _simulationFilePath = result.files.single.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select GNSS device'),
      content: SizedBox(
        width: Responsive.relativeWidth(context, 0.5, min: 320, max: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<SourceType>(
              segments: const [
                ButtonSegment(
                  value: SourceType.windowsCom,
                  label: Text('External receiver'),
                  icon: Icon(Icons.usb),
                ),
                ButtonSegment(
                  value: SourceType.simulation,
                  label: Text('Simulation file'),
                  icon: Icon(Icons.play_circle_outline),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (s) => setState(() => _selectedType = s.first),
            ),
            const SizedBox(height: 16),
            if (_selectedType == SourceType.windowsCom) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedComPort,
                      decoration: const InputDecoration(labelText: 'COM port'),
                      items: _ports
                          .map((p) => DropdownMenuItem(
                                value: p['name'],
                                child: Text(
                                  '${p['name']}${p['description'] != null ? ' — ${p['description']}' : ''}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedComPort = v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Rescan ports',
                    onPressed: _refreshPorts,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _baudRate,
                decoration: const InputDecoration(labelText: 'Baud rate'),
                items: SourceConfig.supportedBaudRates
                    .map((b) => DropdownMenuItem(value: b, child: Text('$b')))
                    .toList(),
                onChanged: (v) => setState(() => _baudRate = v ?? 9600),
              ),
              const SizedBox(height: 4),
              const Text(
                '8 data bits · no parity · 1 stop bit (HC-05 default, slave mode)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: _pickSimulationFile,
                icon: const Icon(Icons.folder_open),
                label: Text(_simulationFilePath == null
                    ? 'Choose sample file (.txt/.nmea/.csv)'
                    : _simulationFilePath!.split(Platform.pathSeparator).last),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                initialValue: _playbackSpeed,
                decoration: const InputDecoration(labelText: 'Playback speed'),
                items: SourceConfig.supportedPlaybackSpeeds
                    .map((s) => DropdownMenuItem(value: s, child: Text('${s}x')))
                    .toList(),
                onChanged: (v) => setState(() => _playbackSpeed = v ?? 1.0),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final config = _selectedType == SourceType.windowsCom
                ? SourceConfig(
                    type: SourceType.windowsCom,
                    comPortName: _selectedComPort,
                    baudRate: _baudRate,
                  )
                : SourceConfig(
                    type: SourceType.simulation,
                    simulationFilePath: _simulationFilePath,
                    playbackSpeed: _playbackSpeed,
                  );
            Navigator.pop(context);
            ref.read(gnssSessionProvider.notifier).connect(config);
          },
          child: const Text('Connect'),
        ),
      ],
    );
  }
}
