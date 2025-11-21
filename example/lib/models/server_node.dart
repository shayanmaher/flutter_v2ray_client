class ServerNode {
  const ServerNode({
    required this.name,
    required this.address,
    required this.type,
    this.port,
    this.raw,
  });

  final String name;
  final String address;
  final String type;
  final int? port;
  final String? raw;

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'type': type,
        'port': port,
        'raw': raw,
      };

  factory ServerNode.fromJson(Map<String, dynamic> json) {
    return ServerNode(
      name: json['name'] as String? ?? 'Unknown',
      address: json['address'] as String? ?? '',
      type: json['type'] as String? ?? 'vmess',
      port: json['port'] as int?,
      raw: json['raw'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ServerNode && other.name == name && other.address == address;
  }

  @override
  int get hashCode => Object.hash(name, address, type, port);
}
