import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/server_node.dart';

class SubscriptionParser {
  Future<List<ServerNode>> parse(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load subscription: ${response.statusCode}');
    }
    final decoded = utf8.decode(base64.decode(response.body.trim()));
    final lines = LineSplitter.split(decoded)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return lines.map(parseLink).whereType<ServerNode>().toList();
  }

  ServerNode? parseLink(String line) {
    if (line.startsWith('vmess://')) {
      final payload = line.replaceFirst('vmess://', '');
      final jsonString = utf8.decode(base64.decode(payload));
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      return ServerNode(
        name: data['ps'] as String? ?? 'VMess Node',
        address: data['add'] as String? ?? '',
        port: int.tryParse(data['port']?.toString() ?? ''),
        type: 'vmess',
        raw: line,
      );
    }
    if (line.startsWith('vless://') || line.startsWith('trojan://')) {
      final uri = Uri.parse(line);
      final type = uri.scheme;
      final name = uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : (uri.queryParameters['remarks'] ?? '${type.toUpperCase()} Node');
      return ServerNode(
        name: name,
        address: uri.host,
        port: uri.port,
        type: type,
        raw: line,
      );
    }
    if (line.startsWith('ss://')) {
      final uri = Uri.parse(line);
      final name = uri.fragment.isNotEmpty
          ? Uri.decodeComponent(uri.fragment)
          : 'Shadowsocks Node';
      final host = uri.host;
      final port = uri.port == 0 ? null : uri.port;
      if (host.isEmpty || port == null) return null;
      return ServerNode(
        name: name,
        address: host,
        port: port,
        type: 'shadowsocks',
        raw: line,
      );
    }
    return null;
  }
}
