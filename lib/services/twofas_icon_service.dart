import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TwoFasIcon {
  final String id;
  final String name;
  final String url;
  final String type; // 'light' or 'dark'
  final int width;
  final int height;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TwoFasIcon({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TwoFasIcon.fromJson(Map<String, dynamic> json) {
    return TwoFasIcon(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      type: json['type'] ?? 'light',
      width: json['width'] ?? 120,
      height: json['height'] ?? 120,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'type': type,
        'width': width,
        'height': height,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class TwoFasIconService {
  static const String _baseUrl = 'https://api2.2fas.com/mobile/icons';
  static const String _cacheFileName = 'twofas_icons_cache.json';
  static const Duration _cacheValidDuration = Duration(days: 30);
  static const double _iconCoverageThreshold = 0.3;

  static List<TwoFasIcon> _cachedIcons = [];
  static DateTime? _lastCacheUpdate;
  static bool _isLoading = false;

  /// Preloads icons for specific services asynchronously (non-blocking)
  static Future<void> preloadIconsForServices(
      List<String> serviceNames, List<String> issuers) async {
    if (_isLoading) return; // Don't start another load

    // Load icons asynchronously in background
    _loadIconsInBackground(serviceNames, issuers);
  }

  /// Background loading of icons (non-blocking)
  static void _loadIconsInBackground(
      List<String> serviceNames, List<String> issuers) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      // Try to load from local cache first
      await _loadFromLocalCache();

      // If cache is invalid or we don't have icons for these services, fetch from API
      if (!_isCacheValid() || !_hasIconsForServices(serviceNames, issuers)) {
        await _fetchFromApi();
        await _saveToLocalCache();
      }
    } catch (e) {
      debugPrint('Background icon loading failed: $e');
    } finally {
      _isLoading = false;
    }
  }

  /// Check if we have icons for the specified services
  static bool _hasIconsForServices(
      List<String> serviceNames, List<String> issuers) {
    if (_cachedIcons.isEmpty) return false;

    // Check if we have reasonable coverage for the requested services
    final searchTerms =
        [...serviceNames, ...issuers].map((s) => s.toLowerCase()).toList();
    int foundCount = 0;

    for (final term in searchTerms) {
      if (term.isEmpty) continue;

      final hasIcon = _cachedIcons.any((icon) =>
          icon.name.toLowerCase().contains(term) ||
          term.contains(icon.name.toLowerCase()));

      if (hasIcon) foundCount++;
    }

    // If we found icons for at least 30% of services, consider it good enough
    return foundCount >= (searchTerms.length * _iconCoverageThreshold);
  }

  /// Gets available icons (loads from cache only, doesn't fetch from API)
  static Future<List<TwoFasIcon>> getAvailableIcons() async {
    if (_cachedIcons.isEmpty) {
      await _loadFromLocalCache();
    }
    return _cachedIcons;
  }

  /// Finds the best matching icon for a service
  static Future<TwoFasIcon?> findIconForService(
    String serviceName,
    String issuer, {
    bool preferDark = false,
  }) async {
    final icons = await getAvailableIcons();
    if (icons.isEmpty) return null;

    final preferredType = preferDark ? 'dark' : 'light';
    final searchTerms =
        [serviceName, issuer].map((s) => s.toLowerCase().trim()).toList();

    // Try exact matches first
    for (final term in searchTerms) {
      if (term.isEmpty) continue;

      final exactMatch = icons
          .where((icon) =>
              icon.name.toLowerCase() == term && icon.type == preferredType)
          .firstOrNull;

      if (exactMatch != null) return exactMatch;
    }

    // Try partial matches
    for (final term in searchTerms) {
      if (term.isEmpty) continue;

      final partialMatch = icons
          .where((icon) =>
              (icon.name.toLowerCase().contains(term) ||
                  term.contains(icon.name.toLowerCase())) &&
              icon.type == preferredType)
          .firstOrNull;

      if (partialMatch != null) return partialMatch;
    }

    // Try with opposite theme as fallback
    final fallbackType = preferDark ? 'light' : 'dark';
    for (final term in searchTerms) {
      if (term.isEmpty) continue;

      final fallbackMatch = icons
          .where((icon) =>
              icon.name.toLowerCase() == term && icon.type == fallbackType)
          .firstOrNull;

      if (fallbackMatch != null) return fallbackMatch;
    }

    return null;
  }

  /// Creates a widget to display a service icon
  static Widget buildServiceIcon(
    String serviceName,
    String issuer, {
    double size = 24.0,
    bool preferDark = false,
    Widget? fallback,
  }) {
    return FutureBuilder<TwoFasIcon?>(
      future: findIconForService(serviceName, issuer, preferDark: preferDark),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final icon = snapshot.data!;
          return CachedNetworkImage(
            imageUrl: icon.url,
            width: size,
            height: size,
            fit: BoxFit.contain,
            placeholder: (context, url) => SizedBox(
              width: size,
              height: size,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (context, url, error) =>
                fallback ?? _getDefaultIcon(serviceName, issuer, size),
          );
        }

        // Show fallback while loading or if no icon found
        return fallback ?? _getDefaultIcon(serviceName, issuer, size);
      },
    );
  }

  /// Creates a circular avatar with service icon
  static Widget buildServiceAvatar(
    String serviceName,
    String issuer, {
    double radius = 16.0,
    bool preferDark = false,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade100,
      child: buildServiceIcon(
        serviceName,
        issuer,
        size: radius * 1.2,
        preferDark: preferDark,
        fallback: Icon(
          Icons.security,
          size: radius * 0.8,
          color: Colors.blue,
        ),
      ),
    );
  }

  static Widget _getDefaultIcon(
      String serviceName, String issuer, double size) {
    // Simple fallback icon based on first letter
    final firstLetter = (serviceName.isNotEmpty
            ? serviceName
            : issuer.isNotEmpty
                ? issuer
                : 'S')
        .toUpperCase()
        .substring(0, 1);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
      ),
    );
  }

  static bool _isCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheValidDuration;
  }

  static Future<void> _fetchFromApi() async {
    debugPrint('Fetching 2FAS icons from API...');

    final response = await http.get(
      Uri.parse(_baseUrl),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      _cachedIcons = jsonList.map((json) => TwoFasIcon.fromJson(json)).toList();
      _lastCacheUpdate = DateTime.now();

      debugPrint('Successfully fetched ${_cachedIcons.length} 2FAS icon metadata entries');
    } else {
      throw HttpException('Failed to fetch icons: ${response.statusCode}');
    }
  }

  static Future<void> _loadFromLocalCache() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_cacheFileName');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final jsonData = jsonDecode(contents);

        _lastCacheUpdate = DateTime.tryParse(jsonData['cache_time'] ?? '');
        final List<dynamic> iconsList = jsonData['icons'] ?? [];
        _cachedIcons =
            iconsList.map((json) => TwoFasIcon.fromJson(json)).toList();

        debugPrint('Loaded ${_cachedIcons.length} icon metadata entries from local cache');
      }
    } catch (e) {
      debugPrint('Error loading icons from local cache: $e');
      _cachedIcons = [];
      _lastCacheUpdate = null;
    }
  }

  static Future<void> _saveToLocalCache() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_cacheFileName');

      final jsonData = {
        'cache_time': (_lastCacheUpdate ?? DateTime.now()).toIso8601String(),
        'icons': _cachedIcons.map((icon) => icon.toJson()).toList(),
      };

      await file.writeAsString(jsonEncode(jsonData));
      debugPrint('Saved ${_cachedIcons.length} icon metadata entries to local cache');
    } catch (e) {
      debugPrint('Error saving icons to local cache: $e');
    }
  }

  /// Force refresh icons from API
  static Future<void> refreshIcons() async {
    _lastCacheUpdate = null;
    _cachedIcons = [];
    await _fetchFromApi();
    await _saveToLocalCache();
  }

  /// Clear local cache
  static Future<void> clearCache() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_cacheFileName');

      if (await file.exists()) {
        await file.delete();
      }

      _cachedIcons = [];
      _lastCacheUpdate = null;

      debugPrint('Cleared 2FAS icons cache');
    } catch (e) {
      debugPrint('Error clearing icons cache: $e');
    }
  }
}
