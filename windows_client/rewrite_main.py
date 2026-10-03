import codecs

code = r"""import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'proxy_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF00FFC2),
          surface: const Color(0xFF2A2A3C),
        ),
      ),
      home: const ClientHomePage(),
    );
  }
}

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});
  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> with SingleTickerProviderStateMixin {
  final TextEditingController _ipController = TextEditingController();
  bool isConnected = false;
  String statusMessage = "Telefona bağlanmak için hazır.";
  String? currentGatewayIp;
  Timer? _pingTimer;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleDisconnectFromServer() {
    if (!isConnected) return;
    // KILL SWITCH: Proxy'i Windows'tan KALDIRMIYORUZ. 
    // Eger kaldirirsak, bilgisayar dogrudan hotspot'tan baglanir ve kotadan yer!
    if (mounted) {
      setState(() {
        statusMessage = "Telefon ile bağlantı koptu! (Kota koruması aktif: İnternet durduruldu)";
      });
    }
  }

  void _handleReconnectToServer() {
    if (mounted && statusMessage.contains("koptu")) {
      setState(() {
        statusMessage = "Bağlandı! Tüm trafik telefon üzerinden akıyor.\nProxy: ${currentGatewayIp}:8080";
      });
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!isConnected || currentGatewayIp == null) {
        timer.cancel();
        return;
      }
      try {
        final String deviceName = Uri.encodeComponent(Platform.localHostname);
        // Timeout 10 saniyeye cikarildi (Yogun indirmelerde ping gecikebilir)
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
        final request = await client.getUrl(Uri.parse('http://${currentGatewayIp}:8080/__netshare_ping?device=${deviceName}'));
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
      // Bağlantıyı kes
      setState(() {
        statusMessage = "Bağlantı kesiliyor...";
      });
      bool success = await ProxyManager.disableProxy();
      if (success) {
        setState(() {
          isConnected = false;
          statusMessage = "Bağlantı kesildi. Proxy kapatıldı.";
        });
        _pingTimer?.cancel();
      } else {
        setState(() {
          statusMessage = "Hata: Proxy kapatılamadı.";
        });
      }
    } else {
      // Bağlan
      String? ip = _ipController.text.trim();
      if (ip.isEmpty) {
        setState(() {
          statusMessage = "Telefon (Ağ Geçidi) aranıyor...";
        });
        ip = await ProxyManager.getGatewayIp();
      }

      if (ip == null || ip.isEmpty) {
        // Fallback
        ip = "192.168.43.1"; 
      }

      setState(() {
        currentGatewayIp = ip;
        statusMessage = "Telefona bağlanılıyor (${ip}:8080)...";
      });

      // Önce telefonun uygulaması aktif mi diye PING at
      bool isReachable = false;
      try {
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
        final request = await client.getUrl(Uri.parse('http://${ip}:8080/__netshare_ping'));
        final response = await request.close();
        if (response.statusCode == 200) {
          isReachable = true;
        }
        client.close();
      } catch (e) {
        isReachable = false;
      }

      if (!isReachable) {
        setState(() {
          statusMessage = "Bağlantı Başarısız! Telefon uygulamasına (${ip}) ulaşılamadı. Aynı ağda olduğunuzdan emin olun.";
        });
        return;
      }

      // Telefon ulaşılabiliyorsa proxy'i ayarla
      bool success = await ProxyManager.enableProxy(ip!, 8080);
      if (success) {
        setState(() {
          isConnected = true;
          statusMessage = "Bağlandı! Tüm trafik telefon üzerinden akıyor.\nProxy: ${ip}:8080";
        });
        _startPing();
      } else {
        setState(() {
          statusMessage = "Hata: Proxy Windows'a yazılamadı.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400,
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
                'NETSHARE PC CLIENT',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Operatör Sınırlarını Aşın',
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
                  hintText: 'Manuel IP (Örn: 10.18.73.167) - İsteğe Bağlı',
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
              const SizedBox(height: 30),
              
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
                            isConnected ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 50),
              Text(
                isConnected ? "BAĞLI" : "BAĞLANTI YOK",
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
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
"""

with codecs.open(r'C:\C_Projects\wifi_tether_client\lib\main.dart', 'w', 'utf-8') as f:
    f.write(code)

