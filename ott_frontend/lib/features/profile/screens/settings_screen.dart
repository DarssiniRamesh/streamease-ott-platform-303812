import 'package:flutter/material.dart';
import 'package:ott_frontend/core/i18n/app_localizations.dart';
import 'package:ott_frontend/features/profile/controllers/settings_controller.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: SafeArea(
        child: Consumer<SettingsController>(
          builder: (BuildContext context, SettingsController s, _) {
            if (s.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: <Widget>[
                Text(t.quality, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: StreamingQuality.values
                        .map(
                          (StreamingQuality q) => RadioListTile<StreamingQuality>(
                            value: q,
                            groupValue: s.quality,
                            onChanged: (StreamingQuality? v) {
                              if (v != null) {
                                s.setQuality(v);
                              }
                            },
                            title: Text(q.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  t.subtitlesDefault,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Card(
                  child: SwitchListTile(
                    value: s.subtitlesDefault,
                    onChanged: (bool v) => s.setSubtitlesDefault(v),
                    title: const Text('Enable subtitles by default'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
