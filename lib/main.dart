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
final ValueNotifier<String> appThemeIdNotifier = ValueNotifier('premium-futuristic');
final ValueNotifier<String> appFontIdNotifier = ValueNotifier('system');

const Map<String, double> appFontScaleOptions = {
  'Large': 1.15,
  'Medium': 1.0,
  'Small': 0.9,
  'Extra Small': 0.8,
};

class AppThemeSpec {
  final String id;
  final String label;
  final String description;
  final ThemeMode mode;
  final Color seedColor;
  final Color lightScaffold;
  final Color lightSurface;
  final Color darkScaffold;
  final Color darkSurface;

  const AppThemeSpec({
    required this.id,
    required this.label,
    required this.description,
    required this.mode,
    required this.seedColor,
    required this.lightScaffold,
    required this.lightSurface,
    required this.darkScaffold,
    required this.darkSurface,
  });
}

class AppThemeOption {
  final String id;
  final String label;
  final String description;
  final ThemeMode mode;
  final ThemeData lightTheme;
  final ThemeData darkTheme;

  const AppThemeOption({
    required this.id,
    required this.label,
    required this.description,
    required this.mode,
    required this.lightTheme,
    required this.darkTheme,
  });
}

TextTheme _buildTextTheme(Brightness brightness) {
  final base = ThemeData(brightness: brightness).textTheme;
  return base.copyWith(
    displaySmall: base.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
    headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: base.bodyLarge?.copyWith(height: 1.35),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.35),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.15),
  );
}

class AppFontOption {
  final String id;
  final String label;
  final String description;
  final String? fontFamily;

  const AppFontOption({
    required this.id,
    required this.label,
    required this.description,
    required this.fontFamily,
  });
}

