import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          create: (_) => ThemeProvider(prefs),
        ),
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(
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
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final baseLight = ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF7F8FD),
            fontFamily: 'Vazir',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          );
          final baseDark = ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            fontFamily: 'Vazir',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF7C3AED),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          );

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'NeonRay',
            themeMode: theme.themeMode,
            theme: baseLight,
            darkTheme: baseDark,
            home: const NeonRayHome(),
          );
        },
      ),
    );
  }
}

class NeonRayHome extends StatefulWidget {
  const NeonRayHome({super.key});

  @override
  State<NeonRayHome> createState() => _NeonRayHomeState();
}

class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._prefs) {
    final saved = _prefs.getString(_prefKey);
    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.dark,
      );
    }
  }

  static const _prefKey = 'theme_mode';
  final SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _prefs.setString(_prefKey, _themeMode.name);
    notifyListeners();
  }
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
                        Text(
                          'Subscription URL',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
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
                        Text(
                          'Choose your exit node',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = context.read<ThemeProvider>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NeonRay',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cyberpunk V2Ray/Xray client',
              style: TextStyle(color: onSurface.withOpacity(0.7)),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Icon(Icons.shield_moon_outlined, color: onSurface.withOpacity(0.7)),
            ),
            const SizedBox(width: 12),
            IconButton(
              tooltip: 'Toggle theme',
              style: IconButton.styleFrom(
                backgroundColor:
                    isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
              ),
              onPressed: theme.toggleTheme,
              icon: Icon(
                theme.themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                color: onSurface,
              ),
            ),
          ],
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
        final colorScheme = Theme.of(context).colorScheme;
        final onSurface = colorScheme.onSurface;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _controller,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                hintText: 'https://example.com/subscription',
                hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
                filled: true,
                fillColor:
                    isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: colorScheme.secondary.withOpacity(0.4)),
                ),
              ),
              onChanged: provider.setSubscriptionUrl,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
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
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    final raw = data?.text?.trim();
                    if (raw == null || raw.isEmpty) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Clipboard is empty.')),
                      );
                      return;
                    }
                    final added = await provider.addServerFromLink(raw);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          added
                              ? 'Config added from clipboard'
                              : 'Clipboard content was not a supported config',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.paste_rounded),
                  label: const Text('Import from clipboard'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const _ManualServerSheet(),
                    );
                  },
                  icon: const Icon(Icons.add_link),
                  label: const Text('Add server manually'),
                ),
              ],
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
          final color = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No servers yet. Paste a subscription URL to populate the list.',
              textAlign: TextAlign.center,
              style: TextStyle(color: color),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${server.type.toUpperCase()} • ${server.address}:${server.port ?? ''}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
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

String _formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '--';
  final mbps = bytesPerSecond * 8 / 1000000;
  return '${mbps.toStringAsFixed(1)} Mbps';
}

