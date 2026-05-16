import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

// FFI Typedefs (Native)
typedef CreateFunc = Pointer<Void> Function();
typedef DestroyFunc = Void Function(Pointer<Void>);
typedef StartFunc = Int8 Function(Pointer<Void>, Int32);
typedef StopFunc = Void Function(Pointer<Void>);
typedef IsRunningFunc = Int8 Function(Pointer<Void>);
typedef DomainFunc = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef ClearFunc = Void Function(Pointer<Void>);
typedef SetUpstreamFunc = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef GetStatFunc = Int32 Function(Pointer<Void>);

// FFI Typedefs (Dart)
typedef CreateDart = Pointer<Void> Function();
typedef DestroyDart = void Function(Pointer<Void>);
typedef StartDart = int Function(Pointer<Void>, int);
typedef StopDart = void Function(Pointer<Void>);
typedef IsRunningDart = int Function(Pointer<Void>);
typedef DomainDart = void Function(Pointer<Void>, Pointer<Utf8>);
typedef ClearDart = void Function(Pointer<Void>);
typedef SetUpstreamDart = void Function(Pointer<Void>, Pointer<Utf8>);
typedef GetStatDart = int Function(Pointer<Void>);

class AdBlockerProvider with ChangeNotifier {
  Database? _db;
  Pointer<Void>? _blockerPtr;
  late DynamicLibrary _nativeLib;
  
  bool _isRunning = false;
  int _totalQueries = 0;
  int _blockedQueries = 0;
  String _upstreamDNS = '8.8.8.8';
  bool _isDoHBlocked = false;
  bool _isServiceInstalled = false;
  bool _isUpdating = false;
  String _statusMessage = '';
  
  List<Map<String, dynamic>> _domains = [];
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _sources = [];
  List<String> _whitelist = [];
  
  Timer? _refreshTimer;

  AdBlockerProvider() {
    _initNative();
    _initDatabase().then((_) => _loadData());
  }

