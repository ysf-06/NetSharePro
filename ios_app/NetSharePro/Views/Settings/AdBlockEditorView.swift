import SwiftUI

struct AdBlockEditorView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var newDomain = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SectionCard(title: "Özel Alan Adı Ekle") {
                    HStack(spacing: 10) {
                        TextField("ornek-reklam.com", text: $newDomain)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(AppTheme.primaryText)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppTheme.background.opacity(0.7))
                            )
                        Button {
                            addDomain()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(AppTheme.teal)
                        }
                        .buttonStyle(.plain)
                        .disabled(trimmedDomain.isEmpty)
                    }
                    Text("Alt alan adları otomatik kapsanır (cdn.ornek-reklam.com gibi).")
                        .font(.caption2)
                        .foregroundColor(AppTheme.secondaryText)
                }

                if !settings.customBlockedDomains.isEmpty {
                    SectionCard(title: "Özel Liste (\(settings.customBlockedDomains.count))") {
                        VStack(spacing: 10) {
                            ForEach(settings.customBlockedDomains, id: \.self) { domain in
                                HStack {
                                    Image(systemName: "xmark.shield.fill")
                                        .foregroundColor(AppTheme.danger)
                                    Text(domain)
                                        .font(.system(.footnote, design: .monospaced))
                                        .foregroundColor(AppTheme.primaryText)
                                    Spacer()
                                    Button {
                                        removeDomain(domain)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(AppTheme.secondaryText)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                SectionCard(title: "Yerleşik Liste (\(AdBlockService.defaultBlockedDomains.count))") {
                    VStack(spacing: 10) {
                        ForEach(AdBlockService.defaultBlockedDomains, id: \.self) { domain in
                            HStack {
                                Image(systemName: "lock.shield")
                                    .foregroundColor(AppTheme.cardLine)
                                Text(domain)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundColor(AppTheme.secondaryText)
                                Spacer()
                                Text("yerleşik")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.secondaryText)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Ad-Block Listesi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var trimmedDomain: String {
        newDomain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func addDomain() {
        let domain = trimmedDomain
        guard !domain.isEmpty,
              !settings.customBlockedDomains.contains(domain),
              !AdBlockService.defaultBlockedDomains.contains(domain) else { return }
        settings.customBlockedDomains.append(domain)
        newDomain = ""
    }

    private func removeDomain(_ domain: String) {
        settings.customBlockedDomains.removeAll { $0 == domain }
    }
}
