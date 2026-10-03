# NetShare Pro 🚀

NetShare Pro, root gerektirmeden Wi-Fi üzerinden internetinizi ve VPN bağlantınızı diğer cihazlarla güvenli bir şekilde paylaşmanızı sağlayan açık kaynaklı bir SOCKS5 Proxy çözümüdür. 

Mobil cihazınızda arka planda çalışan bir SOCKS5 ve HTTP proxy sunucusu oluşturarak bağlantıyı paylaştırır ve özel bir şifreleme (PIN kodu) kullanarak dışarıdan izinsiz erişimleri engeller.

Bu proje iki ana bileşenden oluşur:
1. **Android App (Server):** Telefonunuzda çalışan, arka planda güvenli SOCKS5 proxy sunucusunu ayağa kaldıran, eş zamanlı grafiklerle hızı takip etmenizi sağlayan ve dahili reklam engelleyici bulunduran Flutter tabanlı mobil uygulama.
2. **Windows Client:** Bilgisayarınıza yüklenen ve tek tuşla (otomatik) telefondaki proxy'ye güvenli şifre ile bağlanan Windows masaüstü istemcisi. Sistem tepsisinde (System Tray) sessizce çalışır.

## 🎯 Özellikler

* **Root Gerektirmez:** Sadece hotspot açarak veya aynı Wi-Fi ağına bağlanarak cihazlarınız arasında doğrudan güvenli bağlantı kurun.
* **SOCKS5 ve HTTP Proxy Desteği:** Her iki protokolü de tam ve eşzamanlı destekler.
* **Güvenli Erişim (4 Haneli PIN):** Ağınızdaki herkesin bağlanmasını engeller. İstemci, Proxy'yi kullanmadan önce özel bir HTTP isteği ile 4 haneli PIN kodunu doğrular.
* **Ağ Seviyesinde Reklam Engelleyici (Ad-Block):** Bilgisayardan girilen siteler telefondaki kara liste havuzuyla kontrol edilir; zararlı ve reklam amaçlı domainler ağ seviyesinde (tıpkı Pi-Hole gibi) engellenir.
* **Canlı Hız İzleme:** Anlık indirme ve yükleme hızlarınızı mobil uygulamada grafiksel olarak görebilirsiniz.
* **Bandwidth Throttling (Hız Limitleme):** İsteğe bağlı olarak PC'ye giden hızı limitleyebilir, verinizi koruyabilirsiniz.
* **Kill-Switch (Zırhlı Ağ Kilidi):** PC istemcisinde bağlantı koptuğu an internet akışını tamamen keserek verinizin doğrudan hücreselden/farklı bir yerden çıkmasını engeller.

## 📁 Proje Yapısı

* `/android_app/` - Mobil uygulama (Flutter)
* `/windows_client/` - Bilgisayar istemcisi (Flutter Desktop)

## 🛠️ Nasıl Çalıştırılır?

### Android Uygulaması
1. `android_app` klasörüne girin.
2. `flutter pub get` komutunu çalıştırın.
3. Telefonunuzu bağlayıp `flutter run --release` komutuyla uygulamayı yükleyin.

### Windows İstemcisi
1. `windows_client` klasörüne girin.
2. `flutter pub get` komutunu çalıştırın.
3. `flutter build windows` komutuyla derleyin veya `flutter run -d windows` ile test edin.

## 📝 Lisans
Bu proje MIT lisansı altında açık kaynak olarak paylaşılmıştır.