  void _initNative() {
    try {
      final libraryPath = 'adblocker.dll';
      _nativeLib = DynamicLibrary.open(libraryPath);
      
      final create = _nativeLib.lookupFunction<CreateFunc, CreateDart>('adblocker_create');
      _blockerPtr = create();
    } catch (e) {
      debugPrint('Failed to load native library: $e');
    }
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

        // Default critical domains to ensure immediate protection
        final defaults = [
          'doubleclick.net', 'google-analytics.com', 'googlesyndication.com', 
          'googleadservices.com', 'adnxs.com', 'taboola.com', 'outbrain.com',
          'advertising.com', 'scorecardresearch.com', 'quantserve.com'
        ];
        for (var domain in defaults) {
          await db.insert('domains', {'domain': domain, 'source': 'system:defaults'}, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
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
    
    final clearD = _nativeLib.lookupFunction<ClearFunc, ClearDart>('adblocker_clear_domains');
    final addD = _nativeLib.lookupFunction<DomainFunc, DomainDart>('adblocker_add_domain');
    final clearW = _nativeLib.lookupFunction<ClearFunc, ClearDart>('adblocker_clear_whitelist');
    final addW = _nativeLib.lookupFunction<DomainFunc, DomainDart>('adblocker_add_whitelist');
    
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
    if (_blockerPtr == null) {
      _statusMessage = 'Native engine not loaded. Restart the app.';
      notifyListeners();
      return;
    }
    
    _statusMessage = 'Starting DNS engine on port 53...';
    notifyListeners();
    
    final start = _nativeLib.lookupFunction<StartFunc, StartDart>('adblocker_start');
    final result = start(_blockerPtr!, 53);
    
    if (result == 0) {
      _statusMessage = 'Failed to bind port 53. Run as Administrator!';
      notifyListeners();
      return;
    }
    
    // Configure Windows DNS to point to our local server
    _statusMessage = 'Configuring system DNS to 127.0.0.1...';
    notifyListeners();
    
    try {
      final dnsResult = await Process.run('powershell', [
        '-Command',
        r"Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ServerAddresses ('127.0.0.1') }"
      ]);
      
      if (dnsResult.exitCode != 0) {
        _statusMessage = 'DNS engine running but could not set system DNS. Run as Admin!';
        debugPrint('DNS config error: ${dnsResult.stderr}');
      } else {
        _statusMessage = 'Protection active. All DNS routed through AdMenii.';
      }
    } catch (e) {
      _statusMessage = 'DNS engine running but system DNS config failed: $e';
      debugPrint('DNS config error: $e');
    }
    
    _isRunning = true;
    _startRefreshTimer();
    notifyListeners();
  }

  Future<void> setUpstream(String dns) async {
    _upstreamDNS = dns;
    if (_blockerPtr != null) {
      final setU = _nativeLib.lookupFunction<SetUpstreamFunc, SetUpstreamDart>('adblocker_set_upstream');
      setU(_blockerPtr!, dns.toNativeUtf8());
    }
    notifyListeners();
  }
  
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isRunning) return;
      
      final getTotal = _nativeLib.lookupFunction<GetStatFunc, GetStatDart>('adblocker_get_total_queries');
      final getBlocked = _nativeLib.lookupFunction<GetStatFunc, GetStatDart>('adblocker_get_blocked_queries');
      
      _totalQueries = getTotal(_blockerPtr!);
      _blockedQueries = getBlocked(_blockerPtr!);
      
      final getLogs = _nativeLib.lookupFunction<Pointer<Utf8> Function(Pointer<Void>), Pointer<Utf8> Function(Pointer<Void>)>('adblocker_get_logs');
      final freeStr = _nativeLib.lookupFunction<Void Function(Pointer<Utf8>), void Function(Pointer<Utf8>)>('adblocker_free_string');
      
      final logsPtr = getLogs(_blockerPtr!);
      if (logsPtr != nullptr) {
        final logsJson = logsPtr.toDartString();
        _logs = List<Map<String, dynamic>>.from(jsonDecode(logsJson));
        _logs = _logs.reversed.toList(); // Newest first
        freeStr(logsPtr);
      }
      
      notifyListeners();
    });
  }

  Future<void> stopServer() async {
    if (_blockerPtr == null) return;
    
    final stop = _nativeLib.lookupFunction<StopFunc, StopDart>('adblocker_stop');
    stop(_blockerPtr!);
    
    // Restore system DNS back to automatic (DHCP)
    try {
      await Process.run('powershell', [
        '-Command',
        r"Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | ForEach-Object { Set-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -ResetServerAddresses }"
      ]);
    } catch (e) {
      debugPrint('Error restoring DNS: $e');
    }
    
    _isRunning = false;
    _statusMessage = 'Protection stopped. DNS restored to default.';
    _refreshTimer?.cancel();
    notifyListeners();
  }

  Future<void> addDomain(String domain, {String source = 'manual'}) async {
    if (_db == null) return;
    await _db!.insert('domains', {'domain': domain, 'source': source}, conflictAlgorithm: ConflictAlgorithm.ignore);
    if (_blockerPtr != null) {
      final addD = _nativeLib.lookupFunction<DomainFunc, DomainDart>('adblocker_add_domain');
      addD(_blockerPtr!, domain.toNativeUtf8());
    }
    _loadData();
  }

  Future<void> removeDomain(String domain) async {
    if (_db == null) return;
    await _db!.delete('domains', where: 'domain = ?', whereArgs: [domain]);
    if (_blockerPtr != null) {
      final removeD = _nativeLib.lookupFunction<DomainFunc, DomainDart>('adblocker_remove_domain');
      removeD(_blockerPtr!, domain.toNativeUtf8());
    }
    _loadData();
  }

  Future<void> addWhitelist(String domain) async {
    if (_db == null) return;
    await _db!.insert('whitelist', {'domain': domain}, conflictAlgorithm: ConflictAlgorithm.ignore);
    if (_blockerPtr != null) {
      final addW = _nativeLib.lookupFunction<DomainFunc, DomainDart>('adblocker_add_whitelist');
      addW(_blockerPtr!, domain.toNativeUtf8());
    }
    _loadData();
  }

  Future<void> removeWhitelist(String domain) async {
    if (_db == null) return;
    await _db!.delete('whitelist', where: 'domain = ?', whereArgs: [domain]);
    if (_blockerPtr != null) {
      final removeW = _nativeLib.lookupFunction<DomainFunc, DomainDart>('adblocker_remove_whitelist');
      removeW(_blockerPtr!, domain.toNativeUtf8());
    }
    _loadData();
  }

  Future<void> updateBlocklists() async {
    if (_isUpdating) return;
    _isUpdating = true;
    _statusMessage = 'Updating blocklists...';
    notifyListeners();
    
    try {
      final sources = await _db!.query('sources', where: 'is_active = 1');
      for (var source in sources) {
        await fetchBlocklist(source['url'] as String);
      }
      _statusMessage = 'Blocklists updated successfully.';
    } catch (e) {
      _statusMessage = 'Update failed: $e';
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }

  Future<void> fetchBlocklist(String url) async {
    if (_db == null) return;
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

  Future<void> installService() async {
    try {
      final exePath = join(File(Platform.resolvedExecutable).parent.path, 'admenii_backend.exe');
      if (!await File(exePath).exists()) {
        debugPrint('Backend executable not found at: $exePath');
        return;
      }

      // Use PowerShell to create the service (requires Admin)
      final script = '''
        \$serviceName = "AdMeniiDNS"
        \$exePath = "$exePath"
        if (Get-Service \$serviceName -ErrorAction SilentlyContinue) {
            sc.exe delete \$serviceName
        }
        sc.exe create \$serviceName binPath= "\$exePath --service" start= auto
        sc.exe start \$serviceName
        # Set system DNS to localhost
        Set-DnsClientServerAddress -InterfaceAlias (Get-NetAdapter | Where-Object {\$_.Status -eq "Up"}).InterfaceAlias -ServerAddresses ("127.0.0.1")
      ''';

      await Process.run('powershell', ['-Command', script]);
      _isServiceInstalled = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error installing service: $e');
    }
  }

  Future<void> toggleDoH(bool value) async {
    _isDoHBlocked = value;
    final dohDomains = [
      'dns.google',
      'cloudflare-dns.com',
      'dns.cloudflare.com',
      'doh.opendns.com',
      'dns.quad9.net',
      'dns.adguard.com',
      'dns-family.adguard.com',
      'doh.cleanbrowsing.org',
      'dns.nextdns.io',
      'doh.mullvad.net',
      'dns.controld.com',
      'doh.sb',
      'doh.libredns.gr',
      'use-application-dns.net',
      'doh.tiar.uk',
      'doh.centurylink.net'
    ];
    
    for (var domain in dohDomains) {
      if (value) {
        await addDomain(domain, source: 'system:doh_blocker');
      } else {
        await removeDomain(domain);
      }
    }
    notifyListeners();
  }

  // Getters
  bool get isRunning => _isRunning;
  bool get isDoHBlocked => _isDoHBlocked;
  bool get isServiceInstalled => _isServiceInstalled;
  bool get isUpdating => _isUpdating;
  String get statusMessage => _statusMessage;
  int get totalQueries => _totalQueries;
  int get blockedQueries => _blockedQueries;
  List<Map<String, dynamic>> get logs => _logs;
  String get upstreamDNS => _upstreamDNS;
  List<Map<String, dynamic>> get domains => _domains;
  List<Map<String, dynamic>> get sources => _sources;
  List<String> get whitelist => _whitelist;
  double get blockRate => _totalQueries > 0 ? (_blockedQueries / _totalQueries) * 100 : 0;
  int get totalDomains => _domains.length;

  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_blockerPtr != null) {
      try {
        final destroy = _nativeLib.lookupFunction<DestroyFunc, DestroyDart>('adblocker_destroy');
        destroy(_blockerPtr!);
      } catch (e) {
        debugPrint('Error destroying blocker: $e');
      }
    }
    super.dispose();
  }
}
