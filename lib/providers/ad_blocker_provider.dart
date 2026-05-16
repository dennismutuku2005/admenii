import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

typedef CreateFunc = Pointer<Void> Function(Pointer<Utf8>);
typedef CreateDart = Pointer<Void> Function(Pointer<Utf8>);

typedef DestroyFunc = Void Function(Pointer<Void>);
typedef DestroyDart = void Function(Pointer<Void>);

typedef StartFunc = Bool Function(Pointer<Void>, Int32);
typedef StartDart = bool Function(Pointer<Void>, int);

typedef StopFunc = Void Function(Pointer<Void>);
typedef StopDart = void Function(Pointer<Void>);

typedef IsRunningFunc = Bool Function(Pointer<Void>);
typedef IsRunningDart = bool Function(Pointer<Void>);

typedef AddDomainFunc = Bool Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef AddDomainDart = bool Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef RemoveDomainFunc = Bool Function(Pointer<Void>, Pointer<Utf8>);
typedef RemoveDomainDart = bool Function(Pointer<Void>, Pointer<Utf8>);

typedef GetJsonFunc = Pointer<Utf8> Function(Pointer<Void>);
typedef GetJsonDart = Pointer<Utf8> Function(Pointer<Void>);

typedef GetDomainsJsonFunc = Pointer<Utf8> Function(Pointer<Void>, Int32);
typedef GetDomainsJsonDart = Pointer<Utf8> Function(Pointer<Void>, int);

typedef SetUpstreamFunc = Void Function(Pointer<Void>, Pointer<Utf8>);
typedef SetUpstreamDart = void Function(Pointer<Void>, Pointer<Utf8>);

typedef FreeStringFunc = Void Function(Pointer<Utf8>);
typedef FreeStringDart = void Function(Pointer<Utf8>);

class AdBlockerProvider extends ChangeNotifier {
  late DynamicLibrary _nativeLib;
  Pointer<Void>? _blockerPtr;
  
  bool _isRunning = false;
  int _totalDomains = 0;
  int _totalQueries = 0;
  int _blockedQueries = 0;
  String _upstreamDNS = '8.8.8.8';
  List<Map<String, dynamic>> _domains = [];
  List<Map<String, dynamic>> _sources = [];
  List<String> _whitelist = [];
  Map<String, int> _categoryStats = {};
  
  Timer? _refreshTimer;
  
  AdBlockerProvider() {
    _initNative();
  }
  
