import sys
import os
import winreg
import urllib.request
import urllib.error
import threading
import time
import tkinter as tk
from tkinter import messagebox, font

def set_proxy(enable, ip="", port=""):
    try:
        internet_settings = winreg.OpenKey(winreg.HKEY_CURRENT_USER,
            r'Software\Microsoft\Windows\CurrentVersion\Internet Settings',
            0, winreg.KEY_ALL_ACCESS)
        
        if enable:
            winreg.SetValueEx(internet_settings, 'ProxyEnable', 0, winreg.REG_DWORD, 1)
            winreg.SetValueEx(internet_settings, 'ProxyServer', 0, winreg.REG_SZ, f'socks={ip}:{port}')
        else:
            winreg.SetValueEx(internet_settings, 'ProxyEnable', 0, winreg.REG_DWORD, 0)
            
        winreg.CloseKey(internet_settings)
        
        import ctypes
        internet_option_refresh = 37
        internet_option_settings_changed = 39
        internet_set_option = ctypes.windll.wininet.InternetSetOptionW
        internet_set_option(0, internet_option_refresh, 0, 0)
        internet_set_option(0, internet_option_settings_changed, 0, 0)
        return True
    except Exception as e:
        print(f"Proxy ayarlanırken hata: {e}")
        return False

class App:
    def __init__(self, root):
        self.root = root
        self.root.title("NetShare Pro")
        self.root.geometry("380x450")
        self.root.configure(bg="#0F172A")
        self.root.resizable(False, False)
        
        self.is_connected = False
        self.ping_thread = None
        self.running_ping = False
        self.saved_ip = ""
        
        if os.path.exists("config.txt"):
            with open("config.txt", "r") as f:
                self.saved_ip = f.read().strip()
                
        self.build_ui()
        
    def build_ui(self):
        title_font = font.Font(family="Helvetica", size=18, weight="bold")
        label_font = font.Font(family="Helvetica", size=10)
        
        # Title
        tk.Label(self.root, text="NetShare Pro", font=title_font, bg="#0F172A", fg="#60A5FA").pack(pady=(20, 20))
        
        # IP Input
        tk.Label(self.root, text="Telefon IP Adresi:", font=label_font, bg="#0F172A", fg="white").pack(anchor="w", padx=30)
        self.ip_entry = tk.Entry(self.root, font=label_font, bg="#1E293B", fg="white", insertbackground="white", relief="flat")
        self.ip_entry.insert(0, self.saved_ip)
        self.ip_entry.pack(fill="x", padx=30, pady=(5, 15), ipady=5)
        
        # PIN Input
        tk.Label(self.root, text="Güvenlik PIN:", font=label_font, bg="#0F172A", fg="white").pack(anchor="w", padx=30)
        self.pin_entry = tk.Entry(self.root, font=label_font, bg="#1E293B", fg="white", insertbackground="white", relief="flat")
        self.pin_entry.pack(fill="x", padx=30, pady=(5, 15), ipady=5)
        
        # Lock Checkbox
        self.lock_var = tk.BooleanVar(value=True)
        self.lock_cb = tk.Checkbutton(self.root, text="Zırhlı Ağ Kilidi (Bağlantı koparsa trafiği kes)", 
                                      variable=self.lock_var, bg="#0F172A", fg="white", selectcolor="#1E293B", activebackground="#0F172A", activeforeground="white")
        self.lock_cb.pack(anchor="w", padx=25, pady=10)
        
        # Status Box
        self.status_frame = tk.Frame(self.root, bg="#1E293B")
        self.status_frame.pack(fill="x", padx=30, pady=15, ipady=15)
        self.status_label = tk.Label(self.status_frame, text="Durum: Bekleniyor...", bg="#1E293B", fg="white", font=label_font)
        self.status_label.pack(expand=True)
        
        # Button
        self.btn = tk.Button(self.root, text="Bağlan (SOCKS5)", font=font.Font(family="Helvetica", size=11, weight="bold"), 
                             bg="#3B82F6", fg="white", relief="flat", activebackground="#2563EB", activeforeground="white", command=self.toggle)
        self.btn.pack(fill="x", padx=30, pady=10, ipady=8)

    def toggle(self):
        if not self.is_connected:
            self.connect_proxy()
        else:
            self.disconnect_proxy()
            
    def connect_proxy(self):
        ip = self.ip_entry.get().strip()
        pin = self.pin_entry.get().strip()
        
        if not ip or not pin:
            messagebox.showwarning("Hata", "Lütfen IP ve PIN girin!")
            return
            
        self.status_label.config(text="Durum: Doğrulanıyor...", fg="#FBBF24")
        self.root.update()
        
        try:
            auth_url = f"http://{ip}:8081/__netshare_auth?pin={pin}"
            proxy_handler = urllib.request.ProxyHandler({})
            opener = urllib.request.build_opener(proxy_handler)
            response = opener.open(auth_url, timeout=3)
            if response.status != 200 or response.read().decode('utf-8') != 'auth_success':
                raise Exception("PIN Hatalı")
        except Exception as e:
            self.status_label.config(text="Durum: Doğrulama Başarısız!", fg="#EF4444")
            messagebox.showerror("Hata", f"Bağlantı hatası veya PIN yanlış:\n{e}")
            return
            
        with open("config.txt", "w") as f:
            f.write(ip)
            
        if set_proxy(True, ip, "8080"):
            self.is_connected = True
            self.btn.config(text="Bağlantıyı Kes", bg="#EF4444", activebackground="#DC2626")
            self.ip_entry.config(state="disabled")
            self.pin_entry.config(state="disabled")
            
            self.status_label.config(text="Durum: Korumalı SOCKS5 Aktif", fg="#10B981")
            
            if self.lock_var.get():
                self.running_ping = True
                self.ping_thread = threading.Thread(target=self.ping_loop, args=(ip,), daemon=True)
                self.ping_thread.start()
        else:
            self.status_label.config(text="Durum: Proxy ayarlanamadı!", fg="#EF4444")

    def disconnect_proxy(self):
        self.running_ping = False
        set_proxy(False)
        self.is_connected = False
        
        self.btn.config(text="Bağlan (SOCKS5)", bg="#3B82F6", activebackground="#2563EB")
        self.ip_entry.config(state="normal")
        self.pin_entry.config(state="normal")
        
        self.status_label.config(text="Durum: Bağlantı Kesildi", fg="#94A3B8")
        
    def ping_loop(self, ip):
        url = f"http://{ip}:8081/__netshare_ping"
        while self.running_ping:
            try:
                proxy_handler = urllib.request.ProxyHandler({})
                opener = urllib.request.build_opener(proxy_handler)
                response = opener.open(url, timeout=2)
                
                if response.status == 200 and response.read().decode('utf-8') == 'pong':
                    self.root.after(0, lambda: self.update_ping_status(True))
                else:
                    self.root.after(0, lambda: self.update_ping_status(False))
            except:
                self.root.after(0, lambda: self.update_ping_status(False))
            time.sleep(2)
            
    def update_ping_status(self, is_ok):
        if not self.is_connected: return
        if not is_ok:
            self.status_label.config(text="Durum: BAĞLANTI KOPTU! Trafik Engellendi.", fg="#EF4444")
        else:
            self.status_label.config(text="Durum: Korumalı SOCKS5 Aktif", fg="#10B981")
            
    def on_close(self):
        if self.is_connected:
            self.disconnect_proxy()
        self.root.destroy()

if __name__ == '__main__':
    set_proxy(False)
    root = tk.Tk()
    app = App(root)
    root.protocol("WM_DELETE_WINDOW", app.on_close)
    root.mainloop()