ThemeData _buildTheme({
  required Brightness brightness,
  required Color scaffoldBackgroundColor,
  required Color surfaceColor,
  required Color seedColor,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    surface: surfaceColor,
  );

  final isDark = brightness == Brightness.dark;

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    cardColor: surfaceColor,
    textTheme: _buildTextTheme(brightness),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBackgroundColor,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: _buildTextTheme(brightness).titleLarge?.copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: surfaceColor,
      elevation: isDark ? 0 : 2,
      shadowColor: scheme.shadow.withOpacity(isDark ? 0.0 : 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: surfaceColor,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? surfaceColor.withOpacity(0.75) : surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: scaffoldBackgroundColor,
      selectedItemColor: scheme.primary,
      unselectedItemColor: scheme.onSurface.withOpacity(0.55),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withOpacity(0.16);
          }
          return surfaceColor.withOpacity(isDark ? 0.45 : 0.92);
        }),
        foregroundColor: WidgetStateProperty.all(scheme.onSurface),
        side: WidgetStateProperty.all(BorderSide(color: scheme.outlineVariant)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surfaceColor,
      contentTextStyle: TextStyle(color: scheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    useMaterial3: true,
  );
}
final List<AppThemeSpec> _themeSpecs = [
  AppThemeSpec(
    id: 'elegant-minimal',
    label: 'Elegant Minimal',
    description: 'Soft neutrals, refined contrast, understated accents.',
    mode: ThemeMode.light,
    seedColor: const Color(0xFF5B4BDA),
    lightScaffold: const Color(0xFFF6F7FB),
    lightSurface: const Color(0xFFFFFFFF),
    darkScaffold: const Color(0xFF111319),
    darkSurface: const Color(0xFF1A1E27),
  ),
  AppThemeSpec(
    id: 'premium-futuristic',
    label: 'Premium Futuristic',
    description: 'Recommended: clean depth, luminous accent, premium surfaces.',
    mode: ThemeMode.dark,
    seedColor: const Color(0xFF7C5CFF),
    lightScaffold: const Color(0xFFF4F5FF),
    lightSurface: const Color(0xFFFFFFFF),
    darkScaffold: const Color(0xFF0D1020),
    darkSurface: const Color(0xFF171B2E),
  ),
  AppThemeSpec(
    id: 'dark-glass-luxury',
    label: 'Dark Glass Luxury',
    description: 'Deep charcoal + cool glass layering with elegant highlights.',
    mode: ThemeMode.dark,
    seedColor: const Color(0xFF9B8CFF),
    lightScaffold: const Color(0xFFF4F5FF),
    lightSurface: const Color(0xFFFFFFFF),
    darkScaffold: const Color(0xFF090A0F),
    darkSurface: const Color(0xFF141722),
  ),
  AppThemeSpec(
    id: 'pearl-light',
    label: 'Pearl Light',
    description: 'Bright and airy, premium white surfaces with soft contrast.',
    mode: ThemeMode.light,
    seedColor: const Color(0xFF6B63FF),
    lightScaffold: const Color(0xFFFBFBFE),
    lightSurface: const Color(0xFFFFFFFF),
    darkScaffold: const Color(0xFF10131E),
    darkSurface: const Color(0xFF1A2030),
  ),
  AppThemeSpec(
    id: 'mist-light',
    label: 'Mist Light',
    description: 'Cool grayscale light theme for a clean productivity vibe.',
    mode: ThemeMode.light,
    seedColor: const Color(0xFF4F6D8A),
    lightScaffold: const Color(0xFFF4F7FA),
    lightSurface: const Color(0xFFFFFFFF),
    darkScaffold: const Color(0xFF0E131B),
    darkSurface: const Color(0xFF18202B),
  ),
  AppThemeSpec(
    id: 'rose-light',
    label: 'Rose Light',
    description: 'Warm premium light palette with subtle rose accenting.',
    mode: ThemeMode.light,
    seedColor: const Color(0xFFB55A7A),
    lightScaffold: const Color(0xFFFEF7F9),
    lightSurface: const Color(0xFFFFFFFF),
    darkScaffold: const Color(0xFF151018),
    darkSurface: const Color(0xFF1F1723),
  ),
  AppThemeSpec(
    id: 'forest-light',
    label: 'Forest Light',
    description: 'Natural green-led light palette, calm and balanced.',
    mode: ThemeMode.light,
    seedColor: const Color(0xFF2F7D62),
    lightScaffold: const Color(0xFFF4FAF7),
    lightSurface: const Color(0xFFFFFFFF),
    darkScaffold: const Color(0xFF0E1713),
    darkSurface: const Color(0xFF16241E),
  ),
  AppThemeSpec(
    id: 'vscode-light-plus',
    label: 'VS Code Light+',
    description: 'Light editor-inspired theme with crisp neutral contrast.',
    mode: ThemeMode.light,
    seedColor: const Color(0xFF005FB8),
    lightScaffold: const Color(0xFFFFFFFF),
    lightSurface: const Color(0xFFF3F3F3),
    darkScaffold: const Color(0xFF1E1E1E),
    darkSurface: const Color(0xFF252526),
  ),
  AppThemeSpec(
    id: 'midnight-neon',
    label: 'Midnight Neon',
    description: 'Dark modern palette with vibrant electric accent.',
    mode: ThemeMode.dark,
    seedColor: const Color(0xFF00D1FF),
    lightScaffold: const Color(0xFFF4F8FF),
    lightSurface: const Color(0xFFFFFFFF),
    darkScaffold: const Color(0xFF080B14),
    darkSurface: const Color(0xFF10182A),
  ),
  AppThemeSpec(
    id: 'graphite-pro',
    label: 'Graphite Pro',
    description: 'Professional dark graphite style with muted premium tones.',
    mode: ThemeMode.dark,
    seedColor: const Color(0xFF8A93A6),
    lightScaffold: const Color(0xFFF4F5F7),
    lightSurface: const Color(0xFFFFFFFF),
    darkScaffold: const Color(0xFF121416),
    darkSurface: const Color(0xFF1A1D22),
  ),
  AppThemeSpec(
    id: 'solarized-dark',
    label: 'Solarized Dark',
    description: 'Classic dark solarized theme tuned for dashboards.',
    mode: ThemeMode.dark,
    seedColor: const Color(0xFF2AA198),
    lightScaffold: const Color(0xFFFDF6E3),
    lightSurface: const Color(0xFFEEE8D5),
    darkScaffold: const Color(0xFF002B36),
    darkSurface: const Color(0xFF073642),
  ),
  AppThemeSpec(
    id: 'charcoal-night',
    label: 'Charcoal Night',
    description: 'Soft charcoal dark theme with subtle blue accents.',
    mode: ThemeMode.dark,
    seedColor: const Color(0xFF5C7AEA),
    lightScaffold: const Color(0xFFF5F7FF),
    lightSurface: const Color(0xFFFFFFFF),
    darkScaffold: const Color(0xFF101218),
    darkSurface: const Color(0xFF181C26),
  ),
];

