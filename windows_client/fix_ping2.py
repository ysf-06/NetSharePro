# -*- coding: utf-8 -*-
import codecs
import re

file_path = r'C:\C_Projects\wifi_tether_client\lib\main.dart'
with codecs.open(file_path, 'r', 'utf-8') as f:
    text = f.read()

# Replace _handleDisconnectFromServer
old_handle = r'void _handleDisconnectFromServer\(\) async \{[^\}]+\n    _pingTimer\?\.cancel\(\);\n    await ProxyManager\.disableProxy\(\);\n[^\}]+\}\n      _showSnackBar\("Telefon bağlantıyı kesti!"\);\n    \}\n  \}'

text = re.sub(
    r'void _handleDisconnectFromServer\(\) async \{.*?\s+await ProxyManager\.disableProxy\(\);.*?\}\s+\}',
    '''void _handleDisconnectFromServer() async {
    if (!isConnected) return;
    // KILL SWITCH: Proxy Windows'tan KALDIRILMIYOR.
    if (mounted) {
      setState(() {
        statusMessage = "Telefon ile bağlantı koptu! (Kota koruması aktif: İnternet durduruldu)";
      });
    }
  }

  void _handleReconnectToServer() {
    if (mounted && statusMessage.contains("bağlantı koptu")) {
      setState(() {
        statusMessage = "Bağlandı! Tüm trafik telefon üzerinden akıyor.\\nProxy: " + currentGatewayIp.toString() + ":8080";
      });
    }
  }''',
    text,
    flags=re.DOTALL
)

# Replace timeout and add _handleReconnectToServer
text = re.sub(
    r'final client = HttpClient\(\)\.\.connectionTimeout = const Duration\(seconds: 2\);(.*?)if \(response\.statusCode != 200\) \{\s*_handleDisconnectFromServer\(\);\s*\}',
    r'''// Timeout 10 saniyeye cikarildi (Yogun indirmelerde ping gecikebilir)
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);\1if (response.statusCode != 200) {
          _handleDisconnectFromServer();
        } else {
          _handleReconnectToServer();
        }''',
    text,
    flags=re.DOTALL
)

with codecs.open(file_path, 'w', 'utf-8') as f:
    f.write(text)
