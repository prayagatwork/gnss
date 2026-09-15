import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/dashboard_screen.dart';
import 'features/satellites_screen.dart';
import 'features/skyplot_screen.dart';
import 'features/source_selection_dialog.dart';
import 'features/app_theme.dart';

void main() => runApp(const ProviderScope(child: SkyTrackApp()));

class SkyTrackApp extends StatelessWidget {
  const SkyTrackApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(AppThemeChoice.redWhite),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor:
            const Color(0xFFF5F7FA), // Light grey background like screenshot
        appBar: AppBar(
          title: const Text('SkyTrack GNSS Explorer',
              style: TextStyle(fontSize: 18)),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "DASHBOARD"),
              Tab(text: "SATELLITES"),
              Tab(text: "SKYPLOT"),
            ],
          ),
          actions: [
            // The Link Icon for Device Selection
            IconButton(
              icon: const Icon(Icons.link),
              onPressed: () => showDialog(
                  context: context,
                  builder: (_) => const SourceSelectionDialog()),
            ),
            // The 3-dot Menu with EXACT 5 options
            PopupMenuButton<String>(
              onSelected: (v) {},
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'loc',
                    child: ListTile(
                        leading: Icon(Icons.location_on_outlined),
                        title: Text("My Location"))),
                const PopupMenuItem(
                    value: 'track',
                    child: ListTile(
                        leading: Icon(Icons.description_outlined),
                        title: Text("Waypoints & Track Data"))),
                const PopupMenuItem(
                    value: 'set',
                    child: ListTile(
                        leading: Icon(Icons.settings_outlined),
                        title: Text("Settings"))),
                const PopupMenuItem(
                    value: 'exp',
                    child: ListTile(
                        leading: Icon(Icons.upload_outlined),
                        title: Text("Export Current Path"))),
                const PopupMenuItem(
                    value: 'about',
                    child: ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text("About"))),
              ],
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            DashboardScreen(),
            SatellitesScreen(),
            SkyplotScreen(),
          ],
        ),
      ),
    );
  }
}
