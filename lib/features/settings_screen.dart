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
            subtitle: "Configure recording behavior and automation",
            onTap: () => _openSubSettings(
                context, "Record settings", _buildRecordSettings()),
          ),
          // 2. Display Settings Category
          _SettingsCategoryTile(
            icon: Icons.monitor_outlined,
            title: "Display settings",
            subtitle: "Customize units, map, charts and appearance",
            onTap: () => _openSubSettings(
                context, "Display settings", _buildDisplaySettings()),
          ),
          // 3. Storage Settings Category
          _SettingsCategoryTile(
            icon: Icons.storage_outlined,
            title: "Storage settings",
            subtitle: "Manage storage, import/export and databases",
            onTap: () => _openSubSettings(
                context, "Storage settings", _buildStorageSettings()),
          ),
          // 4. Manage Subscription Category
          _SettingsCategoryTile(
            icon: Icons.visibility_outlined,
            title: "Manage subscription",
            subtitle: "View and manage your subscription",
            onTap: () {},
          ),

          const Divider(),

          // Subscription Banner matching screenshot
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      text: "Subscription: ",
                      style: TextStyle(
                          color: Colors.black, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                            text: "NONE", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                            "Subscribe now and unlock all premium features",
                            style:
                                TextStyle(fontSize: 12, color: Colors.black54)),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white),
                        child: const Text("SUBSCRIBE"),
                      )
                    ],
                  )
                ],
              ),
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
            title: Text("Record profile: General"),
            subtitle: Text("Freq: 1 second, Dist: 1.0 m")),
        SwitchListTile(
          secondary: const Icon(Icons.battery_saver_outlined),
          title: const Text("Ignore battery optimizations"),
          subtitle: const Text("Recommended for better background recording"),
          value: true,
          onChanged: (v) {},
        ),
        const ListTile(
            title: Text("Setup for background work"),
            subtitle: Text(
                "Manual configuration for continuous background recording")),
        SwitchListTile(
          secondary: const Icon(Icons.stop_circle_outlined),
          title: const Text("Mark stops"),
          subtitle:
              const Text("Automatically mark stops when you stop for a while"),
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
            title: Text("Default x-axis for charts"),
            subtitle: Text("Duration (s)")),
        const Divider(),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Appearance Theme",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ),
        RadioListTile<AppThemeChoice>(
          title: const Text("Red & White"),
          value: AppThemeChoice.redWhite,
          groupValue: widget.currentTheme,
          onChanged: (v) => widget.onThemeChanged(v!),
        ),
        RadioListTile<AppThemeChoice>(
          title: const Text("Blue & Black"),
          value: AppThemeChoice.blueBlackWhite,
          groupValue: widget.currentTheme,
          onChanged: (v) => widget.onThemeChanged(v!),
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
            subtitle: Text("TXT (Default)")),
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
          onTap: () => notifier.clearLog(),
        ),
        ListTile(
          leading: const Icon(Icons.save_outlined, color: Colors.green),
          title: const Text("Save and lock log"),
          onTap: () => notifier.saveLog(),
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
