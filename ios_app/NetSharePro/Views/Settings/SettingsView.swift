import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: SettingsStore
    @ObservedObject var viewModel: SettingsViewModel
    @State private var isPINVisible = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                generalSection
                securitySection
                adBlockSection
                bandwidthSection
                quotaSection
                aboutSection
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var generalSection: some View {
        SectionCard(title: "Genel") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cihaz Adı")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
                TextField("iPhone Paylaşım Noktası", text: $settings.deviceName)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(AppTheme.primaryText)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(AppTheme.background.opacity(0.7))
                    )
            }
            Toggle(isOn: $settings.keepScreenAwake) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ekranı Açık Tut")
                        .foregroundColor(AppTheme.primaryText)
                    Text("Paylaşım sırasında ekran kilitlenmesin (arka planda iOS soketleri askıya alır).")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .tint(AppTheme.accent)
        }
    }

    private var securitySection: some View {
        SectionCard(title: "Güvenlik") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Güvenlik PIN")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    Text(isPINVisible ? viewModel.pin : "••••")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundColor(AppTheme.warning)
                        .textSelection(.enabled)
                }
                Spacer()
                Button {
                    isPINVisible.toggle()
                } label: {
                    Image(systemName: isPINVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(AppTheme.accentLight)
                }
                .buttonStyle(.plain)
                Button {
                    viewModel.regeneratePIN()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.teal)
                }
                .buttonStyle(.plain)
            }
            Text("PIN değiştirildiğinde tüm yetkilendirmeler sıfırlanır; istemcilerin yeniden kimlik doğrulaması gerekir.")
                .font(.caption2)
                .foregroundColor(AppTheme.secondaryText)
        }
    }

    private var adBlockSection: some View {
        SectionCard(title: "Reklam Engelleyici") {
            Toggle(isOn: $settings.adBlockEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ağ Seviyesinde Ad-Block")
                        .foregroundColor(AppTheme.primaryText)
                    Text("Bilinen reklam sunucuları bağlantı aşamasında engellenir (Pi-Hole benzeri).")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .tint(AppTheme.teal)

            NavigationLink(destination: AdBlockEditorView()) {
                HStack {
                    Label("Engel Listesini Düzenle", systemImage: "list.bullet.rectangle")
                        .foregroundColor(AppTheme.accentLight)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var bandwidthSection: some View {
        SectionCard(title: "Bant Genişliği") {
            VStack(alignment: .leading, spacing: 8) {
                Text("İstemciye Giden Hız Sınırı")
                    .font(.caption)
                    .foregroundColor(AppTheme.secondaryText)
                Picker("Hız Sınırı", selection: $settings.speedLimitIndex) {
                    ForEach(0..<SettingsStore.speedLimitOptions.count, id: \.self) { index in
                        Text(SettingsStore.speedLimitOptions[index].label)
                            .tag(index)
                    }
                }
                .pickerStyle(.menu)
                .foregroundColor(AppTheme.primaryText)
            }
        }
    }

    private var quotaSection: some View {
        SectionCard(title: "Varsayılan Kota") {
            Stepper(
                value: $settings.defaultQuotaMB,
                in: 0...102_400,
                step: 100
            ) {
                HStack {
                    Text("Cihaz Başı Kota")
                        .foregroundColor(AppTheme.primaryText)
                    Spacer()
                    Text(settings.defaultQuotaMB > 0 ? "\(settings.defaultQuotaMB) MB" : "Sınırsız")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(AppTheme.warning)
                }
            }
            Text("Yeni bağlanan her istemciye uygulanır; cihaz listesinden tek tek değiştirilebilir.")
                .font(.caption2)
                .foregroundColor(AppTheme.secondaryText)
        }
    }

    private var aboutSection: some View {
        SectionCard(title: "Hakkında") {
            infoRow("Sürüm", viewModel.appVersion)
            infoRow("SOCKS5 Portu", String(viewModel.socksPort))
            infoRow("Kontrol Portu", String(viewModel.controlPort))
            infoRow("Ağ Arayüzleri", viewModel.interfaceSummary.isEmpty ? "—" : viewModel.interfaceSummary)
            infoRow("Protokol", "SOCKS5 · SOCKS4/4a · HTTP")
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(AppTheme.primaryText)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
