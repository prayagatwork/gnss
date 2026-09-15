import 'package:flutter/material.dart';

class SatellitesScreen extends StatelessWidget {
  const SatellitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SatInfo("12", "GPS", Colors.blue),
              _SatInfo("8", "GLONASS", Colors.red),
              _SatInfo("3", "Other", Colors.green),
              _SatInfo("0", "SBAS", Colors.orange),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              DataTable(
                columns: const [
                  DataColumn(label: Text("PRN")),
                  DataColumn(label: Text("SYSTEM")),
                  DataColumn(label: Text("EL")),
                  DataColumn(label: Text("AZ")),
                  DataColumn(label: Text("SNR")),
                ],
                rows: List.generate(
                    5,
                    (i) => DataRow(cells: [
                          DataCell(Text("${i + 7}")),
                          const DataCell(Text("GPS")),
                          const DataCell(Text("62°")),
                          const DataCell(Text("138°")),
                          const DataCell(Text("45")),
                        ])),
              )
            ],
          ),
        )
      ],
    );
  }
}

class _SatInfo extends StatelessWidget {
  final String val, label;
  final Color color;
  const _SatInfo(this.val, this.label, this.color);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(val,
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    ]);
  }
}
