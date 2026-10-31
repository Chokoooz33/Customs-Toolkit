import SwiftUI

public struct ResultRowData: Identifiable {
    public let id = UUID()
    public let label: String
    public let value: String
    public let isEmphasized: Bool
    
    public init(label: String, value: String, isEmphasized: Bool = false) {
        self.label = label
        self.value = value
        self.isEmphasized = isEmphasized
    }
}

public struct AppResultCard: View {
    let title: String
    let primaryValue: String
    let primaryUnit: String?
    let rows: [ResultRowData]
    let onCopy: () -> Void
    let onReset: (() -> Void)?
    
    @State private var showCopiedAlert = false
    
    public init(
        title: String,
        primaryValue: String,
        primaryUnit: String? = nil,
        rows: [ResultRowData] = [],
        onCopy: @escaping () -> Void,
        onReset: (() -> Void)? = nil
    ) {
        self.title = title
        self.primaryValue = primaryValue
        self.primaryUnit = primaryUnit
        self.rows = rows
        self.onCopy = onCopy
        self.onReset = onReset
    }
    
    public var body: some View {
        VStack(spacing: AppSpacing.medium) {
            // Header
            HStack {
                Text(title)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                if let onReset = onReset {
                    Button(action: {
                        HapticFeedback.impact(style: .light)
                        onReset()
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            
            // Primary Value
            VStack(spacing: AppSpacing.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xSmall) {
                    Text(primaryValue)
                        .font(AppTypography.technicalNumberLarge)
                        .foregroundColor(AppColors.brandPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    
                    if let unit = primaryUnit {
                        Text(unit)
                            .font(AppTypography.headline)
                            .foregroundColor(AppColors.brandPrimary)
                    }
                }
                .preserveTechnicalLTR()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.small)
            
            // Breakdown Rows
            if !rows.isEmpty {
                Divider()
                    .background(AppColors.subtleBorder)
                
                VStack(spacing: AppSpacing.xSmall) {
                    ForEach(rows) { row in
                        HStack {
                            Text(row.label)
                                .font(AppTypography.callout)
                                .foregroundColor(row.isEmphasized ? AppColors.textPrimary : AppColors.textSecondary)
                            
                            Spacer()
                            
                            Text(row.value)
                                .font(row.isEmphasized ? AppTypography.headline : AppTypography.callout)
                                .foregroundColor(row.isEmphasized ? AppColors.brandPrimary : AppColors.textPrimary)
                                .preserveTechnicalLTR()
                        }
                    }
                }
            }
            
            // Copy Button
            AppButton(
                showCopiedAlert ? LanguageManager.shared.string(.copied) : LanguageManager.shared.string(.copyResult),
                icon: showCopiedAlert ? "checkmark" : "doc.on.doc",
                style: showCopiedAlert ? .secondary : .primary
            ) {
                onCopy()
                HapticFeedback.success()
                withAnimation {
                    showCopiedAlert = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation {
                        showCopiedAlert = false
                    }
                }
            }
        }
        .padding(AppSpacing.medium)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                .stroke(AppColors.subtleBorder, lineWidth: 1)
        )
    }
}
