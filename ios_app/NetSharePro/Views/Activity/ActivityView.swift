import SwiftUI

struct ActivityView: View {
    @ObservedObject var viewModel: ActivityViewModel
    @State private var isConfirmingClear = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryRow

                if viewModel.isEmpty {
                    emptyState
                } else {
                    SectionCard(title: "URL Geçmişi (Ebeveyn Modu)") {
                        VStack(spacing: 10) {
                            ForEach(viewModel.events) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Etkinlik")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isConfirmingClear = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(AppTheme.danger)
                }
                .disabled(viewModel.isEmpty)
            }
        }
        .confirmationDialog(
            "Geçmiş temizlensin mi?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Tümünü Sil", role: .destructive) {
                viewModel.clearHistory()
            }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            StatTile(
                icon: "globe",
                title: "Kayıtlı Alan Adı",
                value: "\(viewModel.events.count)",
                tint: AppTheme.accentLight
            )
            StatTile(
                icon: "hand.raised.fill",
                title: "Engellenen",
                value: "\(viewModel.blockedCount)",
                tint: AppTheme.danger
            )
        }
    }

    private func eventRow(_ event: ActivityEvent) -> some View {
        HStack(spacing: 10) {
            PulsingDot(
                color: event.wasBlocked ? AppTheme.danger : AppTheme.teal,
                isActive: false
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(event.host)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(event.wasBlocked ? AppTheme.danger : AppTheme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(event.timestamp.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(AppTheme.secondaryText)
            }
            Spacer()
            if event.wasBlocked {
                Text("ENGELLENDİ")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.5)
                    .foregroundColor(AppTheme.danger)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.danger.opacity(0.15)))
            }
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 42))
                .foregroundColor(AppTheme.secondaryText)
            Text("Etkinlik kaydı yok")
                .font(.headline)
                .foregroundColor(AppTheme.primaryText)
            Text("İstemciler alan adı (domain) bazlı istek gönderdiğinde kayıtlar burada görünür. IP bazlı istekler kaydedilmez.")
                .font(.footnote)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
