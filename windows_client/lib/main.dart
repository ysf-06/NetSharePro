import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'proxy_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(600, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'NetShare Pro',
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await ProxyManager.disableProxy(); // Reset on start
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetShare Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FFC2),
          secondary: Color(0xFF008B8B),
          background: Color(0xFF1E1E2C),
          surface: Color(0xFF2D2D44),
        ),
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        useMaterial3: true,
      ),
      home: const ConnectionScreen(),
    );
  }
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> with SingleTickerProviderStateMixin, TrayListener, WindowListener {
  bool isConnected = false;
  String statusMessage = "Baglanmaya hazir.";
  String? currentGatewayIp;
  
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  Timer? _pingTimer;
  
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  
  bool _networkLockEnabled = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initSystemTray();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _loadGateway();
  }
  
  Future<void> _loadGateway() async {
    String? ip = await ProxyManager.getGatewayIp();
    if (ip != null) {
      _ipController.text = ip;
    }
  }

  
  Future<void> _initSystemTray() async {
    await trayManager.setIcon(
      Platform.isWindows ? '${File(Platform.resolvedExecutable).parent.path}\\app_icon.ico' : 'assets/app_icon.png',
    );
    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Goster',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit_app',
          label: 'Cikis',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      windowManager.hide();
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      windowManager.destroy();
      exit(0);
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _pingTimer?.cancel();
    _pulseController.dispose();
    _ipController.dispose();
    _pinController.dispose();
    super.dispose();
  }


  void _handleDisconnectFromServer() {
    if (!isConnected) return;
    
    if (_networkLockEnabled) {
        setState(() {
            statusMessage = "BAGLANTI KOPTU! Zirhli Ag Kilidi Devrede (Trafik Kesildi).";
        });
    } else {
        ProxyManager.disableProxy();
        setState(() {
          isConnected = false;
          statusMessage = "Baglanti Koptu. Proxy Kapatildi.";
        });
        _pingTimer?.cancel();
    }
  }

  void _handleReconnectToServer() {
    if (!isConnected) return;
    setState(() {
      statusMessage = "Baglandi! Tum trafik telefon uzerinden akiyor.\nSOCKS5 Proxy: ${currentGatewayIp}:8080";
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
        final request = await client.getUrl(Uri.parse('http://${currentGatewayIp}:8081/__netshare_ping'));
        final response = await request.close();
        if (response.statusCode != 200) {
          _handleDisconnectFromServer();
        } else {
          _handleReconnectToServer();
        }
        client.close();
      } catch (e) {
        _handleDisconnectFromServer();
      }
    });
  }

  Future<void> toggleConnection() async {
    if (isConnected) {
      setState(() {
        statusMessage = "Baglanti kesiliyor...";
      });
      bool success = await ProxyManager.disableProxy();
      if (success) {
        setState(() {
          isConnected = false;
          statusMessage = "Baglanti kesildi. Proxy kapatildi.";
        });
        _pingTimer?.cancel();
      } else {
        setState(() {
          statusMessage = "Hata: Proxy kapatilamadi.";
        });
      }
    } else {
      String? ip = _ipController.text.trim();
      String pin = _pinController.text.trim();
      
      if (ip.isEmpty) {
        ip = await ProxyManager.getGatewayIp();
      }
      if (ip == null || ip.isEmpty) ip = "192.168.43.1"; 

      if (pin.isEmpty) {
          setState(() { statusMessage = "Lutfen Guvenlik PIN'ini girin!"; });
          return;
      }

      setState(() {
        currentGatewayIp = ip;
        statusMessage = "Telefona baglaniliyor (${ip}:8080)...";
      });

      bool isReachable = false;
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
        final request = await client.getUrl(Uri.parse('http://${ip}:8081/__netshare_auth?pin=${pin}'));
        final response = await request.close();
        if (response.statusCode == 200) {
          isReachable = true;
        } else {
          setState(() {
            statusMessage = "HATA: Guvenlik PIN'i yanlis veya erisim reddedildi!";
          });
          client.close();
          return;
        }
        client.close();
      } catch (e) {
        isReachable = false;
      }

      if (!isReachable) {
        setState(() {
          statusMessage = "Baglanti Basarisiz! Telefon uygulamasina (${ip}) ulasilamadi.";
        });
        return;
      }

      bool success = await ProxyManager.enableProxy(ip, 8080);
      if (success) {
        setState(() {
          isConnected = true;
          statusMessage = "Baglandi! Korumali SOCKS5 Aktif.\nProxy: ${ip}:8080";
        });
        _startPing();
      } else {
        setState(() {
          statusMessage = "Hata: Windows Proxy ayarlanamadi.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: isConnected ? Colors.green.withOpacity(0.2) : Colors.black26,
                blurRadius: 30,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NETSHARE PRO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'SOCKS5 ve Guvenli Baglanti',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ipController,
                enabled: !isConnected,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'IP Adresi (Orn: 192.168.43.1)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pinController,
                enabled: !isConnected,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Guvenlik PIN (4 Haneli)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                textAlign: TextAlign.center,
                maxLength: 4,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text("Zirhli Ag Kilidi (Kill-Switch)", style: TextStyle(color: Colors.white70)),
                value: _networkLockEnabled,
                onChanged: isConnected ? null : (val) {
                    setState(() { _networkLockEnabled = val ?? true; });
                },
                controlAffinity: ListTileControlAffinity.leading,
                checkColor: Colors.black,
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              
              // Animasyonlu Buton
              GestureDetector(
                onTap: toggleConnection,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: isConnected ? _scaleAnimation.value : 1.0,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: isConnected 
                              ? [const Color(0xFF00FFC2), const Color(0xFF008B8B)]
                              : [const Color(0xFF4A4A6A), const Color(0xFF2D2D44)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isConnected 
                                ? const Color(0xFF00FFC2).withOpacity(0.5) 
                                : Colors.black45,
                              blurRadius: isConnected ? 40 : 15,
                              spreadRadius: isConnected ? 10 : 0,
                            )
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            isConnected ? Icons.security : Icons.security_outlined,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 30),
              Text(
                isConnected ? "BAGLI" : "BAGLANTI YOK",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isConnected ? const Color(0xFF00FFC2) : Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: statusMessage.contains("KOPTU") ? Colors.redAccent : Colors.white70,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
