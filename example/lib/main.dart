import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(NeonRayApp(prefs: prefs));
}

class NeonRayApp extends StatelessWidget {
  const NeonRayApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(
            V2RayService(),
            prefs,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider(
            SubscriptionParser(),
            prefs,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NeonRay',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          fontFamily: 'Vazir',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C3AED),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const NeonRayHome(),
      ),
    );
  }
}

class NeonRayHome extends StatefulWidget {
  const NeonRayHome({super.key});

  @override
  State<NeonRayHome> createState() => _NeonRayHomeState();
}

class _NeonRayHomeState extends State<NeonRayHome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
      lowerBound: 0.5,
      upperBound: 1,
    )..repeat(reverse: true);

    final subProvider = context.read<SubscriptionProvider>();
    subProvider.restoreState();
    final connection = context.read<ConnectionProvider>();
    connection.restoreSelectedServer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Safety check

      final subProvider = context.read<SubscriptionProvider>();
      subProvider.restoreState();

      final connection = context.read<ConnectionProvider>();
      connection.restoreSelectedServer();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Header(),
                  const SizedBox(height: 24),
                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Subscription URL',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        _SubscriptionField(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Text(
                          'Choose your exit node',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        const _ServerList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ConnectButton(glowController: _glowController),
                  const SizedBox(height: 20),
                  const _StatusPanel(),
                ],
              ),
            ),
          ),
          const _BottomSheetStatus(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'NeonRay',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Cyberpunk V2Ray/Xray client',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: const Icon(Icons.shield_moon_outlined, color: Colors.white70),
        ),
      ],
    );
  }
}

class _SubscriptionField extends StatefulWidget {
  const _SubscriptionField();

  @override
  State<_SubscriptionField> createState() => _SubscriptionFieldState();
}

