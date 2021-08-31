import SwiftUI

/// Represents a large title, mostly to be used at the top of view controllers like What's New Component
struct LargeTitleView: View {
    let text: String

    var body: some View {
        Text(text)
            .multilineTextAlignment(.center)
            .font(.system(size: 34, weight: .bold, design: .default))
    }
}

// MARK: - Preview
struct LargeTitleView_Previews: PreviewProvider {
    static var previews: some View {
        LargeTitleView(text: "What's New in WooCommerce")
    }
}