String _formatData(int bytes) {
  if (bytes <= 0) return '--';
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '$bytes B';
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel();

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionProvider>(
      builder: (context, connection, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final onSurface = colorScheme.onSurface;
        final statusInfo = connection.liveStatus;

        Color accent;
        String label;
        switch (connection.status) {
          case ConnectionStatus.connected:
            accent = colorScheme.secondary;
            label = 'Connected';
            break;
          case ConnectionStatus.connecting:
            accent = Colors.amberAccent;
            label = 'Connecting…';
            break;
          case ConnectionStatus.disconnected:
          default:
            accent = onSurface.withOpacity(0.5);
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
                  Text(label, style: TextStyle(fontSize: 14, color: onSurface)),
                  const Spacer(),
                  Text(
                    connection.selectedServer?.type.toUpperCase() ?? '--',
                    style: TextStyle(color: onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Metric(
                    label: 'Uplink',
                    value: _formatSpeed(statusInfo.uploadSpeed),
                  ),
                  _Metric(
                    label: 'Downlink',
                    value: _formatSpeed(statusInfo.downloadSpeed),
                  ),
                  _Metric(
                    label: 'Duration',
                    value: statusInfo.duration,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Metric(
                    label: 'Uploaded',
                    value: _formatData(statusInfo.upload),
                  ),
                  _Metric(
                    label: 'Downloaded',
                    value: _formatData(statusInfo.download),
                  ),
                  _Metric(
                    label: 'Server',
                    value: connection.selectedServer?.name ?? '--',
                  ),
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: onSurface.withOpacity(0.6), fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: onSurface,
          ),
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
            children: [
              Icon(Icons.shield, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Secure NeonGlass VPN tunnel ready. Tap connect to breathe in the glow.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
              Icon(Icons.keyboard_double_arrow_up_rounded,
                  color: Theme.of(context).colorScheme.secondary),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white10 : Colors.black12;
    final backgroundColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.white.withOpacity(0.7);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF2F5FF),
      child: Stack(
        children: [
          _blob(
              _purple,
              isDark ? Colors.purpleAccent.withOpacity(0.35) : const Color(0xFFB794F4).withOpacity(0.45),
              280,
              const Offset(-0.2, -0.3)),
          _blob(
              _cyan,
              isDark ? Colors.cyanAccent.withOpacity(0.35) : const Color(0xFF5EEAD4).withOpacity(0.45),
              260,
              const Offset(0.6, -0.1)),
          _blob(
              _pink,
              isDark ? Colors.pinkAccent.withOpacity(0.35) : const Color(0xFFF9A8D4).withOpacity(0.45),
              300,
              const Offset(0.1, 0.4)),
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

class _ManualServerSheet extends StatefulWidget {
  const _ManualServerSheet();

  @override
  State<_ManualServerSheet> createState() => _ManualServerSheetState();
}

class _ManualServerSheetState extends State<_ManualServerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _portController = TextEditingController();
  final _secretController = TextEditingController();
  final _encryptionController = TextEditingController(text: 'aes-256-gcm');
  String _type = 'vless';

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _portController.dispose();
    _secretController.dispose();
    _encryptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add server manually',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: onSurface),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'vless', child: Text('VLESS')),
                  DropdownMenuItem(value: 'trojan', child: Text('Trojan')),
                  DropdownMenuItem(value: 'shadowsocks', child: Text('Shadowsocks')),
                ],
                decoration: const InputDecoration(labelText: 'Type'),
                onChanged: (value) {
                  if (value != null) setState(() => _type = value);
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name (optional)'),
              ),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Address is required' : null,
              ),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final port = int.tryParse(value ?? '');
                  if (port == null || port <= 0) {
                    return 'Enter a valid port';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _secretController,
                decoration: InputDecoration(
                  labelText: _type == 'shadowsocks'
                      ? 'Password'
                      : 'ID / Password',
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'A credential is required' : null,
              ),
              if (_type == 'shadowsocks')
                TextFormField(
                  controller: _encryptionController,
                  decoration: const InputDecoration(labelText: 'Encryption method'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Encryption is required' : null,
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Save server'),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    final raw = _buildLink();
                    final added = await context.read<SubscriptionProvider>().addServerFromLink(raw);
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          added ? 'Server saved' : 'Could not parse the provided details',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildLink() {
    final name = _nameController.text.trim().isEmpty
        ? '${_type.toUpperCase()} Node'
        : _nameController.text.trim();
    final encodedName = Uri.encodeComponent(name);
    final host = _addressController.text.trim();
    final port = _portController.text.trim();
    final secret = _secretController.text.trim();

    switch (_type) {
      case 'vless':
        return 'vless://$secret@$host:$port#${encodedName}';
      case 'trojan':
        return 'trojan://$secret@$host:$port#${encodedName}';
      case 'shadowsocks':
        final method = _encryptionController.text.trim();
        final encoded = base64.encode(utf8.encode('$method:$secret'));
        return 'ss://$encoded@$host:$port#${encodedName}';
      default:
        return '';
    }
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
