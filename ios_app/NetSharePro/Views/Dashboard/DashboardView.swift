import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusSection
                connectionInfoSection
                controlButton
                if viewModel.isActive {
                    speedSection
                    trafficSection
                }
                if case .failed(let message) = viewModel.runState {
                    ErrorBanner(text: message)
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("NetShare Pro")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.isPresentingQR) {
            ConnectionQRView(
                ipAddress: viewModel.phoneIPAddress,
                socksPort: ProtocolConstants.defaultSocksPort,
                controlPort: ProtocolConstants.defaultControlPort,
                pin: viewModel.pin,
                deviceName: viewModel.deviceName
            )
        }
    }

    private var statusSection: some View {
        VStack(spacing: 16) {
            StatusRingView(
                isActive: viewModel.isActive,
                subtitle: statusSubtitle
            )

            HStack(spacing: 12) {
                summaryChip(
                    icon: "laptopcomputer.and.iphone",
                    text: "\(viewModel.onlineClientCount)/\(viewModel.connectedClientCount) cihaz çevrimiçi",
                    tint: viewModel.onlineClientCount > 0 ? AppTheme.teal : AppTheme.secondaryText
                )
                summaryChip(
                    icon: "hand.raised.fill",
                    text: "\(viewModel.blockedDomainCount) engellenen",
                    tint: viewModel.blockedDomainCount > 0 ? AppTheme.danger : AppTheme.secondaryText
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var statusSubtitle: String {
        guard viewModel.isActive else {
            return "Paylaşıma başlamak için kalkanı başlat"
        }
        if let ip = viewModel.phoneIPAddress {
            return "\(ip) üzerinden paylaşılıyor"
        }
        return "Ağ adresi alınıyor..."
    }

    private var connectionInfoSection: some View {
        SectionCard(title: "Bağlantı Bilgisi") {
            CopyableField(label: "Telefon IP Adresi", value: viewModel.phoneIPAddress ?? "—")
            Divider().overlay(AppTheme.cardLine)
            CopyableField(label: "SOCKS5 Portu", value: viewModel.socksPortText, icon: "point.3.connected.trianglepath.dotted")
            Divider().overlay(AppTheme.cardLine)
            CopyableField(label: "Kontrol Portu", value: viewModel.controlPortText, icon: "point.3.connected.trianglepath.dotted")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Güvenlik PIN")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondaryText)
                    Text(viewModel.pin)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundColor(AppTheme.warning)
                }
                Spacer()
                Button {
                    viewModel.isPresentingQR = true
                } label: {
                    Image(systemName: "qrcode")
                        .font(.title2)
                        .foregroundColor(AppTheme.accentLight)
                        .padding(10)
                        .background(Circle().fill(AppTheme.cardLine.opacity(0.4)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var controlButton: some View {
        Button {
            viewModel.toggleShield()
        } label: {
            HStack(spacing: 10) {
                if viewModel.runState == .starting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: viewModel.isActive ? "stop.fill" : "play.fill")
                }
                Text(viewModel.isActive ? "Sistemi Durdur" : "Kalkanı Başlat")
                    .font(.system(size: 18, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(viewModel.isActive ? AppTheme.dangerGradient : AppTheme.accentGradient)
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: (viewModel.isActive ? AppTheme.danger : AppTheme.accent).opacity(0.35), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.runState == .starting)
    }

    private var speedSection: some View {
        HStack(spacing: 12) {
            StatTile(
                icon: "arrow.down.circle.fill",
                title: "İndirme",
                value: ByteFormatter.kilobytesPerSecond(viewModel.currentDownloadKBps),
                tint: AppTheme.accentLight
            )
            StatTile(
                icon: "arrow.up.circle.fill",
                title: "Yükleme",
                value: ByteFormatter.kilobytesPerSecond(viewModel.currentUploadKBps),
                tint: AppTheme.teal
            )
        }
    }

    private var trafficSection: some View {
        SectionCard {
            SpeedChartView(
                downloadSeries: viewModel.downloadSpeedHistory,
                uploadSeries: viewModel.uploadSpeedHistory
            )
        }
    }

    private func summaryChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(tint)
            Text(text)
                .font(.caption)
                .foregroundColor(AppTheme.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(AppTheme.card))
    }
}
