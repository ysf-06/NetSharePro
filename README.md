# NetShare Pro 🚀

[![English](https://img.shields.io/badge/Language-English-blue)](#english) [![Türkçe](https://img.shields.io/badge/Dil-T%C3%BCrk%C3%A7e-red)](#t%C3%BCrk%C3%A7e)

---

## <a id="english"></a> 🇬🇧 English

NetShare Pro is an open-source SOCKS5 and HTTP Proxy solution that allows you to securely share your Wi-Fi and VPN connection with other devices **without root access**.

It creates a secure SOCKS5/HTTP proxy server in the background on your mobile device and prevents unauthorized access using a special encryption (PIN code) method.

### 📥 Download (Ready to Use)
You don't need to build from source! You can download the ready-to-use application files directly from the **Releases** page:

* 📱 **Android APK:** [Download NetSharePro.apk](https://github.com/ysf-06/NetSharePro/releases/latest)
* 💻 **Windows Client:** [Download NetSharePro-Windows.zip](https://github.com/ysf-06/NetSharePro/releases/latest)

> **Note:** To download, click the link above, go to the latest release, and download the `.apk` and `.zip` files from the "Assets" section. Extract the Windows ZIP to a folder and run `wifi_tether_client.exe`.

### 🎯 Features
* **No Root Required:** Create a secure connection directly between your devices by just turning on your mobile hotspot or connecting to the same Wi-Fi.
* **SOCKS5 and HTTP Proxy:** Full and simultaneous support for both protocols.
* **Secure Access (4-Digit PIN):** Prevents anyone on your network from connecting. The client authenticates with a 4-digit PIN before using the Proxy.
* **Network-Level Ad-Blocker:** Websites accessed from your PC are checked against a blacklist on your phone; malicious and ad-serving domains are blocked at the network level (like Pi-Hole).
* **Live Speed Monitoring:** Visually monitor your real-time download and upload speeds directly in the mobile app.
* **Bandwidth Throttling:** Optionally limit the internet speed delivered to the PC to save your data.
* **Kill-Switch (Armored Network Lock):** If the connection is lost on the PC client, it completely cuts off internet traffic, preventing data from leaking out through other networks.

---

## <a id="türkçe"></a> 🇹🇷 Türkçe

NetShare Pro, root gerektirmeden Wi-Fi üzerinden internetinizi ve VPN bağlantınızı diğer cihazlarla güvenli bir şekilde paylaşmanızı sağlayan açık kaynaklı bir SOCKS5 ve HTTP Proxy çözümüdür. 

Mobil cihazınızda arka planda çalışan bir SOCKS5/HTTP proxy sunucusu oluşturarak bağlantıyı paylaştırır ve özel bir şifreleme (PIN kodu) kullanarak dışarıdan izinsiz erişimleri engeller.

### 📥 İndir (Hazır Kurulum)
Kodlarla uğraşmanıza gerek yok! Uygulamanın çalışmaya hazır hallerini **Releases** sayfasından tek tıkla indirebilirsiniz:

* 📱 **Android APK:** [NetSharePro.apk İndir](https://github.com/ysf-06/NetSharePro/releases/latest)
* 💻 **Windows İstemcisi:** [NetSharePro-Windows.zip İndir](https://github.com/ysf-06/NetSharePro/releases/latest)

> **Not:** İndirmek için üstteki bağlantıya tıklayın, açılan sayfada "Assets" bölümünden `.apk` ve `.zip` dosyalarını indirin. Windows için ZIP dosyasını klasöre çıkartıp `wifi_tether_client.exe` dosyasını çalıştırmanız yeterlidir.

### 🎯 Özellikler
* **Root Gerektirmez:** Sadece hotspot açarak veya aynı Wi-Fi ağına bağlanarak cihazlarınız arasında doğrudan güvenli bağlantı kurun.
* **SOCKS5 ve HTTP Proxy Desteği:** Her iki protokolü de tam ve eşzamanlı destekler.
* **Güvenli Erişim (4 Haneli PIN):** Ağınızdaki herkesin bağlanmasını engeller. İstemci, Proxy'yi kullanmadan önce özel bir HTTP isteği ile 4 haneli PIN kodunu doğrular.
* **Ağ Seviyesinde Reklam Engelleyici (Ad-Block):** Bilgisayardan girilen siteler telefondaki kara liste havuzuyla kontrol edilir; zararlı ve reklam amaçlı domainler ağ seviyesinde (tıpkı Pi-Hole gibi) engellenir.
* **Canlı Hız İzleme:** Anlık indirme ve yükleme hızlarınızı mobil uygulamada grafiksel olarak görebilirsiniz.
* **Bandwidth Throttling (Hız Limitleme):** İsteğe bağlı olarak PC'ye giden hızı limitleyebilir, verinizi koruyabilirsiniz.
* **Kill-Switch (Zırhlı Ağ Kilidi):** PC istemcisinde bağlantı koptuğu an internet akışını tamamen keserek verinizin doğrudan farklı bir yerden çıkmasını engeller.

## 📝 Lisans / License
© 2026 Yusuf. Tüm Hakları Saklıdır. / All Rights Reserved.

Bu uygulamanın kaynak kodlarının, tasarımının veya derlenmiş dosyalarının kopyalanması, değiştirilmesi, başka bir isimle yayınlanması veya ticari/bireysel amaçlarla izinsiz dağıtılması kesinlikle yasaktır.

*The copying, modification, redistribution, or unauthorized use of this application's source code, design, or compiled binaries under any other name for commercial or personal purposes is strictly prohibited.*


---

## 🛠 Advanced Installation (For High Security Android Devices) / Gelişmiş Kurulum (Yüksek Güvenlikli Cihazlar İçin)

If your device has **Google Advanced Protection** enabled or **Play Protect** strictly blocks you from installing APKs via browser, use the PC Installer tool:

Eğer telefonunuzda **"Gelişmiş Koruma" (Advanced Protection)** aktifse ve tarayıcıdan hiçbir şekilde APK kurmanıza izin vermiyorsa bu kesin yöntemi kullanın:

1. Bilgisayarınıza [NetSharePro-Android-Installer.zip](https://github.com/ysf-06/NetSharePro/raw/main/Releases/NetSharePro-Android-Installer.zip) dosyasını indirin ve bir klasöre çıkartın.
2. Telefonunuzu bilgisayara USB kablosu ile bağlayın.
3. Telefonunuzun ayarlarından **Geliştirici Seçenekleri**ni ve ardından **USB Hata Ayıklama** (USB Debugging) özelliğini açın.
4. Çıkarttığınız klasördeki **`Kurulum.bat`** dosyasına çift tıklayın.
5. Telefonunuzun ekranında çıkan "Bu bilgisayara izin verilsin mi?" sorusuna **İzin Ver** deyin.
6. Kurulum aracı tüm engelleri aşarak uygulamayı telefonunuza saniyeler içinde kuracaktır!
