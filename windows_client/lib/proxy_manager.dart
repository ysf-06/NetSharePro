import 'dart:io';

class ProxyManager {
  static Future<String?> getGatewayIp() async {
    if (Platform.isWindows) {
      try {
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          'Get-NetAdapter | Get-NetIPConfiguration | Select-Object -ExpandProperty IPv4DefaultGateway | Select-Object -ExpandProperty NextHop'
        ]);
        
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          final lines = output.split('\n');
          for (var line in lines) {
            line = line.trim();
            if (line.isNotEmpty && line.contains('.')) {
              return line;
            }
          }
        }
      } catch (e) {
        print("Gateway IP alinamadi: $e");
      }
    } else if (Platform.isMacOS) {
      try {
        final result = await Process.run('route', ['-n', 'get', 'default']);
        final lines = result.stdout.toString().split('\n');
        for (var line in lines) {
          if (line.contains('gateway:')) {
            return line.split(':')[1].trim();
          }
        }
      } catch (e) {
        print("Mac Gateway IP alinamadi: $e");
      }
    }
    return null;
  }

  static Future<bool> enableProxy(String ip, int port) async {
    if (Platform.isWindows) {
      try {
        final proxyStr = 'http=$ip:$port;https=$ip:$port';
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyServer',
          '/t',
          'REG_SZ',
          '/d',
          proxyStr,
          '/f'
        ]);
        
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyEnable',
          '/t',
          'REG_DWORD',
          '/d',
          '1',
          '/f'
        ]);
        
        // Yenileme komutu powershell ile
        await Process.run('powershell', [
            '-Command',
            r'''
            $signature = @'
            [DllImport("wininet.dll", SetLastError = true, CharSet=CharSet.Auto)]
            public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@
            $type = Add-Type -MemberDefinition $signature -Name "WinInet" -Namespace "Win32" -PassThru
            $type::InternetSetOption(0, 39, 0, 0)
            $type::InternetSetOption(0, 37, 0, 0)
            '''
        ]);

        return true;
      } catch (e) {
        print("Windows Proxy aktif edilemedi: $e");
        return false;
      }
    } else if (Platform.isMacOS) {
      try {
        final wifiInterface = 'Wi-Fi'; 
        await Process.run('networksetup', ['-setsocksfirewallproxy', wifiInterface, ip, port.toString()]);
        await Process.run('networksetup', ['-setsocksfirewallproxystate', wifiInterface, 'on']);
        return true;
      } catch (e) {
        print("Mac Proxy aktif edilemedi: $e");
        return false;
      }
    }
    return false;
  }

  static Future<bool> disableProxy() async {
    if (Platform.isWindows) {
      try {
        await Process.run('reg', [
          'add',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyEnable',
          '/t',
          'REG_DWORD',
          '/d',
          '0',
          '/f'
        ]);
        
        await Process.run('powershell', [
            '-Command',
            r'''
            $signature = @'
            [DllImport("wininet.dll", SetLastError = true, CharSet=CharSet.Auto)]
            public static extern bool InternetSetOption(IntPtr hInternet, int dwOption, IntPtr lpBuffer, int dwBufferLength);
'@
            $type = Add-Type -MemberDefinition $signature -Name "WinInet" -Namespace "Win32" -PassThru
            $type::InternetSetOption(0, 39, 0, 0)
            $type::InternetSetOption(0, 37, 0, 0)
            '''
        ]);

        return true;
      } catch (e) {
        print("Windows Proxy kapatilamadi: $e");
        return false;
      }
    } else if (Platform.isMacOS) {
      try {
        final wifiInterface = 'Wi-Fi';
        await Process.run('networksetup', ['-setsocksfirewallproxystate', wifiInterface, 'off']);
        return true;
      } catch (e) {
        print("Mac Proxy kapatilamadi: $e");
        return false;
      }
    }
    return false;
  }
}
