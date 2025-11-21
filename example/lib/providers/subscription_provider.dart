import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_node.dart';
import '../parsers/subscription_parser.dart';

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider(this._parser, this._prefs);

  final SubscriptionParser _parser;
  final SharedPreferences _prefs;

  String subscriptionUrl = '';
  bool isLoading = false;
  List<ServerNode> servers = [];

  Future<bool> addServerFromLink(String raw) async {
    final parsed = _parser.parseLink(raw.trim());
    if (parsed == null) return false;
    servers = _mergeServers([parsed]);
    await _persistServers();
    notifyListeners();
    return true;
  }

  void setSubscriptionUrl(String value) {
    subscriptionUrl = value.trim();
    _prefs.setString('subscription_url', subscriptionUrl);
    notifyListeners();
  }

  Future<void> restoreState() async {
    subscriptionUrl = _prefs.getString('subscription_url') ?? '';
    final savedServers = _prefs.getString('servers_cache');
    if (savedServers != null) {
      final list = (jsonDecode(savedServers) as List)
          .whereType<Map<String, dynamic>>()
          .map(ServerNode.fromJson)
          .toList();
      servers = list;
    }
    notifyListeners();
  }

  Future<void> fetchServers() async {
    if (subscriptionUrl.isEmpty) return;
    isLoading = true;
    notifyListeners();
    try {
      final fetched = await _parser.parse(subscriptionUrl);
      servers = _mergeServers(fetched);
      await _persistServers();
    } catch (_) {
      // Keep existing servers on failure.
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  List<ServerNode> _mergeServers(List<ServerNode> incoming) {
    final merged = [...servers];
    for (final server in incoming) {
      final exists = merged.any((s) =>
          (server.raw != null && server.raw == s.raw) ||
          (s.address == server.address && s.type == server.type && s.port == server.port));
      if (!exists) {
        merged.add(server);
      }
    }
    return merged;
  }

  Future<void> _persistServers() async {
    await _prefs.setString(
      'servers_cache',
      jsonEncode(servers.map((s) => s.toJson()).toList()),
    );
  }
}