  Future<void> _initNative() async {
    try {
      if (Platform.isWindows) {
        // Look in the same directory as the executable or in the build folder
        final exePath = Platform.resolvedExecutable;
        final exeDir = p.dirname(exePath);
        final dllPath = p.join(exeDir, 'adblocker.dll');
        
        if (File(dllPath).existsSync()) {
          _nativeLib = DynamicLibrary.open(dllPath);
        } else {
          // Fallback for development
          _nativeLib = DynamicLibrary.open('adblocker.dll');
        }
      } else {
        throw UnsupportedError('Only Windows is supported for now');
      }
      
      final create = _nativeLib.lookupFunction<CreateFunc, CreateDart>('adblocker_create');
      
      final appDir = await getApplicationSupportDirectory();
      final dbPath = p.join(appDir.path, 'admenii.db');
      
      _blockerPtr = create(dbPath.toNativeUtf8());
      
      _startRefreshTimer();
      _refreshStats();
    } catch (e) {
      debugPrint('Error initializing native library: $e');
    }
  }
  
  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _refreshStats();
    });
  }
  
  Future<void> _refreshStats() async {
    if (_blockerPtr == null || _blockerPtr == nullptr) return;
    
    try {
      final getStats = _nativeLib.lookupFunction<GetJsonFunc, GetJsonDart>('adblocker_get_stats_json');
      final statsPtr = getStats(_blockerPtr!);
      final statsJson = statsPtr.toDartString();
      final stats = jsonDecode(statsJson);
      
      _totalDomains = stats['total_domains'] ?? 0;
      _totalQueries = stats['total_queries'] ?? 0;
      _blockedQueries = stats['blocked_queries'] ?? 0;
      _categoryStats = Map<String, int>.from(stats['categories'] ?? {});
      
      final freeString = _nativeLib.lookupFunction<FreeStringFunc, FreeStringDart>('free_string');
      freeString(statsPtr);
      
      final isRunningFunc = _nativeLib.lookupFunction<IsRunningFunc, IsRunningDart>('adblocker_is_running');
      _isRunning = isRunningFunc(_blockerPtr!);
      
      final getUpstream = _nativeLib.lookupFunction<GetJsonFunc, GetJsonDart>('adblocker_get_upstream');
      final upstreamPtr = getUpstream(_blockerPtr!);
      _upstreamDNS = upstreamPtr.toDartString();
      freeString(upstreamPtr);
      
      final getDomains = _nativeLib.lookupFunction<GetDomainsJsonFunc, GetDomainsJsonDart>('adblocker_get_domains_json');
      final domainsPtr = getDomains(_blockerPtr!, 100);
      final domainsList = jsonDecode(domainsPtr.toDartString()) as List;
      _domains = domainsList.cast<Map<String, dynamic>>();
      freeString(domainsPtr);
      
      final getSources = _nativeLib.lookupFunction<GetJsonFunc, GetJsonDart>('adblocker_get_sources_json');
      final sourcesPtr = getSources(_blockerPtr!);
      final sourcesList = jsonDecode(sourcesPtr.toDartString()) as List;
      _sources = sourcesList.cast<Map<String, dynamic>>();
      freeString(sourcesPtr);

      final getWhitelist = _nativeLib.lookupFunction<GetJsonFunc, GetJsonDart>('database_get_whitelisted_json');
      final whitelistPtr = getWhitelist(_blockerPtr!);
      final whitelistList = jsonDecode(whitelistPtr.toDartString()) as List;
      _whitelist = whitelistList.cast<String>();
      freeString(whitelistPtr);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing stats: $e');
    }
  }
  
  Future<void> startServer() async {
    if (_blockerPtr == null || _blockerPtr == nullptr) return;
    
    final start = _nativeLib.lookupFunction<StartFunc, StartDart>('adblocker_start');
    await Future(() => start(_blockerPtr!, 53));
    _refreshStats();
  }
  
  Future<void> stopServer() async {
    if (_blockerPtr == null || _blockerPtr == nullptr) return;
    
    final stop = _nativeLib.lookupFunction<StopFunc, StopDart>('adblocker_stop');
    await Future(() => stop(_blockerPtr!));
    _refreshStats();
  }
  
  Future<void> updateBlocklists() async {
    if (_blockerPtr == null || _blockerPtr == nullptr) return;
    
    final update = _nativeLib.lookupFunction<StopFunc, StopDart>('adblocker_update_blocklists');
    await Future(() => update(_blockerPtr!));
    _refreshStats();
  }
  
  Future<void> addDomain(String domain, {String category = 'ads'}) async {
    if (_blockerPtr == null || _blockerPtr == nullptr) return;
    
    final add = _nativeLib.lookupFunction<AddDomainFunc, AddDomainDart>('adblocker_add_domain');
    await Future(() => add(_blockerPtr!, domain.toNativeUtf8(), category.toNativeUtf8()));
    _refreshStats();
  }
  
  Future<void> removeDomain(String domain) async {
    if (_blockerPtr == null || _blockerPtr == nullptr) return;
    
    final remove = _nativeLib.lookupFunction<RemoveDomainFunc, RemoveDomainDart>('adblocker_remove_domain');
    await Future(() => remove(_blockerPtr!, domain.toNativeUtf8()));
    _refreshStats();
  }
  
  Future<void> setUpstream(String dns) async {
    if (_blockerPtr == null || _blockerPtr == nullptr) return;
    
    final setUpstream = _nativeLib.lookupFunction<SetUpstreamFunc, SetUpstreamDart>('adblocker_set_upstream');
    await Future(() => setUpstream(_blockerPtr!, dns.toNativeUtf8()));
    _refreshStats();
  }

  Future<void> addWhitelist(String domain) async {
    if (_blockerPtr == null || _blockerPtr == nullptr) return;
    final add = _nativeLib.lookupFunction<RemoveDomainFunc, RemoveDomainDart>('database_add_whitelisted');
    await Future(() => add(_blockerPtr!, domain.toNativeUtf8()));
    _refreshStats();
  }

  Future<void> removeWhitelist(String domain) async {
    if (_blockerPtr == null || _blockerPtr == nullptr) return;
    final remove = _nativeLib.lookupFunction<RemoveDomainFunc, RemoveDomainDart>('database_remove_whitelisted');
    await Future(() => remove(_blockerPtr!, domain.toNativeUtf8()));
    _refreshStats();
  }
  
  bool get isRunning => _isRunning;
  int get totalDomains => _totalDomains;
  int get totalQueries => _totalQueries;
  int get blockedQueries => _blockedQueries;
  String get upstreamDNS => _upstreamDNS;
  List<Map<String, dynamic>> get domains => _domains;
  List<Map<String, dynamic>> get sources => _sources;
  List<String> get whitelist => _whitelist;
  Map<String, int> get categoryStats => _categoryStats;
  double get blockRate => _totalQueries > 0 ? (_blockedQueries / _totalQueries) * 100 : 0;
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    if (_blockerPtr != null && _blockerPtr != nullptr) {
      final destroy = _nativeLib.lookupFunction<DestroyFunc, DestroyDart>('adblocker_destroy');
      destroy(_blockerPtr!);
    }
    super.dispose();
  }
}
