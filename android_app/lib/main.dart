import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'socks5_proxy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'proxy_service_channel',
    'Proxy Service',
    description: 'This channel is used for proxy service notifications.',
    importance: Importance.low,
  );
  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'proxy_service_channel',
      initialNotificationTitle: 'NetShare Pro',
      initialNotificationContent: 'Ağ koruması aktif',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetShare Pro',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.tealAccent,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool _isRunning = false;
  String _ipAddress = "IP Bekleniyor...";
  final int _port = 8080;
  String _pinCode = "";
  
  bool _adBlockEnabled = false;
  int? _speedLimit;

  Socks5Proxy? _proxyServer;
  HttpServer? _pingServer;
  
  List<FlSpot> downloadData = [];
  List<FlSpot> uploadData = [];
  double timeX = 0;
  Timer? _graphTimer;
  int _lastTotalDown = 0;
  int _lastTotalUp = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getIpAddress();
    _pinCode = (1000 + Random().nextInt(9000)).toString();
  }

  @override
  void dispose() {
    _graphTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _stopServer();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _stopServer();
      final service = FlutterBackgroundService();
      service.invoke("stopService");
    }
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
  }

  Future<void> _getIpAddress() async {
    String foundIp = "IP Bulunamadi";
    
    try {
      List<NetworkInterface> interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      
      for (var interface in interfaces) {
        if (interface.name.toLowerCase().contains('wlan') || interface.name.toLowerCase().contains('ap')) {
          for (var addr in interface.addresses) {
            if (addr.address.startsWith('192.168.') || addr.address.startsWith('10.')) {
              foundIp = addr.address;
              break;
            }
          }
        }
      }
      
      if (foundIp == "IP Bulunamadi") {
        for (var interface in interfaces) {
           for (var addr in interface.addresses) {
             if (addr.address.startsWith('192.168.') || addr.address.startsWith('10.')) {
                 foundIp = addr.address;
                 break;
             }
           }
        }
      }
    } catch (e) {
      print("Error getting IP: $e");
    }
    
    if (foundIp == "IP Bulunamadi") {
        final info = NetworkInfo();
        String? wifiIP = await info.getWifiIP();
        foundIp = wifiIP ?? "IP Bulunamadi";
    }

    setState(() {
      _ipAddress = foundIp;
    });
  }

  void _startServer() async {
    await _getIpAddress();
    if (_ipAddress == "IP Bulunamadi") return;

    _proxyServer = Socks5Proxy(port: _port);
    _proxyServer!.adBlockEnabled = _adBlockEnabled;
    _proxyServer!.speedLimitBytesPerSec = _speedLimit;
    
    _proxyServer!.onStatsUpdated = () {
      // Do not setState here heavily to avoid UI lag, we update graph periodically.
    };
    _proxyServer!.onUrlVisited = () {
      if (mounted) setState(() {});
    };
    await _proxyServer!.start();
    
    _pingServer = await HttpServer.bind(InternetAddress.anyIPv4, 8081);
    _pingServer!.listen((HttpRequest request) {
      final clientIp = request.connectionInfo?.remoteAddress.address ?? '';
      if (request.uri.path == '/__netshare_auth') {
        final pin = request.uri.queryParameters['pin'];
        if (pin == _pinCode) {
          _proxyServer!.authenticatedIps.add(clientIp);
          request.response.statusCode = HttpStatus.ok;
          request.response.write('auth_success');
        } else {
          request.response.statusCode = HttpStatus.forbidden;
          request.response.write('auth_failed');
        }
        request.response.close();
      } else if (request.uri.path == '/__netshare_ping') {
        if (_proxyServer!.authenticatedIps.contains(clientIp)) {
            request.response.statusCode = HttpStatus.ok;
            request.response.write('pong');
        } else {
            request.response.statusCode = HttpStatus.forbidden;
        }
        request.response.close();
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
      }
    });

    final service = FlutterBackgroundService();
    await service.startService();
    
    // Start Graph Timer
    timeX = 0;
    downloadData.clear();
    uploadData.clear();
    _lastTotalDown = 0;
    _lastTotalUp = 0;
    
    _graphTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
       if (_proxyServer != null && mounted) {
          int totalDown = 0;
          int totalUp = 0;
          for (var client in _proxyServer!.clients.values) {
              totalDown += client.bytesDownloaded;
              totalUp += client.bytesUploaded;
          }
          
          double downSpeed = (totalDown - _lastTotalDown) / 1024.0; // KB/s
          double upSpeed = (totalUp - _lastTotalUp) / 1024.0; // KB/s
          
          _lastTotalDown = totalDown;
          _lastTotalUp = totalUp;
          
          setState(() {
              timeX += 1;
              downloadData.add(FlSpot(timeX, downSpeed));
              uploadData.add(FlSpot(timeX, upSpeed));
              if (downloadData.length > 20) {
                 downloadData.removeAt(0);
                 uploadData.removeAt(0);
              }
          });
       }
    });

    setState(() {
      _isRunning = true;
    });
  }

  void _stopServer() {
    _proxyServer?.stop();
    _pingServer?.close(force: true);
    final service = FlutterBackgroundService();
    service.invoke("stopService");
    
    _graphTimer?.cancel();
    
    setState(() {
      _isRunning = false;
    });
  }
  
  void _setQuotaDialog(ClientSession session) {
    TextEditingController controller = TextEditingController();
    showDialog(context: context, builder: (context) {
       return AlertDialog(
         title: const Text('Kota Sınırı (MB)'),
         content: TextField(
           controller: controller,
           keyboardType: TextInputType.number,
           decoration: const InputDecoration(hintText: "Örn: 500"),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
           TextButton(onPressed: () {
             if (controller.text.isNotEmpty) {
               setState(() {
                  session.quotaLimit = int.parse(controller.text) * 1024 * 1024;
               });
             }
             Navigator.pop(context);
           }, child: const Text("Kaydet")),
         ]
       );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NetShare Pro', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
                  ]
                ),
                child: Column(
                  children: [
                    Icon(
                      _isRunning ? Icons.shield : Icons.shield_outlined, 
                      size: 60, 
                      color: _isRunning ? Colors.blueAccent : Colors.grey
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isRunning ? "Bağlantı Aktif" : "Bağlantı Kapalı",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _isRunning ? Colors.white : Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Text("IP: $_ipAddress\nPort: $_port", style: const TextStyle(fontSize: 16, color: Colors.white70)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                      child: Text("Güvenlik PIN: $_pinCode", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.orangeAccent)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // AD BLOCKER TOGGLE
              Container(
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)),
                child: SwitchListTile(
                  title: const Text("Reklam Engelleyici (Ad-Block)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Bilinen reklam sunucularını ağ düzeyinde engeller", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: _adBlockEnabled,
                  activeColor: Colors.deepPurpleAccent,
                  onChanged: (val) {
                     setState(() {
                         _adBlockEnabled = val;
                         if (_proxyServer != null) {
                            _proxyServer!.adBlockEnabled = val;
                         }
                     });
                  },
                ),
              ),
              const SizedBox(height: 15),
              
              // SPEED LIMIT DROPDOWN
              Container(
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    value: _speedLimit,
                    hint: const Text("Hız Sınırı (Limit Yok)", style: TextStyle(color: Colors.white70)),
                    icon: const Icon(Icons.speed, color: Colors.blueAccent),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    items: const [
                       DropdownMenuItem(value: null, child: Text("Sınırsız Hız")),
                       DropdownMenuItem(value: 256 * 1024, child: Text("256 KB/s (Yavaş)")),
                       DropdownMenuItem(value: 1024 * 1024, child: Text("1 MB/s (Standart)")),
                       DropdownMenuItem(value: 5 * 1024 * 1024, child: Text("5 MB/s (Hızlı)")),
                       DropdownMenuItem(value: 10 * 1024 * 1024, child: Text("10 MB/s (Ultra Hızlı)")),
                    ],
                    onChanged: (val) {
                       setState(() {
                          _speedLimit = val;
                          if (_proxyServer != null) {
                             _proxyServer!.speedLimitBytesPerSec = val;
                          }
                       });
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isRunning ? _stopServer : _startServer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.redAccent : Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: Text(
                  _isRunning ? 'Sistemi Durdur' : 'Kalkanı Başlat',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              
              if (_isRunning && _proxyServer != null) ...[
                const SizedBox(height: 30),
                
                // LIVE DATA CHART
                const Text("Canlı Ağ Trafiği (KB/s)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  height: 200,
                  padding: const EdgeInsets.only(top: 20, right: 20, left: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white12, strokeWidth: 1)),
                      titlesData: FlTitlesData(
                         leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (value, meta) => Text("${value.toInt()}", style: const TextStyle(color: Colors.white54, fontSize: 10)))),
                         bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                         topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                         rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                         LineChartBarData(
                            spots: downloadData.isEmpty ? const [FlSpot(0,0)] : downloadData,
                            isCurved: true,
                            color: Colors.blueAccent,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.2)),
                         ),
                         LineChartBarData(
                            spots: uploadData.isEmpty ? const [FlSpot(0,0)] : uploadData,
                            isCurved: true,
                            color: Colors.greenAccent,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: Colors.greenAccent.withOpacity(0.2)),
                         ),
                      ],
                    )
                  )
                ),
                
                const SizedBox(height: 30),
                const Text("Bağlı Cihazlar & Kota", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ..._proxyServer!.clients.values.map((client) => Card(
                  color: Colors.black26,
                  child: ListTile(
                    leading: const Icon(Icons.computer, color: Colors.blueAccent),
                    title: Text(client.ip),
                    subtitle: Text('İndirme: ${formatBytes(client.bytesDownloaded)} | Yükleme: ${formatBytes(client.bytesUploaded)}' + (client.quotaLimit != null ? '\nKota: ${formatBytes(client.quotaLimit!)}' : '')),
                    trailing: IconButton(
                      icon: const Icon(Icons.speed, color: Colors.orangeAccent),
                      onPressed: () => _setQuotaDialog(client),
                    ),
                  ),
                )).toList(),
                
                const SizedBox(height: 30),
                const Text("URL Geçmişi (Ebeveyn Modu)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.builder(
                    itemCount: _proxyServer!.urlHistory.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text("- " + _proxyServer!.urlHistory.reversed.toList()[index], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      );
                    }
                  )
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
