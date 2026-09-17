import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../data/sources/windows_com_source.dart';
import '../domain/models/source_config.dart';
import 'gnss_session_controller.dart';
import 'responsive.dart';

class SourceSelectionDialog extends ConsumerStatefulWidget {
  const SourceSelectionDialog({super.key});

  @override
  ConsumerState<SourceSelectionDialog> createState() =>
      _SourceSelectionDialogState();
}

class _SourceSelectionDialogState extends ConsumerState<SourceSelectionDialog> {
  SourceType _selectedType = SourceType.simulation;
  int _baudRate = 9600;
  late List<Map<String, String?>> _ports;
  String? _selectedPort;

  @override
  void initState() {
    super.initState();
    _refreshPorts();
  }

  void _refreshPorts() {
    _ports = WindowsComSource.listPorts();
    _selectedPort = _ports.isEmpty ? null : _ports.first['name'];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.satellite_alt, color: Colors.blue),
          SizedBox(width: 12),
          Text("Select GNSS Device",
              style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        // Use responsive width for different screen sizes
        width: Responsive.relativeWidth(context, 0.45, min: 320, max: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Choose your data source:",
                style: TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 16),

            // Modern Segmented Button selection
            Center(
              child: SegmentedButton<SourceType>(
                segments: const [
                  ButtonSegment(
                    value: SourceType.simulation,
                    label: Text('Simulation'),
                    icon: Icon(Icons.play_circle_outline),
                  ),
                  ButtonSegment(
                    value: SourceType.windowsCom,
                    label: Text('External'),
                    icon: Icon(Icons.usb),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<SourceType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            // Conditional view based on selection
            if (_selectedType == SourceType.simulation) ...[
              const _SourceInfoBox(
                icon: Icons.info_outline,
                text:
                    "Select a .nmea or .txt log file from your computer to simulate a live GNSS feed.",
              ),
            ] else ...[
              Row(
                children: [
                  const Expanded(
                    child: Text("COM Port",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(_refreshPorts),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Refresh"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedPort,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                hint: const Text("No COM ports found"),
                items: _ports.map((port) {
                  final name = port['name'] ?? '';
                  final description = port['description'];
                  return DropdownMenuItem<String>(
                    value: name,
                    child: Text(description == null || description.isEmpty
                        ? name
                        : "$name - $description"),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedPort = v),
              ),
              const SizedBox(height: 12),
              const Text("Baud Rate",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: _baudRate,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                items: [4800, 9600, 38400, 115200].map((int val) {
                  return DropdownMenuItem<int>(
                    value: val,
                    child: Text("$val bps"),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _baudRate = v!),
              ),
              const SizedBox(height: 12),
              const _SourceInfoBox(
                icon: Icons.warning_amber_rounded,
                text:
                    "Pair the HC-05 in Windows first, then select its outgoing virtual COM port. Default serial configuration is 9600 baud, 8-N-1.",
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () async {
            if (_selectedType == SourceType.simulation) {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['nmea', 'txt', 'log'],
                withData: true,
              );

              if (result != null && result.files.first.bytes != null) {
                if (!mounted) return;

                ref
                    .read(gnssSessionProvider.notifier)
                    .startWebSimulation(result.files.first.bytes!);

                if (context.mounted) Navigator.pop(context);
              }
            } else {
              if (_selectedPort == null || _selectedPort!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No COM port selected.")),
                );
                return;
              }
              ref.read(gnssSessionProvider.notifier).connect(
                    SourceConfig(
                      type: SourceType.windowsCom,
                      comPortName: _selectedPort,
                      baudRate: _baudRate,
                    ),
                  );
              Navigator.pop(context);
            }
          },
          child: Text(_selectedType == SourceType.simulation
              ? "Select File"
              : "Connect"),
        ),
      ],
    );
  }
}

/// Helper widget for the info boxes inside the dialog
class _SourceInfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SourceInfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
