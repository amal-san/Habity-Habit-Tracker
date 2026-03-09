import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/notification_service.dart';


class GlobalRemindersScreen extends StatefulWidget {
  const GlobalRemindersScreen({super.key});

  @override
  State<GlobalRemindersScreen> createState() => _GlobalRemindersScreenState();
}

class _GlobalRemindersScreenState extends State<GlobalRemindersScreen> {
  final _settingsBox = Hive.box('settingsBox');

  bool _isEnabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0); // Default 6:00 PM
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> titles = [
    'Stay on Track!',
    'Time for Your Habits',
    'Habit Reminder',
    'Keep the Streak Alive!',
    'Daily Habit Check'
  ];

  final List<String> descriptions = [
    'Take a moment to complete your habits and stay consistent.',
    'Your daily habits are waiting. Let’s keep the momentum going!',
    'Small habits lead to big results. Complete them now.',
    'Consistency builds success. Don’t break your streak today.',
    'A quick reminder to finish your habits and stay productive.'
  ];

  @override
  void initState() {
    super.initState();

    _isEnabled = _settingsBox.get('globalEnabled', defaultValue: false);
    _time = TimeOfDay(
      hour: _settingsBox.get('globalHour', defaultValue: 18),
      minute: _settingsBox.get('globalMinute', defaultValue: 0),
    );


    String savedTitle = _settingsBox.get('globalTitle', defaultValue: '');
    String savedBody = _settingsBox.get('globalBody', defaultValue: '');


    final random = Random();
    if (savedTitle.trim().isEmpty) {
      savedTitle = titles[random.nextInt(titles.length)];
    }
    if (savedBody.trim().isEmpty) {
      savedBody = descriptions[random.nextInt(descriptions.length)];
    }

    _titleController.text = savedTitle;
    _bodyController.text = savedBody;
  }

  void _saveAndSchedule() {
    _settingsBox.put('globalEnabled', _isEnabled);
    _settingsBox.put('globalHour', _time.hour);
    _settingsBox.put('globalMinute', _time.minute);

    // Provide a hard fallback so you never send a blank notification
    String finalTitle = _titleController.text.trim().isEmpty ? 'Habit Reminder' : _titleController.text;
    String finalBody = _bodyController.text.trim().isEmpty ? 'Time to complete your habits!' : _bodyController.text;

    _settingsBox.put('globalTitle', finalTitle);
    _settingsBox.put('globalBody', finalBody);

    if (_isEnabled) {
      NotificationService.scheduleGlobalReminder(_time, finalTitle, finalBody);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reminder set for ${_time.format(context)}')));
    } else {
      NotificationService.cancelGlobalReminder();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Global reminders disabled')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Text('Settings', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Daily Check-In Reminders', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Set up a daily notification to remind you to complete your habits.', style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700, fontSize: 16)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => NotificationService.fireInstantNotification(),
            child: const Text('Fire Instant Test Notification'),
          ),

          // Enable Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // NEW: Wrap the text in Expanded to prevent the 6.9 pixel overflow!
              Expanded(
                child: Text(
                  'Enable Daily Check-In Reminders',
                  style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Switch(
                value: _isEnabled,
                activeColor: const Color(0xFF673AB7),
                onChanged: (val) {
                  setState(() => _isEnabled = val);
                  _saveAndSchedule();
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Time Picker Button
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _time);
              if (picked != null) {
                setState(() => _time = picked);
                _saveAndSchedule();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                  const SizedBox(width: 10),
                  Text(_time.format(context), style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Custom Title & Message
          _buildTextField(_titleController, 'Notification Title', Icons.title, cardColor, textColor),
          const SizedBox(height: 15),
          _buildTextField(_bodyController, 'Notification Message', Icons.notes, cardColor, textColor),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, Color fill, Color text) {
    return TextField(
      controller: controller,
      style: TextStyle(color: text),
      onChanged: (_) => _saveAndSchedule(), // Auto-save on type
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.grey.shade600),
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  // --- INSTANT TEST ---

}