import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/app_theme.dart';
import 'features/dashboard_screen.dart';
import 'features/gnss_session_controller.dart';
import 'features/settings_screen.dart';
import 'features/source_selection_dialog.dart';

void main() => runApp(const ProviderScope(child: SkyTrackApp()));

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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(_theme),
      home: MainShell(
        currentTheme: _theme,
        onThemeChanged: (choice) => setState(() => _theme = choice),
      ),
    );
  }
}

class MainShell extends ConsumerWidget {
  final AppThemeChoice currentTheme;
  final ValueChanged<AppThemeChoice> onThemeChanged;

  const MainShell({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'SkyTrack GNSS Explorer',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Select GNSS device',
            icon: const Icon(Icons.link),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const SourceSelectionDialog(),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenu(context, ref, value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'loc',
                child: ListTile(
                  leading: Icon(Icons.location_on_outlined),
                  title: Text('My Location'),
                ),
              ),
              PopupMenuItem(
                value: 'track',
                child: ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('Waypoints & Track Data'),
                ),
              ),
              PopupMenuItem(
                value: 'set',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),
              PopupMenuItem(
                value: 'exp',
                child: ListTile(
                  leading: Icon(Icons.upload_outlined),
                  title: Text('Export Current Path'),
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: const DashboardScreen(),
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    WidgetRef ref,
    String value,
  ) async {
    final session = ref.read(gnssSessionProvider);
    final messenger = ScaffoldMessenger.of(context);

    switch (value) {
      case 'loc':
        final fix = session.currentFix;
        if (fix?.latitudeDeg == null || fix?.longitudeDeg == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('No valid GNSS location yet.')),
          );
          return;
        }
        final text =
            '${fix!.latitudeDeg!.toStringAsFixed(6)}, ${fix.longitudeDeg!.toStringAsFixed(6)}';
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Location copied: $text')),
        );
        return;
      case 'track':
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${session.pathPoints.length} point(s), '
              '${session.totalDistance.toStringAsFixed(1)} m recorded.',
            ),
          ),
        );
        return;
      case 'set':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SettingsScreen(
              currentTheme: currentTheme,
              onThemeChanged: onThemeChanged,
            ),
          ),
        );
        return;
      case 'exp':
        final savedPath =
            await ref.read(gnssSessionProvider.notifier).saveLog();
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(savedPath == null
                ? 'No recorded path to export.'
                : 'Path saved to $savedPath'),
          ),
        );
        return;
      case 'about':
        showAboutDialog(
          context: context,
          applicationName: 'SkyTrack GNSS Explorer',
          applicationVersion: '0.1.0',
          children: const [
            Text('Windows exe handover build for HC-05 GNSS COM input.'),
          ],
        );
        return;
    }
  }
}
