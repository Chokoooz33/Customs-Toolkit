import SwiftUI

#if os(iOS) && canImport(VisionKit)
import VisionKit
import UIKit

public struct HSCodeCameraScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [String] = []
    @State private var selectedCode: String?

    let onSelect: (String) -> Void

    public init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    LiveTextScanner { text in
                        updateCandidates(from: text)
                    }
                    .ignoresSafeArea()

                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "viewfinder")
                            Text(LanguageManager.shared.string(.hsCameraAimHint))
                            Spacer()
                        }
                        .font(AppTypography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.black.opacity(0.66))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                        if candidates.isEmpty {
                            Text(LanguageManager.shared.string(.hsCameraSearching))
                                .font(AppTypography.subheadline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(.black.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            candidatePanel
                        }
                    }
                    .padding(AppSpacing.medium)
                } else {
                    AppEmptyStateView(
                        icon: "camera.fill",
                        title: LanguageManager.shared.string(.hsCameraUnavailableTitle),
                        description: LanguageManager.shared.string(.hsCameraUnavailableDescription)
                    )
                    .padding(AppSpacing.large)
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(LanguageManager.shared.string(.hsCameraTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LanguageManager.shared.string(.close)) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black.opacity(0.85), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var candidatePanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(LanguageManager.shared.string(.hsCameraCandidatesTitle))
                .font(AppTypography.headline)
                .foregroundStyle(.white)

            ForEach(candidates.prefix(5), id: \.self) { code in
                Button {
                    HapticFeedback.selection()
                    selectedCode = code
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: selectedCode == code ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedCode == code ? AppColors.brandGold : .white.opacity(0.72))
                        Text(HSNormalizer.formatForDisplay(code))
                            .font(AppTypography.technicalNumberSmall)
                            .foregroundStyle(.white)
                            .preserveTechnicalLTR()
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(selectedCode == code ? 0.13 : 0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {
                guard let code = selectedCode ?? candidates.first else { return }
                HapticFeedback.success()
                onSelect(code)
                dismiss()
            } label: {
                Text(LanguageManager.shared.string(.hsCameraUseSelected))
                    .font(AppTypography.headline)
                    .foregroundStyle(AppColors.brandDeepNavy)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(AppColors.brandGold)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.black.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func updateCandidates(from text: String) {
        let extracted = HSCodeCandidateExtractor.candidates(from: text)
        guard !extracted.isEmpty else { return }

        var merged = candidates
        for candidate in extracted where !merged.contains(candidate) {
            merged.append(candidate)
        }
        merged.sort {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0 < $1
        }
        candidates = Array(merged.prefix(8))
        if selectedCode == nil {
            selectedCode = candidates.first
        }
    }
}

private struct LiveTextScanner: UIViewControllerRepresentable {
    let onText: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onText: onText)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onText: (String) -> Void

        init(onText: @escaping (String) -> Void) {
            self.onText = onText
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            emit(allItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didUpdate updatedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            emit(allItems)
        }

        private func emit(_ items: [RecognizedItem]) {
            let text = items.compactMap { item -> String? in
                if case .text(let recognizedText) = item {
                    return recognizedText.transcript
                }
                return nil
            }
            .joined(separator: "\n")

            guard !text.isEmpty else { return }
            onText(text)
        }
    }
}
#else
public struct HSCodeCameraScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void

    public init(onSelect: @escaping (String) -> Void) {
        self.onSelect = onSelect
    }

    public var body: some View {
        AppEmptyStateView(
            icon: "camera.fill",
            title: LanguageManager.shared.string(.hsCameraUnavailableTitle),
            description: LanguageManager.shared.string(.hsCameraUnavailableDescription)
        )
        .padding()
    }
}
#endif
