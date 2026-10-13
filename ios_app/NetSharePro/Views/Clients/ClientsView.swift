import SwiftUI

struct ClientsView: View {
    @ObservedObject var viewModel: ClientsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if viewModel.clients.isEmpty && viewModel.bannedIPs.isEmpty && viewModel.discoveredServers.isEmpty {
                    emptyState
                }

                if !viewModel.clients.isEmpty {
                    SectionCard(title: "Bağlı Cihazlar & Kota") {
                        VStack(spacing: 12) {
                            ForEach(viewModel.clients) { client in
                                ClientRowView(client: client)
                                    .contextMenu {
                                        Button {
                                            viewModel.beginQuotaEditing(for: client)
                                        } label: {
                                            Label("Kota Sınırı Ayarla", systemImage: "speedometer")
                                        }
                                        Button(role: .destructive) {
                                            viewModel.revokeAccess(client)
                                        } label: {
                                            Label("Yetkiyi Kaldır", systemImage: "xmark.circle")
                                        }
                                        Button(role: .destructive) {
                                            viewModel.banClient(client)
                                        } label: {
                                            Label("Kalıcı Olarak Yasakla", systemImage: "nosign")
                                        }
                                    }
                            }
                        }
                    }
                }

                if !viewModel.bannedIPs.isEmpty {
                    SectionCard(title: "Yasaklı Adresler") {
                        VStack(spacing: 10) {
                            ForEach(viewModel.bannedIPs, id: \.self) { ip in
                                HStack {
                                    Image(systemName: "nosign")
                                        .foregroundColor(AppTheme.danger)
                                    Text(ip)
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(AppTheme.primaryText)
                                    Spacer()
                                    Button("Kaldır") {
                                        viewModel.unban(ip: ip)
                                    }
                                    .font(.caption.weight(.semibold))
                                }
                            }
                        }
                    }
                }

                if !viewModel.discoveredServers.isEmpty {
                    SectionCard(title: "Keşfedilen NetShare Sunucuları") {
                        VStack(spacing: 10) {
                            ForEach(viewModel.discoveredServers) { server in
                                HStack(spacing: 10) {
                                    Image(systemName: "bonjour")
                                        .foregroundColor(AppTheme.accentLight)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(server.name)
                                            .font(.footnote.weight(.semibold))
                                            .foregroundColor(AppTheme.primaryText)
                                        Text("Yerel ağda yayınlanıyor")
                                            .font(.caption2)
                                            .foregroundColor(AppTheme.secondaryText)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Cihazlar")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "Kota Sınırı (MB)",
            isPresented: $viewModel.isPresentingQuotaAlert
        ) {
            TextField("Örn: 500", text: $viewModel.quotaInput)
                .keyboardType(.numberPad)
            Button("Kaydet") {
                viewModel.commitQuotaInput()
            }
            Button("İptal", role: .cancel) {
                viewModel.quotaEditingClient = nil
            }
        } message: {
            Text("0 veya boş bırakırsanız kota sınırı kaldırılır.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 42))
                .foregroundColor(AppTheme.secondaryText)
            Text("Henüz kimse bağlı değil")
                .font(.headline)
                .foregroundColor(AppTheme.primaryText)
            Text("Windows istemcisinden telefonun IP adresi ve PIN ile bağlanın.\nYetkili cihazlar burada listelenecek.")
                .font(.footnote)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct ClientRowView: View {
    let client: ConnectedClient

    private var quotaProgress: Double? {
        guard let quota = client.quotaBytes, quota > 0 else { return nil }
        return min(1, Double(client.usedBytes) / Double(quota))
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "desktopcomputer")
                    .foregroundColor(AppTheme.accentLight)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(client.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.primaryText)
                    PulsingDot(color: client.isOnline ? AppTheme.teal : AppTheme.secondaryText, isActive: client.isOnline)
                }
                Text(client.ip)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(AppTheme.secondaryText)
                Text("↓ \(ByteFormatter.bytes(client.bytesDownloaded))   ↑ \(ByteFormatter.bytes(client.bytesUploaded))")
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText)
            }

            Spacer()

            if let progress = quotaProgress, let quota = client.quotaBytes {
                VStack(alignment: .trailing, spacing: 4) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(progress > 0.9 ? AppTheme.danger : AppTheme.warning)
                        .frame(width: 74)
                    Text("%\(Int(progress * 100)) / \(ByteFormatter.bytes(quota))")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                }
            } else {
                Image(systemName: "infinity")
                    .foregroundColor(AppTheme.cardLine)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.background.opacity(0.55))
        )
    }
}
