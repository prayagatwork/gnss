import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'gnss_session_controller.dart';

/// "Using 3 dots in the settings refer the first image" — this is the panel
/// opened from the AppBar's 3-dot menu. Covers spec 8.3 for exe scope
/// (Windows folder selection; no Android SAF/export-share here).
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
  int _samplingSeconds = 1;
  String _rotation = '1 hour';
  bool _rawNmeaEnabled = false;
  bool _autoReconnect = true;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gnssSessionProvider);
    final notifier = ref.read(gnssSessionProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(context, 'Logging'),
        SwitchListTile(
          title: const Text('Enable logging'),
          value: session.loggingEnabled,
          onChanged: (v) => notifier.setLoggingEnabled(v),
        ),
        ListTile(
          title: const Text('Sampling interval'),
          trailing: DropdownButton<int>(
            value: _samplingSeconds,
            items: const [1, 5, 10]
                .map((s) => DropdownMenuItem(value: s, child: Text('$s s')))
                .toList(),
            onChanged: (v) => setState(() => _samplingSeconds = v ?? 1),
          ),
        ),
        ListTile(
          title: const Text('File rotation interval'),
          trailing: DropdownButton<String>(
            value: _rotation,
            items: const ['30 minutes', '1 hour', 'Daily']
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => _rotation = v ?? '1 hour'),
          ),
        ),
        SwitchListTile(
          title: const Text('Also record raw NMEA (.nmea)'),
          subtitle: const Text('Normalized CSV is always recorded'),
          value: _rawNmeaEnabled,
          onChanged: (v) => setState(() => _rawNmeaEnabled = v),
        ),
        const Divider(height: 32),
        _sectionTitle(context, 'File actions'),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => notifier.clearLog(),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear (discard, do not save)'),
            ),
            FilledButton.icon(
              onPressed: () => notifier.saveLog(),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Save (locks file — no further edits)'),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Default filename format: yyyymmdd_hhmmssmmm.txt',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const Divider(height: 32),
        _sectionTitle(context, 'Connection'),
        SwitchListTile(
          title: const Text('Automatic reconnect'),
          subtitle: const Text('Up to 5 attempts: 1s, 2s, 4s, 8s, 16s'),
          value: _autoReconnect,
          onChanged: (v) => setState(() => _autoReconnect = v),
        ),
        const Divider(height: 32),
        _sectionTitle(context, 'Appearance'),
        RadioListTile<AppThemeChoice>(
          title: const Text('Red & White'),
          value: AppThemeChoice.redWhite,
          groupValue: widget.currentTheme,
          onChanged: (v) => widget.onThemeChanged(v!),
        ),
        RadioListTile<AppThemeChoice>(
          title: const Text('Blue, White & Black'),
          value: AppThemeChoice.blueBlackWhite,
          groupValue: widget.currentTheme,
          onChanged: (v) => widget.onThemeChanged(v!),
        ),
        const Divider(height: 32),
        _sectionTitle(context, 'Diagnostics'),
        ListTile(
          title: const Text('Bytes received'),
          trailing: Text('${session.diagnostics.bytesReceived}'),
        ),
        ListTile(
          title: const Text('Sentences parsed / rejected'),
          trailing: Text(
              '${session.diagnostics.parsed} / ${session.diagnostics.checksumFailed + session.diagnostics.malformed}'),
        ),
        TextButton(
          onPressed: () => setState(() => session.diagnostics.reset()),
          child: const Text('Clear diagnostics counters'),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
