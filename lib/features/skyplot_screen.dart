import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SkyplotScreen extends StatelessWidget {
  const SkyplotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.map), text: "MAP"),
              Tab(icon: Icon(Icons.bar_chart), text: "STATISTICS"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMap(),
                _buildStatistics(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      options: const MapOptions(
          initialCenter: LatLng(28.6139, 77.2090), initialZoom: 13),
      children: [
        TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
      ],
    );
  }

  Widget _buildStatistics() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 4 Summary Cards
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _StatMiniCard("Points", "56"),
            _StatMiniCard("Track", "3.72 km"),
            _StatMiniCard("Max Spd", "28.6"),
            _StatMiniCard("Avg Spd", "12.4"),
          ],
        ),
        const SizedBox(height: 20),
        const Text("SPEED PLOT (km/h)",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 150, child: _LineChart(color: Colors.blue)),
        const Divider(height: 40),
        const Text("ELEVATION PLOT (m)",
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 150, child: _LineChart(color: Colors.green)),
      ],
    );
  }

  Widget _StatMiniCard(String l, String v) => Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(children: [
            Text(l, style: const TextStyle(fontSize: 10)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.bold))
          ]),
        ),
      );
}

class _LineChart extends StatelessWidget {
  final Color color;
  const _LineChart({required this.color});
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(
            show: true, border: Border.all(color: Colors.grey.shade300)),
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 1),
              const FlSpot(2, 3),
              const FlSpot(4, 2),
              const FlSpot(6, 5),
              const FlSpot(8, 4)
            ],
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData:
                BarAreaData(show: true, color: color.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}
