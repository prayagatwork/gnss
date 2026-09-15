import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gnss_session_controller.dart';

class StartPathDialog extends ConsumerStatefulWidget {
  const StartPathDialog({super.key});

  @override
  ConsumerState<StartPathDialog> createState() => _StartPathDialogState();
}

class _StartPathDialogState extends ConsumerState<StartPathDialog> {
  RecordMode _mode = RecordMode.distance;
  final TextEditingController _valueController =
      TextEditingController(text: "1.0");
  final TextEditingController _accuracyController =
      TextEditingController(text: "10.0");

  String _timeUnit = "Seconds";
  String _distUnit = "Meter(s)";
  bool _filterByAccuracy = true;

  @override
  void dispose() {
    _valueController.dispose();
    _accuracyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Start Path",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select how you want to add points to your path.",
                style: TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 10),

            // Mode Selection
            RadioListTile<RecordMode>(
              title: const Text("Time-based"),
              value: RecordMode.time,
              groupValue: _mode,
              activeColor: Colors.blue,
              onChanged: (v) => setState(() {
                _mode = v!;
              }),
            ),
            RadioListTile<RecordMode>(
              title: const Text("Distance-based"),
              value: RecordMode.distance,
              groupValue: _mode,
              activeColor: Colors.blue,
              onChanged: (v) => setState(() {
                _mode = v!;
              }),
            ),

            const SizedBox(height: 10),

            // Interval and Unit Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text("Every "),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _valueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _mode == RecordMode.time ? _timeUnit : _distUnit,
                      items: (_mode == RecordMode.time
                              ? ["Seconds", "Minutes", "Hours"]
                              : ["Meter(s)", "KM"])
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (v) {
                        setState(() {
                          if (_mode == RecordMode.time)
                            _timeUnit = v!;
                          else
                            _distUnit = v!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Accuracy Filter Checkbox
            CheckboxListTile(
              title: const Text("Valid GPS location only",
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text("Ignore points with low accuracy",
                  style: TextStyle(fontSize: 11)),
              value: _filterByAccuracy,
              activeColor: Colors.blue,
              onChanged: (v) => setState(() => _filterByAccuracy = v!),
              controlAffinity: ListTileControlAffinity.leading,
            ),

            // Required Accuracy Input (Matches your 10m vs 1m example)
            if (_filterByAccuracy)
              Padding(
                padding: const EdgeInsets.only(left: 50, right: 20),
                child: Row(
                  children: [
                    const Text("Required Accuracy: "),
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: _accuracyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            hintText: "1.0", isDense: true),
                      ),
                    ),
                    const Text(" m"),
                  ],
                ),
              ),
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
              backgroundColor: Colors.blue, foregroundColor: Colors.white),
          onPressed: () {
            // Convert units to base (Seconds or Meters)
            double val = double.tryParse(_valueController.text) ?? 1.0;
            if (_mode == RecordMode.time) {
              if (_timeUnit == "Minutes") val *= 60;
              if (_timeUnit == "Hours") val *= 3600;
            } else {
              if (_distUnit == "KM") val *= 1000;
            }

            double acc = double.tryParse(_accuracyController.text) ?? 10.0;

            // Trigger the Backend Controller
            ref
                .read(gnssSessionProvider.notifier)
                .startRecording(_mode, val, _filterByAccuracy, acc);

            Navigator.pop(context);
          },
          child: const Text("OK"),
        ),
      ],
    );
  }
}
