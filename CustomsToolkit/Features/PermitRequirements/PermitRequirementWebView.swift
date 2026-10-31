import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

public struct PermitRequirementWebView: View {
    let hsCode: String

    public init(hsCode: String) {
        self.hsCode = HSNormalizer.normalize(hsCode)
    }

    public var body: some View {
        VStack(spacing: 0) {
            AppCard {
                HStack(spacing: AppSpacing.small) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(AppColors.brandPrimary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LanguageManager.shared.string(.permitOfficialCheck))
                            .font(AppTypography.headline)
                        Text(LanguageManager.shared.string(.permitCaptchaNotice))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Button {
                        ClipboardService.copy(hsCode)
                        HapticFeedback.success()
                    } label: {
                        Text(hsCode)
                            .font(AppTypography.technicalNumberMedium)
                            .foregroundStyle(AppColors.brandPrimary)
                            .preserveTechnicalLTR()
                    }
                }
            }
            .padding(AppSpacing.medium)

            #if canImport(WebKit) && os(iOS)
            PermitWebContainer(hsCode: hsCode)
            #else
            if let url = URL(string: AppConfig.omanHSRequirementsURL) {
                Link(LanguageManager.shared.string(.permitOpenOfficial), destination: url)
                    .padding()
            }
            #endif
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle(LanguageManager.shared.string(.permitTitle))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if canImport(WebKit) && os(iOS)
private struct PermitWebContainer: UIViewRepresentable {
    let hsCode: String

    func makeCoordinator() -> Coordinator { Coordinator(hsCode: hsCode) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        if let url = URL(string: AppConfig.omanHSRequirementsURL) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let hsCode: String
        init(hsCode: String) { self.hsCode = hsCode }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let escaped = hsCode.replacingOccurrences(of: "'", with: "\\'")
            let script = """
            (() => {
              const visible = el => !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
              const inputs = [...document.querySelectorAll('input[type="text"], input:not([type])')].filter(visible);
              const candidate = inputs.find(el => {
                const hay = `${el.id || ''} ${el.name || ''} ${el.placeholder || ''}`.toLowerCase();
                return hay.includes('hs') || hay.includes('code');
              });
              if (!candidate) return false;
              const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')?.set;
              if (setter) setter.call(candidate, '\(escaped)'); else candidate.value = '\(escaped)';
              candidate.dispatchEvent(new Event('input', {bubbles:true}));
              candidate.dispatchEvent(new Event('change', {bubbles:true}));
              return true;
            })();
            """
            webView.evaluateJavaScript(script)
        }
    }
}
#endif
