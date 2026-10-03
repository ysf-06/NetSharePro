import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ClientSession {
  final String ip;
  int bytesDownloaded = 0;
  int bytesUploaded = 0;
  int? quotaLimit;
  
  ClientSession(this.ip);
}

class StreamReader {
  late StreamSubscription<List<int>> sub;
  List<int> buffer = [];
  Completer<void>? _waiter;
  bool isClosed = false;

  StreamReader(Stream<List<int>> stream) {
    sub = stream.listen((data) {
      buffer.addAll(data);
      if (_waiter != null && !_waiter!.isCompleted) {
        _waiter!.complete();
      }
    }, onDone: () {
      isClosed = true;
      if (_waiter != null && !_waiter!.isCompleted) {
        _waiter!.complete();
      }
    }, onError: (e) {
      isClosed = true;
      if (_waiter != null && !_waiter!.isCompleted) {
        _waiter!.completeError(e);
      }
    });
  }

  Future<List<int>> read(int count) async {
    while (buffer.length < count && !isClosed) {
      _waiter = Completer<void>();
      await _waiter!.future;
    }
    if (buffer.length < count) return [];
    var res = buffer.sublist(0, count);
    buffer = buffer.sublist(count);
    return res;
  }
}

class Socks5Proxy {
  final int port;
  ServerSocket? _serverSocket;
  bool isRunning = false;
  
  Set<String> authenticatedIps = {};
  Map<String, ClientSession> clients = {};
  List<String> urlHistory = [];
  
  bool adBlockEnabled = false;
  int? speedLimitBytesPerSec;
  
  final List<String> adDomains = [
    'doubleclick.net', 'googleadservices.com', 'googlesyndication.com', 
    'adsystem.com', 'adnxs.com', 'criteo.com', 'taboola.com', 'outbrain.com', 
    'rubiconproject.com', 'openx.net', 'appsflyer.com', 'unityads.unity3d.com', 
    'applovin.com', 'vungle.com', 'inmobi.com', 'chartboost.com', 'admob.com', 
    'amazon-adsystem.com', 'tiktokv.com', 'byteoversea.com'
  ];

  Function? onStatsUpdated;
  Function? onUrlVisited;

  Socks5Proxy({required this.port});
  
  bool _isAdDomain(String? host) {
    if (!adBlockEnabled || host == null) return false;
    for (var domain in adDomains) {
      if (host == domain || host.endsWith('.$domain')) {
        return true;
      }
    }
    return false;
  }

