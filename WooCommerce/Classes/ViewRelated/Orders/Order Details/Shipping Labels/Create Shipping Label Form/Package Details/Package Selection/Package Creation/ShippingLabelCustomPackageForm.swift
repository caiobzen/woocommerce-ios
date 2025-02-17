import SwiftUI

/// Form to create a new custom package to use with shipping labels.
struct ShippingLabelCustomPackageForm: View {
    @ObservedObject private var viewModel = ShippingLabelCustomPackageFormViewModel()
    private let safeAreaInsets: EdgeInsets

    init(safeAreaInsets: EdgeInsets) {
        self.safeAreaInsets = safeAreaInsets
    }

    var body: some View {
        VStack(spacing: Constants.verticalSpacing) {
                ListHeaderView(text: Localization.customPackageHeader, alignment: .left)
                    .padding(.horizontal, insets: safeAreaInsets)

                VStack(spacing: 0) {
                    Divider()

                    VStack(spacing: 0) {
                        TitleAndValueRow(title: Localization.packageTypeLabel,
                                         value: Localization.packageTypePlaceholder,
                                         selectable: true) {
                            // TODO-4743: Navigate to Package Type screen
                        }

                        Divider()
                            .padding(.leading, Constants.horizontalPadding)

                        TitleAndTextFieldRow(title: Localization.packageNameLabel,
                                             placeholder: Localization.packageNamePlaceholder,
                                             text: $viewModel.packageName,
                                             symbol: nil,
                                             keyboardType: .default)
                    }
                    .padding(.horizontal, insets: safeAreaInsets)

                    Divider()
                }
                .background(Color(.systemBackground).ignoresSafeArea(.container, edges: .horizontal))

                VStack(spacing: 0) {
                    Divider()

                    VStack(spacing: 0) {
                        TitleAndTextFieldRow(title: Localization.lengthLabel,
                                             placeholder: "0",
                                             text: $viewModel.packageLength,
                                             symbol: viewModel.lengthUnit,
                                             keyboardType: .decimalPad)

                        Divider()
                            .padding(.leading, Constants.horizontalPadding)

                        TitleAndTextFieldRow(title: Localization.widthLabel,
                                             placeholder: "0",
                                             text: $viewModel.packageWidth,
                                             symbol: viewModel.lengthUnit,
                                             keyboardType: .decimalPad)

                        Divider()
                            .padding(.leading, Constants.horizontalPadding)

                        TitleAndTextFieldRow(title: Localization.heightLabel,
                                             placeholder: "0",
                                             text: $viewModel.packageHeight,
                                             symbol: viewModel.lengthUnit,
                                             keyboardType: .decimalPad)
                    }
                    .padding(.horizontal, insets: safeAreaInsets)

                    Divider()
                }
                .background(Color(.systemBackground).ignoresSafeArea(.container, edges: .horizontal))

                VStack(spacing: 0) {
                    Divider()

                    TitleAndTextFieldRow(title: Localization.emptyPackageWeightLabel,
                                         placeholder: "0",
                                         text: $viewModel.emptyPackageWeight,
                                         symbol: viewModel.weightUnit,
                                         keyboardType: .decimalPad)
                        .padding(.horizontal, insets: safeAreaInsets)
                        .background(Color(.systemBackground).ignoresSafeArea(.container, edges: .horizontal))

                    Divider()

                    ListHeaderView(text: Localization.weightFooter, alignment: .left)
                        .padding(.horizontal, insets: safeAreaInsets)
                }
        }
        .background(Color(.listBackground))
        .ignoresSafeArea(.container, edges: .horizontal)
    }
}

private extension ShippingLabelCustomPackageForm {
    enum Localization {
        static let customPackageHeader = NSLocalizedString(
            "Set up the package you'll be using to ship your products. We'll save it for future orders.",
            comment: "Header text on Add New Custom Package screen in Shipping Label flow")
        static let packageTypeLabel = NSLocalizedString(
            "Package Type",
            comment: "Title for the row to select the package type (box or envelope) on the Add New Custom Package screen in Shipping Label flow")
        static let packageTypePlaceholder = NSLocalizedString(
            "Select Type",
            comment: "Placeholder for the row to select the package type (box or envelope) on the Add New Custom Package screen in Shipping Label flow")
        static let packageNameLabel = NSLocalizedString(
            "Package Name",
            comment: "Title for the row to enter the package name on the Add New Custom Package screen in Shipping Label flow")
        static let packageNamePlaceholder = NSLocalizedString(
            "Enter Name",
            comment: "Placeholder for the row to enter the package name on the Add New Custom Package screen in Shipping Label flow")
        static let lengthLabel = NSLocalizedString(
            "Length",
            comment: "Title for the row to enter the package length on the Add New Custom Package screen in Shipping Label flow")
        static let widthLabel = NSLocalizedString(
            "Width",
            comment: "Title for the row to enter the package width on the Add New Custom Package screen in Shipping Label flow")
        static let heightLabel = NSLocalizedString(
            "Height",
            comment: "Title for the row to enter the package height on the Add New Custom Package screen in Shipping Label flow")
        static let emptyPackageWeightLabel = NSLocalizedString(
            "Empty Package Weight",
            comment: "Title for the row to enter the empty package weight on the Add New Custom Package screen in Shipping Label flow")
        static let weightFooter = NSLocalizedString(
            "Weight of empty package",
            comment: "Footer text for the empty package weight on the Add New Custom Package screen in Shipping Label flow")
    }

    enum Constants {
        static let horizontalPadding: CGFloat = 16
        static let verticalSpacing: CGFloat = 16
    }
}

struct ShippingLabelAddCustomPackage_Previews: PreviewProvider {
    static var previews: some View {
        ShippingLabelCustomPackageForm(safeAreaInsets: .zero)
            .previewLayout(.sizeThatFits)
    }
}
