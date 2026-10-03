# -*- coding: utf-8 -*-
import codecs

file_path = r'C:\C_Projects\wifi_tether_client\lib\main.dart'
with codecs.open(file_path, 'r', 'utf-8') as f:
    text = f.read()

old_disconnect = '''  void _handleDisconnectFromServer() async {
    if (!isConnected) return;
    _pingTimer?.cancel();
    await ProxyManager.disableProxy();
    if (mounted) {
      setState(() {
        isConnected = false;
        statusMessage = "Telefon ile bağlantı koptu!";
      });
      _showSnackBar("Telefon bağlantıyı kesti!");
    }
  }'''

new_disconnect = '''  void _handleDisconnectFromServer() async {
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
    if (mounted && statusMessage.contains("bağlantı koptu")) {
      setState(() {
        statusMessage = "Bağlandı! Tüm trafik telefon üzerinden akıyor.\\nProxy: \";
      });
    }
  }'''

old_ping = '''  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!isConnected || currentGatewayIp == null) {
        timer.cancel();
        return;
      }
      try {
        final String deviceName = Uri.encodeComponent(Platform.localHostname);
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
        final request = await client.getUrl(Uri.parse('http://\/__netshare_ping?device=\'));
        final response = await request.close();
        if (response.statusCode != 200) {
          _handleDisconnectFromServer();
        }
        client.close();
      } catch (e) {
        _handleDisconnectFromServer();
      }
    });
  }'''

new_ping = '''  void _startPing() {
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
        final request = await client.getUrl(Uri.parse('http://\/__netshare_ping?device=\'));
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
  }'''

text = text.replace(old_disconnect, new_disconnect)
text = text.replace(old_ping, new_ping)

with codecs.open(file_path, 'w', 'utf-8') as f:
    f.write(text)
