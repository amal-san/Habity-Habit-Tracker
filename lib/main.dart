import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'models/focus_session.dart';
import 'models/note.dart';
import 'models/todo.dart';
import 'services/habitDatabase.dart';
import 'models/habit.dart';
import 'screens/home_page.dart';
import 'services/local_sync_service.dart';
import 'services/notification_service.dart';





@pragma("vm:entry-point")
Future<void> interactiveCallback(Uri? uri) async {
  if (uri?.host == 'tickhabit') {
    int habitKey = int.parse(uri?.queryParameters['id'] ?? '-1');
    if (habitKey != -1) {
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(HabitAdapter());
      }
      final box = await Hive.openBox<Habit>('habitsBox');
      final habit = box.values.firstWhere((h) => h.key == habitKey);

      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);


      bool isDone = habit.completedDays.any((d) => d.year == today.year && d.month == today.month && d.day == today.day);


      if (isDone) {
        habit.completedDays.removeWhere((d) => d.year == today.year && d.month == today.month && d.day == today.day);
        isDone = false;
      } else {
        habit.completedDays.add(today);
        isDone = true;
      }

      habit.save();

      await HomeWidget.saveWidgetData<bool>('habit_${habit.key}_done', isDone);


      await HabitDatabase.syncWidgetState(habit);

      await HomeWidget.updateWidget(name: 'FitdyWidgetProvider');
    }
  }
}


final ValueNotifier<double> fontScaleNotifier = ValueNotifier(1.0);
final ValueNotifier<String> appThemeIdNotifier = ValueNotifier('system');

const Map<String, double> appFontScaleOptions = {
  'Large': 1.15,
  'Medium': 1.0,
  'Small': 0.9,
  'Extra Small': 0.8,
};

ThemeData _buildTheme({
  required Brightness brightness,
  required Color scaffoldBackgroundColor,
  required Color cardColor,
  required AppBarTheme appBarTheme,
  Color? primaryColor,
}) {
  return ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor ?? const Color(0xFF673AB7),
      brightness: brightness,
    ),
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    cardColor: cardColor,
    appBarTheme: appBarTheme,
    useMaterial3: true,
  );
}

class AppThemeOption {
  final String id;
  final String label;
  final ThemeMode mode;
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  const AppThemeOption({
    required this.id,
    required this.label,
    required this.mode,
    required this.lightTheme,
    required this.darkTheme,
  });
}