  Future<void> start() async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    isRunning = true;
    _serverSocket!.listen(_handleClient);
  }

  void stop() {
    isRunning = false;
    _serverSocket?.close();
  }

  void _handleClient(Socket client) async {
    final clientIp = client.remoteAddress.address;
    
    if (!authenticatedIps.contains(clientIp)) {
      client.destroy();
      return;
    }

    if (!clients.containsKey(clientIp)) {
      clients[clientIp] = ClientSession(clientIp);
    }
    
    final reader = StreamReader(client);
    
    try {
      var initHeader = await reader.read(1);
      if (initHeader.isEmpty) {
        client.destroy();
        return;
      }
      
      int protocolVersion = initHeader[0];
      
      if (protocolVersion == 0x05) {
          // SOCKS5
          var nMethodsBytes = await reader.read(1);
          if (nMethodsBytes.isEmpty) { client.destroy(); return; }
          int nMethods = nMethodsBytes[0];
          
          var methods = await reader.read(nMethods);
          if (!methods.contains(0x00)) {
            client.add([0x05, 0xFF]); 
            client.destroy();
            return;
          }
          client.add([0x05, 0x00]); // NO AUTH required
          
          var cmdHeader = await reader.read(4);
          if (cmdHeader.isEmpty || cmdHeader[0] != 0x05) { client.destroy(); return; }
          int cmd = cmdHeader[1];
          int atyp = cmdHeader[3];
          
          if (cmd != 0x01) {
            client.add([0x05, 0x07, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
            client.destroy(); return;
          }
          
          String targetHost = '';
          if (atyp == 0x01) {
            var ipBytes = await reader.read(4);
            targetHost = InternetAddress.fromRawAddress(Uint8List.fromList(ipBytes)).address;
          } else if (atyp == 0x03) {
            var lenBytes = await reader.read(1);
            var domainBytes = await reader.read(lenBytes[0]);
            targetHost = utf8.decode(domainBytes);
            _recordUrl(targetHost);
          } else if (atyp == 0x04) {
            var ipBytes = await reader.read(16);
            targetHost = InternetAddress.fromRawAddress(Uint8List.fromList(ipBytes)).address;
          }
          
          var portBytes = await reader.read(2);
          int targetPort = (portBytes[0] << 8) | portBytes[1];
          
          if (_isAdDomain(targetHost)) {
              client.destroy(); return;
          }
          
          Socket targetSocket;
          try {
            targetSocket = await Socket.connect(targetHost, targetPort, timeout: const Duration(seconds: 10));
          } catch (e) {
            client.add([0x05, 0x04, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
            client.destroy(); return;
          }
          
          client.add([0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
          _setupPipes(client, targetSocket, clientIp, reader);
          
      } else if (protocolVersion == 0x04) {
          // SOCKS4
          var cmdBytes = await reader.read(1);
          if (cmdBytes.isEmpty) { client.destroy(); return; }
          int cmd = cmdBytes[0];
          
          if (cmd != 0x01) { client.destroy(); return; }
          
          var portBytes = await reader.read(2);
          int targetPort = (portBytes[0] << 8) | portBytes[1];
          
          var ipBytes = await reader.read(4);
          String targetHost = InternetAddress.fromRawAddress(Uint8List.fromList(ipBytes)).address;
          
          // Read UserID (null-terminated)
          while (true) {
             var b = await reader.read(1);
             if (b.isEmpty || b[0] == 0x00) break;
          }
          
          // SOCKS4a extension
          if (ipBytes[0] == 0 && ipBytes[1] == 0 && ipBytes[2] == 0 && ipBytes[3] != 0) {
              List<int> domainBytes = [];
              while (true) {
                 var b = await reader.read(1);
                 if (b.isEmpty || b[0] == 0x00) break;
                 domainBytes.add(b[0]);
              }
              targetHost = utf8.decode(domainBytes);
              _recordUrl(targetHost);
          } else {
             if (targetPort == 80 || targetPort == 443) _recordUrl(targetHost);
          }
          
          if (_isAdDomain(targetHost)) {
              client.destroy(); return;
          }
          
          Socket targetSocket;
          try {
            targetSocket = await Socket.connect(targetHost, targetPort, timeout: const Duration(seconds: 10));
          } catch (e) {
            client.add([0x00, 0x5B, 0, 0, 0, 0, 0, 0]); // Rejected
            client.destroy(); return;
          }
          
          // Granted
          client.add([0x00, 0x5A, portBytes[0], portBytes[1], ipBytes[0], ipBytes[1], ipBytes[2], ipBytes[3]]);
          _setupPipes(client, targetSocket, clientIp, reader);
          
      } else {
          // Check for HTTP Proxy (e.g. CONNECT or GET)
          // Since we read 1 byte, we put it back
          List<int> initialData = [protocolVersion];
          // Try reading next bytes until \r\n\r\n
          List<int> headerBytes = List.from(initialData);
          while (true) {
             var b = await reader.read(1);
             if (b.isEmpty) break;
             headerBytes.add(b[0]);
             if (headerBytes.length >= 4 && 
                 headerBytes[headerBytes.length-4] == 13 && headerBytes[headerBytes.length-3] == 10 &&
                 headerBytes[headerBytes.length-2] == 13 && headerBytes[headerBytes.length-1] == 10) {
                 break;
             }
             if (headerBytes.length > 8192) break; // too long
          }
          
          String requestString = String.fromCharCodes(headerBytes);
          final lines = requestString.split('\r\n');
          if (lines.isEmpty) { client.destroy(); return; }
          final firstLine = lines.first.split(' ');
          if (firstLine.length < 3) { client.destroy(); return; }
          
          final method = firstLine[0];
          final url = firstLine[1];
          
          try {
            if (method == 'CONNECT') {
              final hostPort = url.split(':');
              final host = hostPort[0];
              final targetPort = int.parse(hostPort[1]);
              _recordUrl(host);
              
              if (_isAdDomain(host)) {
                  client.destroy(); return;
              }
              
              final targetSocket = await Socket.connect(host, targetPort, timeout: const Duration(seconds: 10));
              client.write('HTTP/1.1 200 Connection Established\r\n\r\n');
              _setupPipes(client, targetSocket, clientIp, reader);
            } else {
              final uri = Uri.parse(url);
              final host = uri.host;
              final targetPort = uri.hasPort ? uri.port : 80;
              _recordUrl(host!);
              
              if (_isAdDomain(host)) {
                  client.destroy(); return;
              }
              
              final targetSocket = await Socket.connect(host, targetPort, timeout: const Duration(seconds: 10));
              targetSocket.add(headerBytes);
              _setupPipes(client, targetSocket, clientIp, reader);
            }
          } catch (e) {
            client.destroy();
          }
      }
      
    } catch (e) {
      client.destroy();
    }
  }
  
  void _recordUrl(String targetHost) {
      if (urlHistory.length > 200) urlHistory.removeAt(0);
      if (!RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(targetHost)) {
          urlHistory.add(targetHost);
          onUrlVisited?.call();
      }
  }
  
  void _setupPipes(Socket client, Socket targetSocket, String clientIp, StreamReader reader) {
      int lastUploadSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int uploadBytesThisSec = 0;
      
      int lastDownloadSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int downloadBytesThisSec = 0;
  
      if (reader.buffer.isNotEmpty) {
        targetSocket.add(reader.buffer);
        final session = clients[clientIp];
        if (session != null) {
          session.bytesUploaded += reader.buffer.length;
          onStatsUpdated?.call();
        }
      }
      
      reader.sub.onData((data) {
        final session = clients[clientIp];
        if (session != null) {
          session.bytesUploaded += data.length;
          if (session.quotaLimit != null && (session.bytesUploaded + session.bytesDownloaded) > session.quotaLimit!) {
            client.destroy();
            targetSocket.destroy();
            return;
          }
          onStatsUpdated?.call();
        }
        targetSocket.add(data);
        
        if (speedLimitBytesPerSec != null) {
             int currentSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
             if (currentSec != lastUploadSec) {
                 lastUploadSec = currentSec;
                 uploadBytesThisSec = 0;
             }
             uploadBytesThisSec += data.length;
             if (uploadBytesThisSec > speedLimitBytesPerSec!) {
                 reader.sub.pause();
                 Future.delayed(Duration(milliseconds: 1000 - (DateTime.now().millisecondsSinceEpoch % 1000))).then((_) {
                     reader.sub.resume();
                 });
             }
        }
      });
      reader.sub.onDone(() {
        targetSocket.close();
      });
      reader.sub.onError((e) {
        targetSocket.destroy();
      });
      
      late StreamSubscription targetSub;
      targetSub = targetSocket.listen((data) {
        final session = clients[clientIp];
        if (session != null) {
          session.bytesDownloaded += data.length;
          onStatsUpdated?.call();
        }
        client.add(data);
        
        if (speedLimitBytesPerSec != null) {
             int currentSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
             if (currentSec != lastDownloadSec) {
                 lastDownloadSec = currentSec;
                 downloadBytesThisSec = 0;
             }
             downloadBytesThisSec += data.length;
             if (downloadBytesThisSec > speedLimitBytesPerSec!) {
                 targetSub.pause();
                 Future.delayed(Duration(milliseconds: 1000 - (DateTime.now().millisecondsSinceEpoch % 1000))).then((_) {
                     targetSub.resume();
                 });
             }
        }
      }, onDone: () {
        client.close();
      }, onError: (e) {
        client.destroy();
      });
  }
}
