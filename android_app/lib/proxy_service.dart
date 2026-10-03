import 'dart:async';
import 'dart:io';

import 'package:flutter_background_service/flutter_background_service.dart';

class ProxyService {
  ServerSocket? _server;
  bool _isRunning = false;
  final ServiceInstance? service;
  DateTime? _lastPing;
  Timer? _pingChecker;
  bool _clientIsActive = false;

  ProxyService({this.service});

  bool get isRunning => _isRunning;

  void _handlePing(String deviceName) {
    _lastPing = DateTime.now();
    _clientIsActive = true;
    service?.invoke('clientConnected', {'device': deviceName});
  }

  void _startPingChecker() {
    _pingChecker = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_clientIsActive && _lastPing != null) {
        if (DateTime.now().difference(_lastPing!).inSeconds > 6) {
          _clientIsActive = false;
          service?.invoke('clientDisconnected');
        }
      }
    });
  }

  /// Sunucuyu başlatır
  Future<bool> startProxy(String ipAddress, int port) async {
    if (_isRunning) return false;

    try {
      _server = await ServerSocket.bind(ipAddress, port);
      _startPingChecker();
      _isRunning = true;

      // Gelen bağlantıları dinle
      _server!.listen(
        (Socket client) {
          _handleConnection(client);
        },
        onError: (e) {
          print('Sunucu hatası: $e');
          stopProxy();
        },
      );
      return true;
    } catch (e) {
      print('Sunucu başlatılamadı: $e');
      return false;
    }
  }

  /// Sunucuyu durdurur
  void stopProxy() {
    _pingChecker?.cancel();
    _server?.close();
    _server = null;
    _isRunning = false;
  }

  /// İstemci bağlantısını yönetir
  void _handleConnection(Socket client) {
    runZonedGuarded(
      () async {
        List<int> requestBuffer = [];
        bool headerParsed = false;
        Socket? remote;

        client.listen(
          (List<int> data) async {
            if (!headerParsed) {
              requestBuffer.addAll(data);
              final requestString = String.fromCharCodes(requestBuffer);

              final headerEnd = requestString.indexOf('\r\n\r\n');
              if (headerEnd != -1) {
                headerParsed = true;

                final lines = requestString.split('\r\n');
                final firstLine = lines.first;
                final parts = firstLine.split(' ');

                if (parts.length >= 3) {
                  final method = parts[0];
                  final urlStr = parts[1];

                  try {
                    if (method == 'GET' &&
                        urlStr.contains('/__netshare_ping')) {
                      String deviceName = "Bilgisayar";
                      try {
                        final uri = Uri.parse(urlStr);
                        if (uri.queryParameters.containsKey('device')) {
                          deviceName = Uri.decodeComponent(
                            uri.queryParameters['device']!,
                          );
                        }
                      } catch (_) {}
                      client.write(
                        "HTTP/1.1 200 OK\r\nX-Device-Name: Telefon\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK",
                      );
                      await client.flush();
                      await client.close();
                      _handlePing(deviceName);
                      return;
                    }

                    if (method == 'CONNECT') {
                      final hostParts = urlStr.split(':');
                      final host = hostParts[0];
                      final port = hostParts.length > 1
                          ? int.parse(hostParts[1])
                          : 443;

                      remote = await Socket.connect(
                        host,
                        port,
                        timeout: const Duration(seconds: 15),
                      );
                      client.write(
                        'HTTP/1.1 200 Connection Established\r\n\r\n',
                      );

                      remote!.listen(
                        (d) {
                          try {
                            client.add(d);
                          } catch (_) {}
                        },
                        onDone: () => client.close(),
                        onError: (e) => client.destroy(),
                      );

                      if (requestBuffer.length > headerEnd + 4) {
                        try {
                          remote!.add(requestBuffer.sublist(headerEnd + 4));
                        } catch (_) {}
                      }
                    } else {
                      final uri = Uri.parse(urlStr);
                      final port = uri.port != 0 ? uri.port : 80;

                      remote = await Socket.connect(
                        uri.host,
                        port,
                        timeout: const Duration(seconds: 15),
                      );
                      try {
                        remote!.add(requestBuffer);
                      } catch (_) {}

                      remote!.listen(
                        (d) {
                          try {
                            client.add(d);
                          } catch (_) {}
                        },
                        onDone: () => client.close(),
                        onError: (e) => client.destroy(),
                      );
                    }
                  } catch (e) {
                    client.destroy();
                  }
                }
              }
            } else {
              if (remote != null) {
                try {
                  remote!.add(data);
                } catch (_) {}
              }
            }
          },
          onDone: () {
            remote?.destroy();
            client.destroy();
          },
          onError: (e) {
            remote?.destroy();
            client.destroy();
          },
        );
      },
      (error, stack) {
        try {
          client.destroy();
        } catch (_) {}
      },
    );
  }
}
