import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'gnss_session_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final AppThemeChoice currentTheme;
  final ValueChanged<AppThemeChoice> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: ListView(
        children: [
          // 1. Record Settings Category
          _SettingsCategoryTile(
            icon: Icons.settings_voice_outlined,
            title: "Record settings",
            subtitle: "Configure path interval and accuracy filtering",
            onTap: () => _openSubSettings(
                context, "Record settings", _buildRecordSettings()),
          ),
          // 2. Display Settings Category
          _SettingsCategoryTile(
            icon: Icons.monitor_outlined,
            title: "Display settings",
            subtitle: "Customize units, map and appearance",
            onTap: () => _openSubSettings(
                context, "Display settings", _buildDisplaySettings()),
          ),
          // 3. Storage Settings Category
          _SettingsCategoryTile(
            icon: Icons.storage_outlined,
            title: "Storage settings",
            subtitle: "Manage TXT save, export and local logs",
            onTap: () => _openSubSettings(
                context, "Storage settings", _buildStorageSettings()),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Windows handover build: external HC-05 COM receiver or simulation file, OpenStreetMap dashboard, TXT path export.",
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  void _openSubSettings(BuildContext context, String title, Widget content) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: content,
        ),
      ),
    );
  }

  // --- Sub-Panels matching the screenshot detail views ---

  Widget _buildRecordSettings() {
    final session = ref.watch(gnssSessionProvider);
    return ListView(
      children: [
        const ListTile(
            title: Text("Record profile"),
            subtitle: Text("Time: seconds/minutes/hours | Distance: m/km")),
        ListTile(
          leading: const Icon(Icons.speed_outlined),
          title: const Text("Required accuracy filter"),
          subtitle: Text(
            session.filterByAccuracy
                ? "Enabled, threshold ${session.requiredAccuracyM.toStringAsFixed(1)}"
                : "Disabled",
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.stop_circle_outlined),
          title: const Text("Recording active"),
          subtitle:
              const Text("Use Dashboard controls to start, pause or finish"),
          value: session.isRecording,
          onChanged: (v) {},
        ),
        const ListTile(
            title: Text("Altitude baseline"),
            subtitle: Text("WGS84 (default)")),
      ],
    );
  }

  Widget _buildDisplaySettings() {
    return ListView(
      children: [
        const ListTile(
            leading: Icon(Icons.straighten),
            title: Text("Measurement units"),
            subtitle: Text("Distances: Kilometers • Altitudes: Meters")),
        const ListTile(
            leading: Icon(Icons.dark_mode_outlined),
            title: Text("Night mode"),
            subtitle: Text("Automatic")),
        const ListTile(
            leading: Icon(Icons.show_chart),
            title: Text("Dashboard map"),
            subtitle: Text("OpenStreetMap tiles in Windows exe")),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Appearance Theme",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<AppThemeChoice>(
            segments: const [
              ButtonSegment(
                value: AppThemeChoice.redWhite,
                label: Text("Red & White"),
                icon: Icon(Icons.circle_outlined),
              ),
              ButtonSegment(
                value: AppThemeChoice.blueBlackWhite,
                label: Text("Blue & Black"),
                icon: Icon(Icons.contrast),
              ),
            ],
            selected: {widget.currentTheme},
            onSelectionChanged: (selection) {
              widget.onThemeChanged(selection.first);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStorageSettings() {
    final notifier = ref.read(gnssSessionProvider.notifier);
    return ListView(
      children: [
        const ListTile(
            leading: Icon(Icons.folder_open),
            title: Text("External storage"),
            subtitle: Text("No storage selected")),
        const ListTile(
            leading: Icon(Icons.file_download_outlined),
            title: Text("Export format"),
            subtitle: Text("TXT, yyyymmdd_hhmmssmmm.txt")),
        Consumer(
          builder: (context, ref, _) {
            final session = ref.watch(gnssSessionProvider);
            return ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text("Saved log"),
              subtitle: Text(session.savedLogPath?.isEmpty ?? true
                  ? "No locked file saved yet"
                  : session.savedLogPath!),
            );
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Actions",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
          title: const Text("Clear current log"),
          onTap: () async {
            await notifier.clearLog();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Current path cleared.")),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.save_outlined, color: Colors.green),
          title: const Text("Save and lock log"),
          onTap: () async {
            final path = await notifier.saveLog();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(path == null
                    ? "No recorded path to save."
                    : "Saved to $path"),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _SettingsCategoryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade800, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black54)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
