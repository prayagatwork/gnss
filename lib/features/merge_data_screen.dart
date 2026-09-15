import 'package:flutter/material.dart'; // Add this line!

class MergeDataScreen extends StatelessWidget {
  const MergeDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _mergeStep("1. Browse GNSS TXT File", "No file selected"),
        _mergeStep("2. Browse FROG File", "No file selected"),
        const SizedBox(height: 20),
        const Text(
          "3. Select parameters to merge",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        _mergeCheck("Timestamp"),
        _mergeCheck("Latitude"),
        _mergeCheck("Longitude"),
        _mergeCheck("Altitude"),
        const SizedBox(height: 20),
        const Text(
          "4. Merge time (matching interval)",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 8,
          children: ["1 min", "2 min", "5 min", "10 min", "30 min", "1 hr"]
              .map((e) => ChoiceChip(label: Text(e), selected: e == "1 min"))
              .toList(),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.sync),
          label: const Text("MERGE"),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _mergeStep(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(subtitle, style: const TextStyle(color: Colors.grey)),
          ),
          trailing: ElevatedButton(
            onPressed: () {},
            child: const Text("Browse"),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _mergeCheck(String label) => CheckboxListTile(
        title: Text(label),
        value: true,
        onChanged: (v) {},
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
      );
}