class _SubscriptionFieldState extends State<_SubscriptionField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SubscriptionProvider>();
    _controller = TextEditingController(text: provider.subscriptionUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://example.com/subscription',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.white10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.cyanAccent.withOpacity(0.3)),
                ),
              ),
              onChanged: provider.setSubscriptionUrl,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        await provider.fetchServers();
                        if (!mounted) return;
                        final connection = context.read<ConnectionProvider>();
                        if (provider.servers.isNotEmpty) {
                          connection.selectServer(provider.servers.first);
                        }
                      },
                icon: provider.isLoading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(provider.isLoading ? 'Updating…' : 'Sync Subscription'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ServerList extends StatelessWidget {
  const _ServerList();

  @override
  Widget build(BuildContext context) {
    return Consumer2<SubscriptionProvider, ConnectionProvider>(
      builder: (context, subscription, connection, _) {
        if (subscription.servers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No servers yet. Paste a subscription URL to populate the list.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subscription.servers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final server = subscription.servers[index];
            final isSelected = connection.selectedServer == server;
            return _GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.pinkAccent.withOpacity(0.8),
                          Colors.cyanAccent.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: const Icon(Icons.wifi_lock, color: Colors.white70),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${server.type.toUpperCase()} • ${server.address}:${server.port ?? ''}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      connection.selectServer(server);
                    },
                    icon: Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.cyanAccent : Colors.white38,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.glowController});

  final AnimationController glowController;

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connection, _) {
        final status = connection.status;
        final isActive =
            status == ConnectionStatus.connecting || status == ConnectionStatus.connected;
        return Center(
          child: GestureDetector(
            onTap: connection.selectedServer == null
                ? null
                : () {
                    if (status == ConnectionStatus.connected) {
                      connection.disconnect();
                    } else {
                      connection.connect();
                    }
                  },
            child: AnimatedBuilder(
              animation: glowController,
              builder: (context, child) {
                final glow = glowController.value * (isActive ? 40 : 18);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  height: 180,
                  width: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF22D3EE), Color(0xFF6366F1), Color(0xFFEC4899)],
                      center: Alignment(-0.2, -0.2),
                      radius: 0.9,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(isActive ? 0.5 : 0.2),
                        blurRadius: glow,
                        spreadRadius: glow / 3,
                      ),
                    ],
                    border: Border.all(color: Colors.white10, width: 1.5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isActive ? 'Disconnect' : 'Connect',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          connection.selectedServer?.name ?? 'Select a server',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connection, _) {
        Color accent;
        String label;
        switch (connection.status) {
          case ConnectionStatus.connected:
            accent = Colors.cyanAccent;
            label = 'Connected';
            break;
          case ConnectionStatus.connecting:
            accent = Colors.amberAccent;
            label = 'Connecting…';
            break;
          case ConnectionStatus.disconnected:
          default:
            accent = Colors.white54;
            label = 'Disconnected';
        }
        return _GlassCard(
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 10,
                    width: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(fontSize: 14)),
                  const Spacer(),
                  Text(
                    connection.selectedServer?.type.toUpperCase() ?? '--',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _Metric(label: 'Uplink', value: '12.4 mbps'),
                  _Metric(label: 'Downlink', value: '56.7 mbps'),
                  _Metric(label: 'Latency', value: '48 ms'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

class _BottomSheetStatus extends StatelessWidget {
  const _BottomSheetStatus();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: const [
              Icon(Icons.shield, color: Colors.white70),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Secure NeonGlass VPN tunnel ready. Tap connect to breathe in the glow.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Icon(Icons.keyboard_double_arrow_up_rounded, color: Colors.cyanAccent),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white10),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AmbientBackground extends StatefulWidget {
  const _AmbientBackground();

  @override
  State<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<_AmbientBackground>
    with TickerProviderStateMixin {
  late final AnimationController _purple;
  late final AnimationController _cyan;
  late final AnimationController _pink;

  @override
  void initState() {
    super.initState();
    _purple = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
    _cyan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat(reverse: true);
    _pink = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _purple.dispose();
    _cyan.dispose();
    _pink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      child: Stack(
        children: [
          _blob(_purple, Colors.purpleAccent.withOpacity(0.35), 280, const Offset(-0.2, -0.3)),
          _blob(_cyan, Colors.cyanAccent.withOpacity(0.35), 260, const Offset(0.6, -0.1)),
          _blob(_pink, Colors.pinkAccent.withOpacity(0.35), 300, const Offset(0.1, 0.4)),
        ],
      ),
    );
  }

  Widget _blob(
    AnimationController controller,
    Color color,
    double size,
    Offset alignment,
  ) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final dx = (alignment.dx + (controller.value - 0.5) * 0.2).clamp(-1.0, 1.0);
        final dy = (alignment.dy + (controller.value - 0.5) * 0.2).clamp(-1.0, 1.0);
        return Align(
          alignment: Alignment(dx, dy),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

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

enum ConnectionStatus { disconnected, connecting, connected }

class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider(this._service, this._prefs);

  final V2RayService _service;
  final SharedPreferences _prefs;

  ConnectionStatus status = ConnectionStatus.disconnected;
  ServerNode? selectedServer;

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

  Future<void> connect() async {
    final server = selectedServer;
    if (server == null) return;
    status = ConnectionStatus.connecting;
    notifyListeners();
    await _service.start(server);
    status = ConnectionStatus.connected;
    notifyListeners();
  }

  Future<void> disconnect() async {
    status = ConnectionStatus.disconnected;
    notifyListeners();
    await _service.stop();
  }
}

class V2RayService {
  Future<void> start(ServerNode server) async {
    await Future.delayed(const Duration(seconds: 2));
    // Placeholder for flutter_v2ray start logic.
  }

  Future<void> stop() async {
    await Future.delayed(const Duration(seconds: 1));
    // Placeholder for flutter_v2ray stop logic.
  }
}

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

    return lines.map(_parseLine).whereType<ServerNode>().toList();
  }

  ServerNode? _parseLine(String line) {
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
    return null;
  }
}

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionProvider(this._parser, this._prefs);

  final SubscriptionParser _parser;
  final SharedPreferences _prefs;

  String subscriptionUrl = '';
  bool isLoading = false;
  List<ServerNode> servers = [];

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
      servers = await _parser.parse(subscriptionUrl);
      await _prefs.setString(
        'servers_cache',
        jsonEncode(servers.map((s) => s.toJson()).toList()),
      );
    } catch (_) {
      servers = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
