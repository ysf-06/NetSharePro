import SwiftUI
import CoreImage.CIFilterBuiltins

struct ConnectionQRView: View {
    let ipAddress: String?
    let socksPort: UInt16
    let controlPort: UInt16
    let pin: String
    let deviceName: String

    @Environment(\.dismiss) private var dismiss

    private var connectionText: String {
        let ip = ipAddress ?? "<telefon-ip>"
        return """
        NetShare Pro Baglanti Bilgisi
        Telefon IP: \(ip)
        SOCKS5 Proxy: \(ip):\(socksPort)
        Kontrol: \(ip):\(controlPort)
        PIN: \(pin)
        Cihaz: \(deviceName)
        """
    }

    private var qrImage: UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(connectionText.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(AppTheme.cardLine)
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Text("Baglanti Kodu")
                .font(.headline)
                .foregroundColor(AppTheme.primaryText)

            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .background(Color.white)
                    .cornerRadius(16)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.card)
                    .frame(width: 240, height: 240)
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.secondaryText)
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(connectionText)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(AppTheme.secondaryText)
                    .textSelection(.enabled)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(cornerRadius: 14)

            Button {
                UIPasteboard.general.string = connectionText
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Bilgileri Kopyala", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accentGradient)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}
