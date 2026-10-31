import SwiftUI
import WebKit

public struct GoldPriceWebView: View {
    @State private var isLoading: Bool = true
    @State private var hasError: Bool = false
    @State private var webViewID = UUID()
    
    private let targetURLString = AppConfig.trustedGoldPriceURL
    
    public init() {}
    
    public var body: some View {
        Group {
            if targetURLString == "TO_BE_PROVIDED" || URL(string: targetURLString) == nil {
                // Pending URL State
                ScrollView {
                    VStack(spacing: AppSpacing.large) {
                        AppEmptyStateView(
                            icon: "link.badge.plus",
                            title: LanguageManager.shared.string(.goldPriceUrlPending),
                            description: LanguageManager.shared.string(.goldPriceUrlPendingDesc)
                        )
                        
                        AppCard {
                            VStack(alignment: .leading, spacing: AppSpacing.small) {
                                Text("Configuration Target:")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text("AppConfig.trustedGoldPriceURL")
                                    .font(AppTypography.technicalNumberSmall)
                                    .foregroundColor(AppColors.brandPrimary)
                                    .preserveTechnicalLTR()
                                
                                Divider()
                                
                                Text("Current Value:")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text(targetURLString)
                                    .font(AppTypography.technicalNumberSmall)
                                    .foregroundColor(AppColors.textTertiary)
                                    .preserveTechnicalLTR()
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(AppSpacing.medium)
                }
            } else if let validURL = URL(string: targetURLString) {
                // In-App Browser
                ZStack {
                    #if os(iOS)
                    WKWebViewRepresentable(
                        url: validURL,
                        isLoading: $isLoading,
                        hasError: $hasError,
                        id: webViewID
                    )
                    #else
                    Text("In-App Browser for iOS: \(validURL.absoluteString)")
                    #endif
                    
                    if isLoading {
                        VStack(spacing: AppSpacing.small) {
                            ProgressView()
                            Text(LanguageManager.shared.string(.webViewLoading))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.large)
                        .background(AppColors.cardBackground.opacity(0.95))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                    }
                    
                    if hasError && !isLoading {
                        VStack(spacing: AppSpacing.medium) {
                            AppEmptyStateView(
                                icon: "wifi.exclamationmark",
                                title: LanguageManager.shared.string(.webViewError),
                                description: LanguageManager.shared.string(.webViewSecureConnectionError),
                                buttonTitle: LanguageManager.shared.string(.retry)
                            ) {
                                hasError = false
                                isLoading = true
                                webViewID = UUID()
                            }
                        }
                        .background(AppColors.background)
                    }
                }
            }
        }
        .background(AppColors.groupedBackground.ignoresSafeArea())
        .navigationTitle(LanguageManager.shared.string(.toolGoldPrice))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if targetURLString != "TO_BE_PROVIDED" && URL(string: targetURLString) != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        HapticFeedback.selection()
                        hasError = false
                        isLoading = true
                        webViewID = UUID()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

#if os(iOS)
// MARK: - WKWebView UIViewRepresentable Wrapper for iOS
struct WKWebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    let id: UUID
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No-op for standard reload via ID change
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WKWebViewRepresentable
        
        init(_ parent: WKWebViewRepresentable) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.hasError = false
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.hasError = true
            }
        }
    }
}
#endif
