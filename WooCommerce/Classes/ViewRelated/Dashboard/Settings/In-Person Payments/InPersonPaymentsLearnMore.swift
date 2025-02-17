import SwiftUI

struct InPersonPaymentsLearnMore: View {
    @Environment(\.customOpenURL) var customOpenURL

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            Image(uiImage: .infoOutlineImage)
                .accentColor(Color(.lightGray))
                .frame(width: 20, height: 20)
            AttributedText(Localization.learnMore)
                .accentColor(Color(.textLink))
                .customOpenURL { url in
                    ServiceLocator.analytics.track(.cardPresentOnboardingLearnMoreTapped)
                    customOpenURL?(url)
                }
        }
    }
}

private enum Localization {
    static let unavailable = NSLocalizedString(
        "In-Person Payments is currently unavailable",
        comment: "Title for the error screen when In-Person Payments is unavailable"
    )

    static let acceptCash = NSLocalizedString(
        "You can still accept in-person cash payments by enabling the “Cash on Delivery” payment method on your store.",
        comment: "Generic error message when In-Person Payments is unavailable"
    )

    static let learnMore: NSAttributedString = {
        let learnMoreText = NSLocalizedString(
            "<a href=\"https://woocommerce.com/payments\">Learn more</a> about accepting payments with your mobile device and ordering card readers",
            comment: "A label prompting users to learn more about card readers with an embedded hyperlink"
        )

        let learnMoreAttributes: [NSAttributedString.Key: Any] = [
            .font: StyleManager.footerLabelFont,
            .foregroundColor: UIColor.textSubtle
        ]

        let learnMoreAttrText = NSMutableAttributedString()
        learnMoreAttrText.append(learnMoreText.htmlToAttributedString)
        let range = NSRange(location: 0, length: learnMoreAttrText.length)
        learnMoreAttrText.addAttributes(learnMoreAttributes, range: range)

        return learnMoreAttrText
    }()
}

struct InPersonPaymentsLearnMore_Previews: PreviewProvider {
    static var previews: some View {
        InPersonPaymentsLearnMore()
            .padding()
    }
}
