import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/app_theme.dart';
import 'features/dashboard_screen.dart';
import 'features/settings_screen.dart';
import 'features/source_selection_dialog.dart';

void main() {
  runApp(const ProviderScope(child: SkyTrackApp()));
}

/// Root widget. Per client notes, the exe scope is intentionally narrow:
///   "In exe dashboard map and merge data and 3 dots for selecting"
/// -> Dashboard is the main (and effectively only) screen; "Select GNSS
/// device" lives as a single top-right AppBar action, and Settings lives
/// behind the 3-dot overflow menu. Skyplot/satellite view and Statistics
/// are explicitly APK-only per the client notes and are not built here.
class SkyTrackApp extends StatefulWidget {
  const SkyTrackApp({super.key});

  @override
  State<SkyTrackApp> createState() => _SkyTrackAppState();
}

class _SkyTrackAppState extends State<SkyTrackApp> {
  AppThemeChoice _theme = AppThemeChoice.redWhite;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkyTrack GNSS Explorer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(_theme),
      home: _HomeShell(
        currentTheme: _theme,
        onThemeChanged: (t) => setState(() => _theme = t),
      ),
    );
  }
}

class _HomeShell extends StatefulWidget {
  final AppThemeChoice currentTheme;
  final ValueChanged<AppThemeChoice> onThemeChanged;

  const _HomeShell({required this.currentTheme, required this.onThemeChanged});

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SkyTrack GNSS Explorer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.satellite_alt_outlined),
            tooltip: 'Select GNSS device',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const SourceSelectionDialog(),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'settings') {
                setState(() => _showSettings = !_showSettings);
              } else if (value == 'share_location') {
                _shareLocation(context);
              } else if (value == 'export') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export uses the Windows file picker (see Settings > File actions)')),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'share_location', child: Text('Share my location')),
              PopupMenuItem(value: 'export', child: Text('Export data')),
            ],
          ),
        ],
      ),
      body: _showSettings
          ? SettingsScreen(
              currentTheme: widget.currentTheme,
              onThemeChanged: widget.onThemeChanged,
            )
          : const DashboardScreen(),
    );
  }

  void _shareLocation(BuildContext context) {
    // Windows share sheet / clipboard fallback wired up in a later phase;
    // placeholder confirms the entry point exists per client notes
    // ("On share location we can share my location").
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share location: coordinates copied (placeholder)')),
    );
  }
}
