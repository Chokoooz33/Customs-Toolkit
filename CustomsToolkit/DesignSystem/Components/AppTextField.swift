import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct AppTextField: View {
    let label: String?
    let placeholder: String
    @Binding var text: String
    let suffix: String?
    #if os(iOS)
    let keyboardType: UIKeyboardType
    #endif
    let isMonospaced: Bool
    let errorMessage: String?
    
    #if os(iOS)
    public init(
        label: String? = nil,
        placeholder: String,
        text: Binding<String>,
        suffix: String? = nil,
        keyboardType: UIKeyboardType = .decimalPad,
        isMonospaced: Bool = true,
        errorMessage: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.suffix = suffix
        self.keyboardType = keyboardType
        self.isMonospaced = isMonospaced
        self.errorMessage = errorMessage
    }
    #else
    public init(
        label: String? = nil,
        placeholder: String,
        text: Binding<String>,
        suffix: String? = nil,
        isMonospaced: Bool = true,
        errorMessage: String? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.suffix = suffix
        self.isMonospaced = isMonospaced
        self.errorMessage = errorMessage
    }
    #endif
    
    public var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxSmall) {
            if let label = label {
                Text(label)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            HStack(spacing: AppSpacing.small) {
                #if os(iOS)
                TextField(placeholder, text: $text)
                    .font(isMonospaced ? AppTypography.technicalNumberMedium : AppTypography.body)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                #else
                TextField(placeholder, text: $text)
                    .font(isMonospaced ? AppTypography.technicalNumberMedium : AppTypography.body)
                    .autocorrectionDisabled()
                #endif
                
                if !text.isEmpty {
                    Button(action: {
                        HapticFeedback.selection()
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                if let suffix = suffix {
                    Text(suffix)
                        .font(AppTypography.headline)
                        .foregroundColor(AppColors.brandPrimary)
                        .padding(.horizontal, AppSpacing.xSmall)
                        .padding(.vertical, 4)
                        .background(AppColors.brandPrimary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                }
            }
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, 12)
            .background(AppColors.innerCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(errorMessage != nil ? AppColors.error : AppColors.subtleBorder, lineWidth: 1)
            )
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.error)
            }
        }
    }
}
