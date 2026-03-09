import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/habit.dart';
import '../main.dart';
import '../services/local_sync_service.dart';
import 'global_reminders_screen.dart';


class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _launchURL(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  // --- HELPER: GENERATE JSON STRING ---
  String? _generateBackupJson(BuildContext context) {
    final box = Hive.box<Habit>('habitsBox');
    if (box.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No habits to export!')));
      return null;
    }

    final List<Map<String, dynamic>> exportData = box.values.map((h) => {
      'name': h.name,
      'description': h.description,
      'colorValue': h.colorValue,
      'iconCodePoint': h.iconCodePoint,
      'currentStreak': h.currentStreak,
      'longestStreak': h.longestStreak,
      'completedDays': h.completedDays.map((d) => d.toIso8601String()).toList(),
      'completionsPerDay': h.completionsPerDay,
      'reminderTimes': h.reminderTimes.map((dt) => dt.toIso8601String()).toList(),    }).toList();

    return jsonEncode(exportData);
  }

  // --- LOGIC 1: SHARE FILE ---
  Future<void> _shareData(BuildContext context) async {
    final jsonString = _generateBackupJson(context);
    if (jsonString == null) return;

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/Habity_Backup.json');
    await file.writeAsString(jsonString);

    await Share.shareXFiles([XFile(file.path)], subject: 'My Habity Backup');
  }

  // --- LOGIC 2: SAVE TO STORAGE ---
  Future<void> _saveDataToStorage(BuildContext context) async {
    final jsonString = _generateBackupJson(context);
    if (jsonString == null) return;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // MOBILE FIX: Bypass strict Scoped Storage rules by using the temporary cache
        // and triggering the native OS "Save to Files" interface.
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/Habity_Backup.json'); // Updated name!
        await file.writeAsString(jsonString);

        // This forces Android/iOS to open their native save dialogue safely
        await Share.shareXFiles([XFile(file.path)], subject: 'Habity Backup');

      } else {
        // DESKTOP FIX: Works perfectly for your Windows and Linux builds
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Backup File',
          fileName: 'Habity_Backup.json', // Updated name!
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(jsonString);

          // context.mounted prevents a Flutter warning when showing UI after an async gap
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to your device!')));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error saving file.')));
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();
        List<dynamic> jsonData = jsonDecode(jsonString);

        final box = Hive.box<Habit>('habitsBox');

        for (var item in jsonData) {
          final habit = Habit(
            name: item['name'] ?? 'Imported Habit',
            completedDays: (item['completedDays'] as List?)?.map((e) => DateTime.parse(e)).toList() ?? [],
            description: item['description'] ?? '',
            colorValue: item['colorValue'] ?? 0xFF673AB7,
            iconCodePoint: item['iconCodePoint'] ?? 0xe0b0,
            completionsPerDay: item['completionsPerDay'] ?? 1,
            reminderTimes: (item['reminderTimes'] as List?)?.map((e) => DateTime.parse(e.toString())).toList() ?? [],          );
          habit.currentStreak = item['currentStreak'] ?? 0;
          habit.longestStreak = item['longestStreak'] ?? 0;
          box.add(habit);
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data imported successfully!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error reading backup file.')));
    }
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Select Theme'),
            backgroundColor: Theme.of(context).cardColor,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: const Text('Light Mode'), leading: const Icon(Icons.light_mode), onTap: () { themeNotifier.value = ThemeMode.light; Navigator.pop(context); }),
                ListTile(title: const Text('Dark Mode'), leading: const Icon(Icons.dark_mode), onTap: () { themeNotifier.value = ThemeMode.dark; Navigator.pop(context); }),
                ListTile(title: const Text('System Default'), leading: const Icon(Icons.settings_system_daydream), onTap: () { themeNotifier.value = ThemeMode.system; Navigator.pop(context); }),
              ],
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          _buildSectionHeader('App', isDark),

          // --- NEW: Toggle for Editing Past Days ---
          ValueListenableBuilder(
              valueListenable: Hive.box('settingsBox').listenable(),
              builder: (context, box, child) {
                final allowPast = box.get('allowPastEdits', defaultValue: true);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.edit_calendar, color: textColor, size: 22),
                      const SizedBox(width: 15),
                      Expanded(child: Text('Allow Editing Past Days', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500))),
                      Switch(
                        value: allowPast,
                        activeColor: const Color(0xFF673AB7),
                        onChanged: (val) => box.put('allowPastEdits', val),
                      ),
                    ],
                  ),
                );
              }
          ),


          _buildSectionHeader('Data', isDark)
          ,
          // NEW: Two distinct export options!
          ValueListenableBuilder(
              valueListenable: Hive.box('settingsBox').listenable(),
              builder: (context, box, child) {
                final currentKey = box.get('localSyncKey', defaultValue: '');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_tethering, color: currentKey.isEmpty ? Colors.grey : Colors.green, size: 22),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Local Network Auto-Sync', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
                            Text(currentKey.isEmpty ? 'Set a passcode to enable' : 'Active. Scanning local network...', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          TextEditingController _keyController = TextEditingController(text: currentKey);
                          showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: cardColor,
                                title: Text('Sync Passcode', style: TextStyle(color: textColor)),
                                content: TextField(
                                  controller: _keyController,
                                  style: TextStyle(color: textColor),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. MySecretKey123',
                                    hintStyle: TextStyle(color: Colors.grey.shade600),
                                    helperText: 'Enter the exact same code on your PC/Phone.',
                                    helperMaxLines: 2,
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () {
                                      box.put('localSyncKey', _keyController.text.trim());
                                      LocalSyncService.start(); // Restart the engine with the new key!
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Save & Start'),
                                  ),
                                ],
                              )
                          );
                        },
                        child: const Text('EDIT'),
                      )
                    ],
                  ),
                );
              }
          ),
       //   _buildSettingItem(Icons.share, 'Share Backup Data', cardColor, textColor, () => _shareData(context)),
          _buildSettingItem(Icons.save_alt, 'Save Backup to Storage', cardColor, textColor, () => _saveDataToStorage(context)),
          _buildSettingItem(Icons.file_download_outlined, 'Import Data', cardColor, textColor, () => _importData(context)),

          const SizedBox(height: 30),
          _buildSectionHeader('Appearance', isDark),
          _buildSettingItem(Icons.palette_outlined, 'Change Theme', cardColor, textColor, () => _showThemeDialog(context)),

          const SizedBox(height: 30),
          _buildSectionHeader('About', isDark),
          _buildSettingItem(Icons.privacy_tip_outlined, 'Privacy Policy', cardColor, textColor, () => _launchURL(context, 'https://github.com/manjeetdeswal/Habity-Habit-Tracker')),
          _buildSettingItem(Icons.star_border, 'Support us', cardColor, textColor, () => _launchURL(context, 'https://www.patreon.com/c/unrealcomponent/posts')),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 10, left: 4), child: Text(title, style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.bold)));

  Widget _buildSettingItem(IconData icon, String title, Color fill, Color text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: text, size: 22),
            const SizedBox(width: 15),
            Expanded(child: Text(title, style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w500))),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}