final List<AppThemeOption> appThemeOptions = [
  AppThemeOption(
    id: 'system',
    label: 'System Default',
    mode: ThemeMode.system,
    lightTheme: _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.grey.shade100,
      cardColor: Colors.white,
      appBarTheme: AppBarTheme(backgroundColor: Colors.grey.shade100, foregroundColor: Colors.black, elevation: 0),
      primaryColor: const Color(0xFF673AB7),
    ),
    darkTheme: _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121421),
      cardColor: const Color(0xFF1C1F30),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121421), foregroundColor: Colors.white, elevation: 0),
      primaryColor: const Color(0xFF673AB7),
    ),
  ),
  AppThemeOption(
    id: 'minimal-light',
    label: 'Minimal Light',
    mode: ThemeMode.light,
    lightTheme: _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F7F8),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F7F8), foregroundColor: Color(0xFF111111), elevation: 0),
      primaryColor: const Color(0xFF111111),
    ),
    darkTheme: _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121421),
      cardColor: const Color(0xFF1C1F30),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121421), foregroundColor: Colors.white, elevation: 0),
      primaryColor: const Color(0xFF673AB7),
    ),
  ),
  AppThemeOption(
    id: 'minimal-dark',
    label: 'Minimal Dark',
    mode: ThemeMode.dark,
    lightTheme: _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.grey.shade100,
      cardColor: Colors.white,
      appBarTheme: AppBarTheme(backgroundColor: Colors.grey.shade100, foregroundColor: Colors.black, elevation: 0),
      primaryColor: const Color(0xFF673AB7),
    ),
    darkTheme: _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      cardColor: const Color(0xFF161B22),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0D1117), foregroundColor: Color(0xFFE6EDF3), elevation: 0),
      primaryColor: const Color(0xFF9DA7B3),
    ),
  ),
  AppThemeOption(
    id: 'solarized-light',
    label: 'Solarized Light',
    mode: ThemeMode.light,
    lightTheme: _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFfdf6e3),
      cardColor: const Color(0xFFeee8d5),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFfdf6e3), foregroundColor: Color(0xFF586e75), elevation: 0),
      primaryColor: const Color(0xFF268bd2),
    ),
    darkTheme: _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121421),
      cardColor: const Color(0xFF1C1F30),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121421), foregroundColor: Colors.white, elevation: 0),
      primaryColor: const Color(0xFF673AB7),
    ),
  ),
  AppThemeOption(
    id: 'solarized-dark',
    label: 'Solarized Dark',
    mode: ThemeMode.dark,
    lightTheme: _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.grey.shade100,
      cardColor: Colors.white,
      appBarTheme: AppBarTheme(backgroundColor: Colors.grey.shade100, foregroundColor: Colors.black, elevation: 0),
      primaryColor: const Color(0xFF673AB7),
    ),
    darkTheme: _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF002b36),
      cardColor: const Color(0xFF073642),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF002b36), foregroundColor: Color(0xFF93a1a1), elevation: 0),
      primaryColor: const Color(0xFF2aa198),
    ),
  ),
  AppThemeOption(
    id: 'vscode-dark-plus',
    label: 'VS Code Dark+',
    mode: ThemeMode.dark,
    lightTheme: _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.grey.shade100,
      cardColor: Colors.white,
      appBarTheme: AppBarTheme(backgroundColor: Colors.grey.shade100, foregroundColor: Colors.black, elevation: 0),
      primaryColor: const Color(0xFF673AB7),
    ),
    darkTheme: _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      cardColor: const Color(0xFF252526),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E), foregroundColor: Color(0xFFD4D4D4), elevation: 0),
      primaryColor: const Color(0xFF007ACC),
    ),
  ),
  AppThemeOption(
    id: 'vscode-light-plus',
    label: 'VS Code Light+',
    mode: ThemeMode.light,
    lightTheme: _buildTheme(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      cardColor: const Color(0xFFF3F3F3),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFFFFFFF), foregroundColor: Color(0xFF333333), elevation: 0),
      primaryColor: const Color(0xFF005FB8),
    ),
    darkTheme: _buildTheme(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF121421),
      cardColor: const Color(0xFF1C1F30),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF121421), foregroundColor: Colors.white, elevation: 0),
      primaryColor: const Color(0xFF673AB7),
    ),
  ),
];

AppThemeOption getThemeById(String id) {
  return appThemeOptions.firstWhere(
    (t) => t.id == id,
    orElse: () => appThemeOptions.first,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();


  Hive.registerAdapter(HabitAdapter());
  Hive.registerAdapter(TodoAdapter());
  Hive.registerAdapter(NoteAdapter());
  Hive.registerAdapter(FocusSessionAdapter());


  await Hive.openBox<Habit>('habitsBox');
  await Hive.openBox<Todo>('todoBox');
  await Hive.openBox<Note>('notesBox');
  await Hive.openBox<FocusSession>('focusBox');
  final settingsBox = await Hive.openBox('settingsBox');
  final savedFontScale = (settingsBox.get('appFontScale', defaultValue: 1.0) as num).toDouble();
  fontScaleNotifier.value = savedFontScale;
  final savedThemeId = settingsBox.get('appThemeId', defaultValue: 'system') as String;
  appThemeIdNotifier.value = savedThemeId;

  await NotificationService.init();

  // These integrations rely on platform-specific APIs that are not
  // implemented on Flutter web.
  if (!kIsWeb) {
    await LocalSyncService.start();
    HomeWidget.registerInteractivityCallback(interactiveCallback);
  }

  runApp(const FitdyApp());
}

class FitdyApp extends StatelessWidget {
  const FitdyApp({super.key});

  @override
  Widget build(BuildContext context) {

    return ValueListenableBuilder<String>(
      valueListenable: appThemeIdNotifier,
      builder: (_, String currentThemeId, __) {
        return ValueListenableBuilder<double>(
          valueListenable: fontScaleNotifier,
          builder: (_, double currentFontScale, __) {
            final theme = getThemeById(currentThemeId);
            return MaterialApp(
              title: 'Habity',
              debugShowCheckedModeBanner: false,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(currentFontScale),
                  ),
                  child: child ?? const SizedBox.shrink(),
                );
              },
              theme: theme.lightTheme,
              darkTheme: theme.darkTheme,
              themeMode: theme.mode,
              home: const HomePage(),
            );
          },
        );
      },
    );
  }
}