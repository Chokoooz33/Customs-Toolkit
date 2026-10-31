import SwiftUI

public struct AppSegmentedPicker<T: Hashable & Identifiable>: View {
    let items: [T]
    @Binding var selection: T
    let titleProvider: (T) -> String
    
    public init(
        items: [T],
        selection: Binding<T>,
        titleProvider: @escaping (T) -> String
    ) {
        self.items = items
        self._selection = selection
        self.titleProvider = titleProvider
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                let isSelected = (selection == item)
                Button(action: {
                    HapticFeedback.selection()
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = item
                    }
                }) {
                    Text(titleProvider(item))
                        .font(AppTypography.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(isSelected ? AppColors.brandPrimary : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ?
                                AppColors.cardBackground :
                                Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                        .overlay(
                            isSelected ?
                                RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                    .stroke(AppColors.subtleBorder, lineWidth: 0.5) :
                                nil
                        )
                }
            }
        }
        .padding(3)
        .background(AppColors.innerCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }
}
