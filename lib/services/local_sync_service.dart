import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/habit.dart';

class LocalSyncService {
  static HttpServer? _server;
  static RawDatagramSocket? _udpSocket;
  static Timer? _broadcastTimer;
  static StreamSubscription? _dbWatcher;

  static final Map<String, DateTime> _lastSyncTimes = {};
  static final List<String> _myIps = [];

  // Prevents the sync engine from triggering its own update loop
  static bool _isApplyingSync = false;

  static Future<void> start() async {
    await stop();

    final settings = Hive.box('settingsBox');
    final syncKey = settings.get('localSyncKey', defaultValue: '');
    if (syncKey.trim().isEmpty) return;

    // WATCHER: Increment our "Version Number" when the user manually changes the database
    final box = Hive.box<Habit>('habitsBox');
    _dbWatcher = box.watch().listen((_) {
      if (!_isApplyingSync) {
        int currentVersion = settings.get('syncVersion', defaultValue: 0);
        settings.put('syncVersion', currentVersion + 1);
        debugPrint('📝 DB Modified locally! New Version: ${currentVersion + 1}');
      }
    });

    try {
      _myIps.clear();
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          _myIps.add(addr.address);
        }
      }

      // 1. HTTP SERVER (Handles both PUSHing and PULLING data)
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 50550);
      _server!.listen((HttpRequest request) async {
        if (request.uri.path == '/sync' && request.method == 'POST') {
          // RECEIVE DATA PUSHED FROM ANOTHER DEVICE
          String content = await utf8.decoder.bind(request).join();
          Map<String, dynamic> payload = jsonDecode(content);
          int incomingVersion = payload['version'] ?? 0;
          int myVersion = settings.get('syncVersion', defaultValue: 0);

          if (incomingVersion > myVersion) {
            debugPrint('⬇️ Received PUSH. Incoming Version ($incomingVersion) > My Version ($myVersion). Updating...');
            _applyIncomingData(payload['habits'], incomingVersion);
          }
          request.response..statusCode = HttpStatus.ok..write('OK')..close();

        } else if (request.uri.path == '/pull' && request.method == 'GET') {
          // ANOTHER DEVICE IS ASKING FOR OUR DATA
          debugPrint('↗️ Peer requested a PULL. Sending our local database!');
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(_exportLocalDataAsJson())
            ..close();
        } else {
          request.response..statusCode = HttpStatus.notFound..close();
        }
      });

      // 2. UDP SOCKET (Discover peers and compare versions)
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 50551);
      _udpSocket!.broadcastEnabled = true;
      _udpSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          Datagram? datagram = _udpSocket!.receive();
          if (datagram != null) {
            String peerIp = datagram.address.address;
            if (_myIps.contains(peerIp) || peerIp == '127.0.0.1') return;

            String msg = utf8.decode(datagram.data);
            List<String> parts = msg.split(':');

            // Format: FITDY_PING:syncKey:versionNumber
            if (parts.length >= 3 && parts[0] == 'FITDY_PING' && parts[1] == syncKey) {
              int peerVersion = int.tryParse(parts[2]) ?? 0;
              int myVersion = settings.get('syncVersion', defaultValue: 0);

              if (myVersion > peerVersion) {
                // I have newer data. Push it to them!
                _pushDataToPeer(peerIp);
              } else if (myVersion < peerVersion) {
                // They have newer data. Pull it from them!
                _pullDataFromPeer(peerIp);
              }
            }
          }
        }
      });

      // 3. BROADCAST PING (Announce our version to the network)
      _broadcastTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        int myVersion = settings.get('syncVersion', defaultValue: 0);
        final pingMsg = utf8.encode('FITDY_PING:$syncKey:$myVersion');
        try {
          _udpSocket!.send(pingMsg, InternetAddress('255.255.255.255'), 50551);
        } catch (e) {}
      });

      debugPrint(' Local Sync Engine Started. Awaiting Pings...');
    } catch (e) {
      debugPrint(' Error starting Sync Service: $e');
    }
  }

  static Future<void> stop() async {
    _broadcastTimer?.cancel();
    _udpSocket?.close();
    await _server?.close();
    await _dbWatcher?.cancel();
  }

  // --- NETWORK HELPERS ---

  static String _exportLocalDataAsJson() {
    int myVersion = Hive.box('settingsBox').get('syncVersion', defaultValue: 0);
    final box = Hive.box<Habit>('habitsBox');

    final List<Map<String, dynamic>> exportData = box.values.map((h) => {
      'name': h.name,
      'description': h.description,
      'colorValue': h.colorValue,
      'iconCodePoint': h.iconCodePoint,
      'completedDays': h.completedDays.map((d) => d.toIso8601String()).toList(),
      'completionsPerDay': h.completionsPerDay,
      'categories': h.categories,
      'streakGoalInterval': h.streakGoalInterval,
      'allowExceeding': h.allowExceeding,
      'reminderDays': h.reminderDays,
    }).toList();

    return jsonEncode({'version': myVersion, 'habits': exportData});
  }

  static void _pushDataToPeer(String peerIp) async {
    if (_isOnCooldown(peerIp)) return;

    try {
      HttpClient client = HttpClient();
      HttpClientRequest request = await client.post(peerIp, 50550, '/sync');
      request.headers.set('content-type', 'application/json');
      request.add(utf8.encode(_exportLocalDataAsJson()));
      await request.close();
      client.close();
    } catch (e) {
      debugPrint(' Failed to push data: $e');
    }
  }

  static void _pullDataFromPeer(String peerIp) async {
    if (_isOnCooldown(peerIp)) return;

    try {
      HttpClient client = HttpClient();
      HttpClientRequest request = await client.get(peerIp, 50550, '/pull');
      HttpClientResponse response = await request.close();

      if (response.statusCode == 200) {
        String content = await utf8.decoder.bind(response).join();
        Map<String, dynamic> payload = jsonDecode(content);
        int incomingVersion = payload['version'] ?? 0;
        int myVersion = Hive.box('settingsBox').get('syncVersion', defaultValue: 0);

        if (incomingVersion > myVersion) {
          debugPrint(' Pulled newer database from peer! Updating...');
          _applyIncomingData(payload['habits'], incomingVersion);
        }
      }
      client.close();
    } catch (e) {
      debugPrint(' Failed to pull data: $e');
    }
  }

  static bool _isOnCooldown(String peerIp) {
    final now = DateTime.now();
    if (_lastSyncTimes.containsKey(peerIp) && now.difference(_lastSyncTimes[peerIp]!).inSeconds < 2) {
      return true;
    }
    _lastSyncTimes[peerIp] = now;
    return false;
  }

  // --- DATA MERGING ---

  static void _applyIncomingData(List<dynamic> incomingHabits, int incomingVersion) {
    try {
      _isApplyingSync = true;
      final box = Hive.box<Habit>('habitsBox');

      for (var item in incomingHabits) {
        String incomingName = item['name'];
        List<DateTime> incomingDates = (item['completedDays'] as List?)?.map((e) => DateTime.parse(e)).toList() ?? [];

        int existingIndex = box.values.toList().indexWhere((h) => h.name == incomingName);

        if (existingIndex >= 0) {
          Habit localHabit = box.getAt(existingIndex)!;

          // EXACT REPLACEMENT: Allows deleting/un-checking a day to sync correctly!
          localHabit.description = item['description'] ?? '';
          localHabit.colorValue = item['colorValue'] ?? 0xFF673AB7;
          localHabit.iconCodePoint = item['iconCodePoint'] ?? 0xe0b0;
          localHabit.completedDays = incomingDates;
          localHabit.completionsPerDay = item['completionsPerDay'] ?? 1;
          localHabit.categories = List<String>.from(item['categories'] ?? []);
          localHabit.streakGoalInterval = item['streakGoalInterval'] ?? 'None';
          localHabit.allowExceeding = item['allowExceeding'] ?? false;
          localHabit.reminderDays = List<int>.from(item['reminderDays'] ?? [1,2,3,4,5,6,7]);

          localHabit.save();
          box.put(localHabit.key, localHabit); // Force UI refresh
        } else {
          final newHabit = Habit(
            name: incomingName,
            description: item['description'] ?? '',
            colorValue: item['colorValue'] ?? 0xFF673AB7,
            iconCodePoint: item['iconCodePoint'] ?? 0xe0b0,
            completedDays: incomingDates,
            completionsPerDay: item['completionsPerDay'] ?? 1,
            categories: List<String>.from(item['categories'] ?? []),
            streakGoalInterval: item['streakGoalInterval'] ?? 'None',
            allowExceeding: item['allowExceeding'] ?? false,
            reminderDays: List<int>.from(item['reminderDays'] ?? [1,2,3,4,5,6,7]),
          );
          box.add(newHabit);
        }
      }

      // Update our logical clock to perfectly match the peer's clock
      Hive.box('settingsBox').put('syncVersion', incomingVersion);
      debugPrint('✨ Sync applied successfully! Dashboard updated.');

    } catch (e) {
      debugPrint(' Error applying sync data: $e');
    } finally {
      // Delay allowing new watcher updates until Hive finishes saving
      Future.delayed(const Duration(milliseconds: 500), () => _isApplyingSync = false);
    }
  }
}