final List<AppThemeOption> appThemeOptions = _themeSpecs
    .map(
      (spec) => AppThemeOption(
        id: spec.id,
        label: spec.label,
        description: spec.description,
        mode: spec.mode,
        lightTheme: _buildTheme(
          brightness: Brightness.light,
          scaffoldBackgroundColor: spec.lightScaffold,
          surfaceColor: spec.lightSurface,
          seedColor: spec.seedColor,
        ),
        darkTheme: _buildTheme(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: spec.darkScaffold,
          surfaceColor: spec.darkSurface,
          seedColor: spec.seedColor,
        ),
      ),
    )
    .toList();

AppThemeOption getThemeById(String id) {
  return appThemeOptions.firstWhere(
    (t) => t.id == id,
    orElse: () => appThemeOptions.first,
  );
}

const List<AppFontOption> appFontOptions = [
  AppFontOption(
    id: 'system',
    label: 'System Default',
    description: 'Platform default font, balanced and familiar.',
    fontFamily: null,
  ),
  AppFontOption(
    id: 'rounded',
    label: 'Rounded Sans',
    description: 'Softer, friendlier headings (e.g. Nunito).',
    fontFamily: 'Nunito',
  ),
  AppFontOption(
    id: 'tech',
    label: 'Tech Grotesk',
    description: 'Slightly futuristic geometric look.',
    fontFamily: 'SpaceGrotesk',
  ),
];

AppFontOption getFontById(String id) {
  return appFontOptions.firstWhere(
    (f) => f.id == id,
    orElse: () => appFontOptions.first,
  );
}

ThemeData _applyFontToTheme(ThemeData base, String? fontFamily) {
  if (fontFamily == null) return base;
  final updatedTextTheme = base.textTheme.apply(fontFamily: fontFamily);
  return base.copyWith(textTheme: updatedTextTheme);
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
  final savedThemeId = settingsBox.get('appThemeId', defaultValue: 'premium-futuristic') as String;
  appThemeIdNotifier.value = savedThemeId;
  final savedFontId = settingsBox.get('appFontId', defaultValue: 'system') as String;
  appFontIdNotifier.value = savedFontId;

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
        return ValueListenableBuilder<String>(
          valueListenable: appFontIdNotifier,
          builder: (_, String currentFontId, __) {
            return ValueListenableBuilder<double>(
              valueListenable: fontScaleNotifier,
              builder: (_, double currentFontScale, __) {
                final theme = getThemeById(currentThemeId);
                final font = getFontById(currentFontId);
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
                  theme: _applyFontToTheme(theme.lightTheme, font.fontFamily),
                  darkTheme: _applyFontToTheme(theme.darkTheme, font.fontFamily),
                  themeMode: theme.mode,
                  home: const HomePage(),
                );
              },
            );
          },
        );
      },
    );
  }
}