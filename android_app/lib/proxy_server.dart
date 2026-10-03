import 'dart:io';

class ProxyServer {
  ServerSocket? _server;
  bool get isRunning => _server != null;

  Future<void> start(int port) async {
    if (_server != null) return;
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      print('Proxy Server running on ${_server!.address.address}:$port');

      _server!.listen((Socket clientSocket) {
        clientSocket.listen((List<int> data) async {
          final requestString = String.fromCharCodes(data);
          if (requestString.isEmpty) return;

          final lines = requestString.split('\r\n');
          if (lines.isEmpty) return;
          final firstLine = lines.first.split(' ');
          
          if (firstLine.length < 3) return;
          final method = firstLine[0];
          final url = firstLine[1];

          try {
            if (method == 'CONNECT') {
              // Handle HTTPS connect
              final hostPort = url.split(':');
              final host = hostPort[0];
              final targetPort = int.parse(hostPort[1]);

              final targetSocket = await Socket.connect(host, targetPort);
              clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
              
              targetSocket.addStream(clientSocket).catchError((_) {});
              clientSocket.addStream(targetSocket).catchError((_) {});
            } else {
              // Handle HTTP proxy
              final uri = Uri.parse(url);
              final host = uri.host;
              final targetPort = uri.hasPort ? uri.port : 80;

              final targetSocket = await Socket.connect(host, targetPort);
              targetSocket.add(data);

              targetSocket.addStream(clientSocket).catchError((_) {});
              clientSocket.addStream(targetSocket).catchError((_) {});
            }
          } catch (e) {
            print('Error handling connection to $url: $e');
            clientSocket.destroy();
          }
        }, onError: (error) {
          print('Client socket error: $error');
          clientSocket.destroy();
        }, onDone: () {
          clientSocket.destroy();
        });
      });
    } catch (e) {
      print('Error starting proxy server: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }
}
