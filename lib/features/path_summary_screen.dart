import 'package:flutter/material.dart';
import '../domain/models/path_point.dart';

class PathSummaryScreen extends StatelessWidget {
  final List<PathPoint> points;
  const PathSummaryScreen({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Finish Path")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const TextField(
                    decoration: InputDecoration(
                        labelText: "Path Name",
                        hintText: "DIST 01",
                        border: OutlineInputBorder())),
                const SizedBox(height: 16),
                _statRow("Start Time:", "2026-09-07 15:22:16"),
                _statRow("Distance:", "41.44m"),
                _statRow("Max Altitude:", "211.50m"),
                CheckboxListTile(
                  title: const Text("Enclose the lines to form a Polygon"),
                  value: false,
                  onChanged: (v) {},
                  controlAffinity: ListTileControlAffinity.leading,
                )
              ],
            ),
          ),
          const Divider(),
          const Text("Select Point(s)",
              style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: points.length,
              itemBuilder: (context, i) => ListTile(
                leading: Checkbox(value: true, onChanged: (v) {}),
                title: Text(
                    "${i + 1}) ${points[i].timestamp.hour}:${points[i].timestamp.minute} ; ${points[i].latitude}, ${points[i].longitude}"),
                dense: true,
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton(
                        onPressed: () {}, child: const Text("Clear"))),
                const SizedBox(width: 8),
                Expanded(
                    child: ElevatedButton(
                        onPressed: () {}, child: const Text("Save"))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _statRow(String label, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(label),
          const SizedBox(width: 10),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold))
        ]),
      );
}
