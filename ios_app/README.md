# NetShare Pro — iOS (Native SwiftUI)

NetSharePro deposunun Android (Flutter) + Windows (Python) tarafıyla **tel uyumlu**, sıfırdan yazılmış **native iOS** uygulaması. Telefon Wi-Fi/hotspot ağında bir **SOCKS5/SOCKS4/HTTP proxy sunucusu** yayınlar; Windows istemcisi 4 haneli PIN ile doğrulanır ve internet trafiğini telefondan geçirir.

## Özellikler

- **Çoklu protokol proxy (8080):** SOCKS5 (CONNECT), SOCKS4/4a ve HTTP CONNECT + düz HTTP — Android sürümündeki tek-port-çoklu-protokol mimarisiyle aynı.
- **Kontrol sunucusu (8081):** `/__netshare_auth?pin=` ve `/__netshare_ping` uçları; Windows istemcisiyle birebir uyumlu (`auth_success` / `pong`).
- **PIN güvenliği:** 4 haneli PIN Keychain'de saklanır, panelden görünür, Ayarlar'dan yenilenebilir. PIN değişimi tüm yetkileri sıfırlar.
- **IP beyaz listesi:** Yalnızca PIN doğrulayan istemci IP'leri proxy portuna bağlanabilir; revoke/ban desteği.
- **Ağ seviyesinde Ad-Block:** Alan adı sonek eşleştirmesi + kullanıcı tanımlı liste (canlı uygulanır).
- **Canlı hız izleme:** 1 sn örnekleme, Canvas tabanlı çift çizgili grafik (indirme/yükleme).
- **Bant genişliği limiti ve kota:** Cihaz başı saniyelik hız limiti ve MB bazlı kota (aşım durumunda bağlantı kesilir).
- **URL geçmişi (Ebeveyn Modu):** Ziyaret edilen alan adları (IP istekleri hariç), engellenenler işaretli.
- **Bonjour:** `_netsharepro._tcp` servisi TXT kayıtlarıyla duyurulur ve yerel ağda keşfedilir.
- **QR bağlantı kodu:** IP/port/PIN bilgisini QR ile paylaş.

## Dizin Yapısı

```
ios_app/
├── project.yml                          # XcodeGen yapılandırması
├── README.md
└── NetSharePro/
    ├── Info.plist                       # Local Network + Bonjour izinleri
    ├── App/
    │   ├── NetShareProApp.swift         # @main, AppContext (DI), scene phase
    │   ├── AppTheme.swift               # Renk teması (#0F172A slate)
    │   ├── RootTabView.swift            # 4 sekmeli NavigationStack kabuğu
    │   └── IntegrationExamples.swift    # Kullanım senaryoları + self-test
    ├── Core/
    │   ├── ProtocolConstants.swift      # Portlar, uçlar, zaman aşımı sabitleri
    │   ├── Networking/
    │   │   ├── TCPConnection.swift      # Async NWConnection sarmalayıcı + connector
    │   │   ├── HTTPRequestParser.swift  # Minimal HTTP/1.1 istek ayrıştırıcı
    │   │   ├── NetworkInterfaceProvider.swift  # getifaddrs → hotspot/Wi-Fi IP
    │   │   ├── ControlHTTPServer.swift  # 8081: auth + ping
    │   │   ├── ProxyServer.swift        # 8080: ilk bayttan protokol seçimi
    │   │   ├── SOCKS5Session.swift      # RFC 1928 CONNECT
    │   │   ├── SOCKS4Session.swift      # SOCKS4 + 4a uzantısı
    │   │   ├── HTTPProxySession.swift   # CONNECT + origin-form yeniden yazımı
    │   │   └── RelayPipe.swift          # Çift yönlü pompa + throttle + kota
    │   └── Services/
    │       ├── ProxyEngine.swift        # Facade: start/stop, tünel, PIN
    │       ├── AccessControl.swift      # Beyaz liste + kalıcı ban listesi
    │       ├── SessionTracker.swift     # Oturum, sayaç, kota, throttle, liveness
    │       ├── ActivityStore.swift      # URL geçmişi (200 kayıt ring buffer)
    │       ├── AdBlockService.swift     # Sonek eşleştirme + özel liste
    │       ├── ConnectionRegistry.swift # IP bazlı canlı bağlantı kaydı (kick)
    │       ├── KeychainStore.swift      # PIN saklama
    │       ├── SettingsStore.swift      # UserDefaults destekli ayarlar
    │       └── BonjourKit.swift         # Duyurucu + NWBrowser keşif
    ├── Models/NetShareModels.swift
    ├── ViewModels/                      # Dashboard / Clients / Activity / Settings VM
    ├── Views/                           # Dashboard, Clients, Activity, Settings, Components
    └── Resources/Assets.xcassets
```

