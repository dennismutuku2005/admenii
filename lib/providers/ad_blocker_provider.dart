import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

// FFI Typedefs
typedef CreateFunc = Pointer<Void> Function();
typedef DestroyFunc = Void Function(Pointer<Void>);
typedef StartFunc = Int8 Function(Pointer<Void>, Int32);
typedef StopFunc = Void Function(Pointer<Void>);
typedef IsRunningFunc = Int8 Function(Pointer<Void>);
typedef DomainFunc = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef ClearFunc = Void Function(Pointer<Void>);
typedef SetUpstreamFunc = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef GetStatFunc = Int32 Function(Pointer<Void>);

class AdBlockerProvider with ChangeNotifier {
  Database? _db;
  Pointer<Void>? _blockerPtr;
  late DynamicLibrary _nativeLib;
  
  bool _isRunning = false;
  int _totalQueries = 0;
  int _blockedQueries = 0;
  String _upstreamDNS = '8.8.8.8';
  
  List<Map<String, dynamic>> _domains = [];
  List<Map<String, dynamic>> _sources = [];
  List<String> _whitelist = [];
  
  Timer? _refreshTimer;

  AdBlockerProvider() {
    _initNative();
    _initDatabase().then((_) => _loadData());
  }

  void _initNative() {
    final libraryPath = 'adblocker.dll';
    _nativeLib = DynamicLibrary.open(libraryPath);
    
    final create = _nativeLib.lookupFunction<CreateFunc, CreateFunc>('adblocker_create');
    _blockerPtr = create();
  }

  Future<void> _initDatabase() async {
    final dbPath = join(await getDatabasesPath(), 'admenii_v2.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE domains (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            domain TEXT NOT NULL UNIQUE,
            source TEXT NOT NULL,
            hit_count INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE whitelist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            domain TEXT NOT NULL UNIQUE
          )
        ''');
        await db.execute('''
          CREATE TABLE sources (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            url TEXT NOT NULL UNIQUE,
            is_active INTEGER DEFAULT 1
          )
        ''');
        
        // Initial sources
        await db.insert('sources', {'name': 'StevenBlack Ads', 'url': 'https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts'});
      },
    );
  }

  Future<void> _loadData() async {
    if (_db == null) return;
    
    _domains = await _db!.query('domains', limit: 100);
    _sources = await _db!.query('sources');
    final whitelistRes = await _db!.query('whitelist');
    _whitelist = whitelistRes.map((e) => e['domain'] as String).toList();
    
    // Sync with C++
    _syncWithNative();
    notifyListeners();
  }

  Future<void> _syncWithNative() async {
    if (_blockerPtr == null) return;
    
    final clearD = _nativeLib.lookupFunction<ClearFunc, ClearFunc>('adblocker_clear_domains');
    final addD = _nativeLib.lookupFunction<DomainFunc, DomainFunc>('adblocker_add_domain');
    final clearW = _nativeLib.lookupFunction<ClearFunc, ClearFunc>('adblocker_clear_whitelist');
    final addW = _nativeLib.lookupFunction<DomainFunc, DomainFunc>('adblocker_add_whitelist');
    
    clearD(_blockerPtr!);
    final allDomains = await _db!.query('domains', columns: ['domain']);
    for (var row in allDomains) {
      addD(_blockerPtr!, (row['domain'] as String).toNativeUtf8());
    }
    
    clearW(_blockerPtr!);
    for (var domain in _whitelist) {
      addW(_blockerPtr!, domain.toNativeUtf8());
    }
  }

  Future<void> startServer() async {
    if (_blockerPtr == null) return;
    final start = _nativeLib.lookupFunction<StartFunc, StartFunc>('adblocker_start');
    if (start(_blockerPtr!, 53) != 0) {
      _isRunning = true;
      _startRefreshTimer();
      notifyListeners();
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isRunning) return;
      
      final getTotal = _nativeLib.lookupFunction<GetStatFunc, GetStatFunc>('adblocker_get_total_queries');
      final getBlocked = _nativeLib.lookupFunction<GetStatFunc, GetStatFunc>('adblocker_get_blocked_queries');
      
      _totalQueries = getTotal(_blockerPtr!);
      _blockedQueries = getBlocked(_blockerPtr!);
      notifyListeners();
    });
  }

  Future<void> stopServer() async {
    if (_blockerPtr == null) return;
    final stop = _nativeLib.lookupFunction<StopFunc, StopFunc>('adblocker_stop');
    stop(_blockerPtr!);
    _isRunning = false;
    _refreshTimer?.cancel();
    notifyListeners();
  }

  Future<void> addDomain(String domain, {String source = 'manual'}) async {
    await _db!.insert('domains', {'domain': domain, 'source': source}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final addD = _nativeLib.lookupFunction<DomainFunc, DomainFunc>('adblocker_add_domain');
    addD(_blockerPtr!, domain.toNativeUtf8());
    _loadData();
  }

  Future<void> removeDomain(String domain) async {
    await _db!.delete('domains', where: 'domain = ?', whereArgs: [domain]);
    final removeD = _nativeLib.lookupFunction<DomainFunc, DomainFunc>('adblocker_remove_domain');
    removeD(_blockerPtr!, domain.toNativeUtf8());
    _loadData();
  }

  Future<void> addWhitelist(String domain) async {
    await _db!.insert('whitelist', {'domain': domain}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final addW = _nativeLib.lookupFunction<DomainFunc, DomainFunc>('adblocker_add_whitelist');
    addW(_blockerPtr!, domain.toNativeUtf8());
    _loadData();
  }

  Future<void> removeWhitelist(String domain) async {
    await _db!.delete('whitelist', where: 'domain = ?', whereArgs: [domain]);
    final removeW = _nativeLib.lookupFunction<DomainFunc, DomainFunc>('adblocker_remove_whitelist');
    removeW(_blockerPtr!, domain.toNativeUtf8());
    _loadData();
  }

  Future<void> fetchBlocklist(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final lines = response.body.split('\n');
        final batch = _db!.batch();
        for (var line in lines) {
          if (line.startsWith('0.0.0.0 ') || line.startsWith('127.0.0.1 ')) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 2) {
              final domain = parts[1].trim();
              if (domain.isNotEmpty && domain != 'localhost') {
                batch.insert('domains', {'domain': domain, 'source': url}, conflictAlgorithm: ConflictAlgorithm.ignore);
              }
            }
          }
        }
        await batch.commit(noResult: true);
        await _syncWithNative();
        _loadData();
      }
    } catch (e) {
      debugPrint('Error fetching blocklist: $e');
    }
  }

  // Getters
  bool get isRunning => _isRunning;
  int get totalQueries => _totalQueries;
  int get blockedQueries => _blockedQueries;
  String get upstreamDNS => _upstreamDNS;
  List<Map<String, dynamic>> get domains => _domains;
  List<Map<String, dynamic>> get sources => _sources;
  List<String> get whitelist => _whitelist;
  double get blockRate => _totalQueries > 0 ? (_blockedQueries / _totalQueries) * 100 : 0;
  int get totalDomains => _domains.length; // This is limited in UI, would need a separate count query for real total

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_blockerPtr != null) {
      final destroy = _nativeLib.lookupFunction<DestroyFunc, DestroyFunc>('adblocker_destroy');
      destroy(_blockerPtr!);
    }
    super.dispose();
  }
}
