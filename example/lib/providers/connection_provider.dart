import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_node.dart';

enum ConnectionStatus { disconnected, connecting, connected }

class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider(this._prefs) {
    _service = V2RayService(onStatusChanged: _handleStatusUpdate);
  }

  late final V2RayService _service;
  final SharedPreferences _prefs;

  ConnectionStatus status = ConnectionStatus.disconnected;
  ServerNode? selectedServer;
  V2RayStatus liveStatus = V2RayStatus();

  Future<void> selectServer(ServerNode server) async {
    selectedServer = server;
    await _prefs.setString('selected_server', jsonEncode(server.toJson()));
    notifyListeners();
  }

  Future<void> restoreSelectedServer() async {
    final saved = _prefs.getString('selected_server');
    if (saved != null) {
      final map = jsonDecode(saved) as Map<String, dynamic>;
      selectedServer = ServerNode.fromJson(map);
      notifyListeners();
    }
  }

  void _handleStatusUpdate(V2RayStatus statusUpdate) {
    liveStatus = statusUpdate;
    if (statusUpdate.state.toUpperCase() == 'CONNECTED' &&
        status != ConnectionStatus.connected) {
      status = ConnectionStatus.connected;
    }
    if (statusUpdate.state.toUpperCase() == 'DISCONNECTED' &&
        status != ConnectionStatus.disconnected) {
      status = ConnectionStatus.disconnected;
    }
    notifyListeners();
  }

  Future<void> connect() async {
    final server = selectedServer;
    if (server == null) return;
    status = ConnectionStatus.connecting;
    notifyListeners();
    try {
      await _service.start(server);
      status = ConnectionStatus.connected;
    } catch (_) {
      status = ConnectionStatus.disconnected;
      liveStatus = V2RayStatus(state: 'DISCONNECTED');
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    status = ConnectionStatus.disconnected;
    liveStatus = V2RayStatus(state: 'DISCONNECTED');
    notifyListeners();
    await _service.stop();
  }
}

class V2RayService {
  V2RayService({void Function(V2RayStatus status)? onStatusChanged})
      : _v2ray = V2ray(onStatusChanged: onStatusChanged ?? (_) {}) {
    _initialization = _v2ray.initialize(
      notificationIconResourceType: "mipmap",
      notificationIconResourceName: "ic_launcher",
    );
  }

  final V2ray _v2ray;
  late final Future<void> _initialization;

  Future<void> start(ServerNode server) async {
    final raw = server.raw;
    if (raw == null || raw.isEmpty) {
      throw Exception('Missing server configuration');
    }

    await _initialization;
    final parsed = V2ray.parseFromURL(raw);
    final remark = parsed.remark.isNotEmpty ? parsed.remark : server.name;

    final hasPermission = await _v2ray.requestPermission();
    if (!hasPermission) {
      throw Exception('VPN permission denied');
    }

    await _v2ray.startV2Ray(
      remark: remark,
      config: parsed.getFullConfiguration(),
      proxyOnly: false,
      bypassSubnets: null,
      notificationDisconnectButtonName: "DISCONNECT",
    );
  }

  Future<void> stop() async {
    await _initialization;
    await _v2ray.stopV2Ray();
  }
}