## Derleme

### XcodeGen ile (önerilen)

```bash
cd ios_app
brew install xcodegen   # bir kez
xcodegen generate
open NetSharePro.xcodeproj
```

Xcode'da kendi Apple ID takımını (Signing & Capabilities) seç ve hedef cihazda/simülatörde çalıştır.

### Manuel (XcodeGen istenmezse)

Xcode > File > New > Project > iOS App (SwiftUI, isim: `NetSharePro`), ardından `NetSharePro/` içindeki tüm `.swift` dosyalarını projeye ekle, `Info.plist` ve `Assets.xcassets` yolunu göster.

## Kullanım Senaryosu (Windows istemcisiyle uçtan uca)

1. iPhone'da hotspot'u aç; uygulamada **Kalkanı Başlat** → panelde IP (`172.20.10.1` gibi) ve PIN görünür.
2. Windows istemcisinde (`windows_client`) telefon IP + PIN gir, **Bağlan (SOCKS5)**.
3. İstemci `http://<ip>:8081/__netshare_auth?pin=XXXX` çağrısı yapar; `auth_success` gelirse IP beyaz listeye alınır ve sistem proxy'si `socks=<ip>:8080` olarak ayarlanır.
4. Her 2 saniyede bir `/__netshare_ping` atılır; 6 saniye ping gelmezse uygulama istemciyi çevrimdışı gösterir (istemcide Kill-Switch devreye girer).
5. Panelde canlı hız grafiği, Cihazlar sekmesinde oturum/kota, Etkinlik'te alan adı geçmişi canlı akar.

Sunucuyu elle test etmek için:

```bash
curl "http://<telefon-ip>:8081/__netshare_auth?pin=1234"   # auth_success
curl "http://<telefon-ip>:8081/__netshare_ping"            # pong
curl --socks5 <telefon-ip>:8080 https://example.com -I
```

Kod içi senaryolar için `App/IntegrationExamples.swift`: programatik motor kontrolü, kontrol sunucusu doğrulaması (`verifyControlServer`) ve SOCKS5 tünel self-testi (`selfTestSOCKS5Tunnel`).

## Platform Sınırları (dürüst notlar)

- **Arka plan:** iOS, arka planda uygulama soketlerini kısa sürede askıya alır. Paylaşım sırasında "Ekranı Açık Tut" açık kalsın. `UIBackgroundModes: audio` hilesi bilinçli olarak **eklenmedi** (App Store politikası riski).
- **VPN paylaşımı:** Android'in `VpnService`'i gibi sistem tünellerini uygulama dışına açmak iOS'ta mümkün değildir. Sistem genelinde çalışan bir VPN varsa bu uygulamanın giden trafiği de VPN'den geçer; uygulama-bazlı VPN tünelleri paylaşılamaz.
- **Sunucu yetkilendirmesi:** SOCKS5 el sıkışmasında yalnızca CONNECT (cmd 0x01) desteklenir; BIND/UDP ASSOCIATE reddedilir (Android sürümüyle aynı).
