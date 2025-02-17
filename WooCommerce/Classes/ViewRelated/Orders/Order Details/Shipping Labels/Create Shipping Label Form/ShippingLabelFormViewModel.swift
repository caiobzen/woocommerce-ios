import UIKit
import Yosemite
import protocol Storage.StorageManagerType

/// Provides view data for Create Shipping Label, and handles init/UI/navigation actions needed.
///
final class ShippingLabelFormViewModel {

    /// Defines the necessary state to produce the ViewModel's outputs.
    ///
    struct State {

        var sections: [Section] = []

        /// Indicates if the view model is validating an address
        ///
        var isValidatingOriginAddress: Bool = false
        var isValidatingDestinationAddress: Bool = false
    }

    typealias Section = ShippingLabelFormViewController.Section
    typealias Row = ShippingLabelFormViewController.Row

    let siteID: Int64
    private(set) var order: Order

    /// Address
    ///
    private(set) var originAddress: ShippingLabelAddress? {
        didSet {
            updateRowsForCustomsIfNeeded()
        }
    }
    private(set) var destinationAddress: ShippingLabelAddress? {
        didSet {
            updateRowsForCustomsIfNeeded()
        }
    }

    /// Packages
    ///
    private(set) var packagesResponse: ShippingLabelPackagesResponse?
    private(set) var selectedPackageID: String?

    /// Customs forms
    ///
    private (set) var customsForms: [ShippingLabelCustomsForm] = []

    /// Carrier and Rates
    ///
    private(set) var selectedRate: ShippingLabelCarrierRate?
    private(set) var selectedSignatureRate: ShippingLabelCarrierRate?
    private(set) var selectedAdultSignatureRate: ShippingLabelCarrierRate?
    var selectedPackage: ShippingLabelPackageSelected? {
        guard let packagesResponse = packagesResponse else {
            return nil
        }

        let weight = Double(totalPackageWeight ?? "0") ?? .zero

        if let customPackage = packagesResponse.customPackages.first(where: { $0.title == selectedPackageID }) {
            let boxID = customPackage.title
            let customsForm = customsForms.first(where: { $0.packageID == boxID })
            return ShippingLabelPackageSelected(boxID: boxID,
                                                length: customPackage.getLength(),
                                                width: customPackage.getWidth(),
                                                height: customPackage.getHeight(),
                                                weight: weight,
                                                isLetter: customPackage.isLetter,
                                                customsForm: customsForm)
        }

        for option in packagesResponse.predefinedOptions {
            if let predefinedPackage = option.predefinedPackages.first(where: { $0.id == selectedPackageID }) {
                let boxID = predefinedPackage.id
                let customsForm = customsForms.first(where: { $0.packageID == boxID })
                return ShippingLabelPackageSelected(boxID: boxID,
                                                    length: predefinedPackage.getLength(),
                                                    width: predefinedPackage.getWidth(),
                                                    height: predefinedPackage.getHeight(),
                                                    weight: weight,
                                                    isLetter: predefinedPackage.isLetter,
                                                    customsForm: customsForm)
            }
        }

        return nil
    }
    private(set) var totalPackageWeight: String?

    /// Payment Methods
    ///
    var shippingLabelAccountSettings: ShippingLabelAccountSettings?

    /// Shipping Label Purchase
    ///
    private(set) var purchasedShippingLabel: ShippingLabel?

    /// ResultsController: Loads Countries from the Storage Layer.
    ///
    private lazy var resultsController: ResultsController<StorageCountry> = {
        let descriptor = NSSortDescriptor(key: "name", ascending: true)
        return ResultsController(storageManager: storageManager, matching: nil, sortedBy: [descriptor])
    }()

    var countries: [Country] {
        resultsController.fetchedObjects
    }

    /// Check for the need of customs form
    ///
    var customsFormRequired: Bool {
        guard let originAddress = originAddress,
              let destinationAddress = destinationAddress else {
            return false
        }
        // Special case: Any shipment from/to military addresses must have Customs
        if originAddress.country == Constants.usCountryCode,
           Constants.usMilitaryStates.contains(where: { $0 == originAddress.state }) {
            return true
        }
        if destinationAddress.country == Constants.usCountryCode,
           Constants.usMilitaryStates.contains(where: { $0 == destinationAddress.state }) {
            return true
        }

        return originAddress.country != destinationAddress.country
    }

    private let stores: StoresManager

    private let storageManager: StorageManagerType

    /// Closure to notify the `ViewController` when the view model properties change.
    ///
    var onChange: (() -> (Void))?

    /// Current `ViewModel` state.
    ///
    private(set) var state: State = State() {
        didSet {
            onChange?()
        }
    }

    init(order: Order,
         originAddress: Address?,
         destinationAddress: Address?,
         stores: StoresManager = ServiceLocator.stores,
         storageManager: StorageManagerType = ServiceLocator.storageManager) {

        self.siteID = order.siteID
        self.order = order

        let accountSettings = ShippingLabelFormViewModel.getStoredAccountSettings()
        let company = ServiceLocator.stores.sessionManager.defaultSite?.name
        let defaultAccount = ServiceLocator.stores.sessionManager.defaultAccount

        self.originAddress = ShippingLabelFormViewModel.fromAddressToShippingLabelAddress(address: originAddress) ??
            ShippingLabelFormViewModel.getDefaultOriginAddress(accountSettings: accountSettings,
                                                               company: company,
                                                               siteAddress: SiteAddress(),
                                                               account: defaultAccount)
        self.destinationAddress = ShippingLabelFormViewModel.fromAddressToShippingLabelAddress(address: destinationAddress)

        self.stores = stores
        self.storageManager = storageManager

        state.sections = generateInitialSections()
        syncShippingLabelAccountSettings()
        syncPackageDetails()
        fetchCountries()
    }

    func handleOriginAddressValueChanges(address: ShippingLabelAddress?, validated: Bool) {
        originAddress = address
        let dateState: ShippingLabelFormViewController.DataState = validated ? .validated : .pending
        updateRowState(type: .shipFrom, dataState: dateState, displayMode: .editable)

        // We reset the carrier and rates selected because if the address change
        // the carrier and rate change accordingly
        handleCarrierAndRatesValueChanges(selectedRate: nil, selectedSignatureRate: nil, selectedAdultSignatureRate: nil, editable: false)

        if dateState == .validated {
            ServiceLocator.analytics.track(.shippingLabelPurchaseFlow, withProperties: ["state": "origin_address_complete"])
        }
    }

    func handleDestinationAddressValueChanges(address: ShippingLabelAddress?, validated: Bool) {
        destinationAddress = address
        let dateState: ShippingLabelFormViewController.DataState = validated ? .validated : .pending
        updateRowState(type: .shipTo, dataState: dateState, displayMode: .editable)

        // We reset the carrier and rates selected because if the address change
        // the carrier and rate change accordingly
        handleCarrierAndRatesValueChanges(selectedRate: nil, selectedSignatureRate: nil, selectedAdultSignatureRate: nil, editable: false)

        if dateState == .validated {
            ServiceLocator.analytics.track(.shippingLabelPurchaseFlow, withProperties: ["state": "destination_address_complete"])
        }
    }

    func handlePackageDetailsValueChanges(selectedPackageID: String?, totalPackageWeight: String?) {
        self.selectedPackageID = selectedPackageID
        self.totalPackageWeight = totalPackageWeight

        guard !selectedPackageID.isNilOrEmpty && !totalPackageWeight.isNilOrEmpty else {
            updateRowState(type: .packageDetails, dataState: .pending, displayMode: .editable)
            return
        }
        updateRowState(type: .packageDetails, dataState: .validated, displayMode: .editable)

        // We reset the selected customs forms & carrier & rates because if the package change
        // these change accordingly.
        let forms = createDefaultCustomsFormsIfNeeded()
        handleCustomsFormsValueChanges(customsForms: forms, isValidated: false)
        handleCarrierAndRatesValueChanges(selectedRate: nil, selectedSignatureRate: nil, selectedAdultSignatureRate: nil, editable: false)
    }

    func handleCustomsFormsValueChanges(customsForms: [ShippingLabelCustomsForm], isValidated: Bool) {
        self.customsForms = customsForms
        guard isValidated else {
            return updateRowState(type: .customs, dataState: .pending, displayMode: .editable)
        }
        updateRowState(type: .customs, dataState: .validated, displayMode: .editable)
        // We reset the carrier and rates selected because if the package change
        // the carrier and rate change accordingly
        handleCarrierAndRatesValueChanges(selectedRate: nil, selectedSignatureRate: nil, selectedAdultSignatureRate: nil, editable: false)
    }

    func handleCarrierAndRatesValueChanges(selectedRate: ShippingLabelCarrierRate?,
                                           selectedSignatureRate: ShippingLabelCarrierRate?,
                                           selectedAdultSignatureRate: ShippingLabelCarrierRate?,
                                           editable: Bool) {
        self.selectedRate = selectedRate
        self.selectedSignatureRate = selectedSignatureRate
        self.selectedAdultSignatureRate = selectedAdultSignatureRate

        guard selectedRate != nil || selectedSignatureRate != nil || selectedAdultSignatureRate != nil else {
            updateRowState(type: .shippingCarrierAndRates, dataState: .pending, displayMode: editable ? .editable : .disabled)
            return
        }
        updateRowState(type: .shippingCarrierAndRates, dataState: .validated, displayMode: editable ? .editable : .disabled)
    }

    func handlePaymentMethodValueChanges(settings: ShippingLabelAccountSettings, editable: Bool) {
        shippingLabelAccountSettings = settings
        let displayMode: ShippingLabelFormViewController.DisplayMode = editable ? .editable : .disabled

        // Only update the data state if there is a selected payment method
        guard settings.selectedPaymentMethodID != 0 else {
            updateRowState(type: .paymentMethod, dataState: .pending, displayMode: displayMode)
            return
        }
        updateRowState(type: .paymentMethod, dataState: .validated, displayMode: displayMode)
    }

    private func generateInitialSections() -> [Section] {
        let shipFrom = Row(type: .shipFrom, dataState: .pending, displayMode: .editable)
        let shipTo = Row(type: .shipTo, dataState: .pending, displayMode: .disabled)
        let packageDetails = Row(type: .packageDetails, dataState: .pending, displayMode: .disabled)
        let customs: Row? = {
            guard customsFormRequired else {
                return nil
            }
            return Row(type: .customs, dataState: .pending, displayMode: .disabled)
        }()
        let shippingCarrierAndRates = Row(type: .shippingCarrierAndRates, dataState: .pending, displayMode: .disabled)
        let paymentMethod = Row(type: .paymentMethod, dataState: .pending, displayMode: .disabled)
        let rows: [Row] = [shipFrom, shipTo, packageDetails, customs, shippingCarrierAndRates, paymentMethod].compactMap { $0 }
        return [Section(title: nil, rows: rows)]
    }

    /// Returns the body of the Package Details cell
    ///
    func getPackageDetailsBody() -> String {
        guard let packagesResponse = packagesResponse,
              let selectedPackageID = selectedPackageID,
              let totalPackageWeight = totalPackageWeight else {
            return Localization.packageDetailsPlaceholder
        }

        let packageTitle = searchCustomPackage(id: selectedPackageID)?.title ?? searchPredefinedPackage(id: selectedPackageID)?.title ?? ""

        let formatter = WeightFormatter(weightUnit: packagesResponse.storeOptions.weightUnit)
        let packageWeight = formatter.formatWeight(weight: totalPackageWeight)

        return packageTitle + "\n" + String.localizedStringWithFormat(Localization.totalPackageWeight, packageWeight)
    }

    /// Returns the body of the selected Carrier and Rates.
    ///
    func getCarrierAndRatesBody() -> String {
        guard let selectedRate = selectedRate else {
            return Localization.carrierAndRatesPlaceholder
        }

        var rate: Double = selectedRate.retailRate
        if let selectedSignatureRate = selectedSignatureRate {
            rate = selectedSignatureRate.retailRate
        }
        else if let selectedAdultSignatureRate = selectedAdultSignatureRate {
            rate = selectedAdultSignatureRate.retailRate
        }

        let currencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings)
        let price = currencyFormatter.formatAmount(Decimal(rate)) ?? ""

        let formatString = selectedRate.deliveryDays == 1 ? Localization.businessDaySingular : Localization.businessDaysPlural

        var shippingDays = ""
        if let deliveryDays = selectedRate.deliveryDays {
            shippingDays = " - " + String(format: formatString, deliveryDays)
        }

        return selectedRate.title + "\n" + price + shippingDays
    }

    /// Returns the body of the Payment Methods cell.
    /// Displays the payment method details if one is selected. Otherwise, displays a prompt to add a credit card.
    ///
    func getPaymentMethodBody() -> String {
        let selectedPaymentMethodID = shippingLabelAccountSettings?.selectedPaymentMethodID
        let availablePaymentMethods = shippingLabelAccountSettings?.paymentMethods
        guard let selectedPaymentMethod = availablePaymentMethods?.first(where: { $0.paymentMethodID == selectedPaymentMethodID }) else {
            return Localization.paymentMethodPlaceholder
        }

        return String.localizedStringWithFormat(Localization.paymentMethodLabel, selectedPaymentMethod.cardDigits)
    }

    /// Returns the subtotal under the Order Summary.
    ///
    func getSubtotal() -> String {
        guard let selectedRate = selectedRate else {
            return ""
        }

        var retailRate: Double = selectedRate.retailRate
        if let selectedSignatureRate = selectedSignatureRate {
            retailRate = selectedSignatureRate.retailRate
        }
        else if let selectedAdultSignatureRate = selectedAdultSignatureRate {
            retailRate = selectedAdultSignatureRate.retailRate
        }

        let currencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings)
        let price = currencyFormatter.formatAmount(Decimal(retailRate)) ?? ""

        return price
    }

    /// Returns, if available, the discount under the Order Summary.
    ///
    func getDiscount() -> String? {
        guard let selectedRate = selectedRate else {
            return nil
        }

        var rate: Double = selectedRate.rate - selectedRate.retailRate
        if let selectedSignatureRate = selectedSignatureRate {
            rate = selectedSignatureRate.rate - selectedSignatureRate.retailRate
        }
        else if let selectedAdultSignatureRate = selectedAdultSignatureRate {
            rate = selectedAdultSignatureRate.rate - selectedAdultSignatureRate.retailRate
        }

        guard rate != 0 else {
            return nil
        }

        let currencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings)
        let discount = currencyFormatter.formatAmount(Decimal(rate)) ?? nil

        return discount
    }

    /// Returns the order total under the Order Summary.
    ///
    func getOrderTotal() -> String {
        guard let selectedRate = selectedRate else {
            return ""
        }

        var rate: Double = selectedRate.rate
        if let selectedSignatureRate = selectedSignatureRate {
            rate = selectedSignatureRate.rate
        }
        else if let selectedAdultSignatureRate = selectedAdultSignatureRate {
            rate = selectedAdultSignatureRate.rate
        }

        let currencyFormatter = CurrencyFormatter(currencySettings: ServiceLocator.currencySettings)
        let price = currencyFormatter.formatAmount(Decimal(rate)) ?? ""

        return price
    }

    /// Filter country for picking based on ship type.
    ///
    /// For origin address, country list should show only US or any of its territories that have at least one USPS postal office.
    /// Destination address should allow picking from the complete country list.
    ///
    func filteredCountries(for type: ShipType) -> [Country] {
        switch type {
        case .origin:
            return countries.filter { Constants.acceptedUSPSCountries.contains($0.code) }
        case .destination:
            return countries
        }
    }
}

// MARK: - State Machine
private extension ShippingLabelFormViewModel {

    /// We have a state machine that keeps track of a list of rows with corresponding data state and UI state.
    /// On each state change (any data change from any rows or API validation response), the state machine:
    /// First updates the date state of affected rows
    /// Then recalculates the UI state of all rows
    /// A row's UI state is `editable` if:
    /// - All previous rows (lower index) have data state as validated
    /// - For the first row, it is always editable
    ///
    func updateRowState(type: ShippingLabelFormViewController.RowType,
                        dataState: ShippingLabelFormViewController.DataState,
                        displayMode: ShippingLabelFormViewController.DisplayMode) {
        guard var rows = state.sections.first?.rows else {
            return
        }

        if let rowIndex = rows.firstIndex(where: { $0.type == type }) {
            rows[rowIndex] = Row(type: type, dataState: dataState, displayMode: displayMode)

            for index in 0 ..< rows.count {
                if rows[safe: index - 1]?.dataState == .validated {
                    let currentRow = rows[index]
                    rows[index] = Row(type: currentRow.type, dataState: currentRow.dataState, displayMode: .editable)
                }
            }
        }

        // Find first row with .pending data state,
        // and update its following rows to be .disabled if their display mode is .editable and data state is .pending.
        if let firstPendingRow = rows.firstIndex(where: { $0.dataState == .pending }) {
            for index in rows.index(after: firstPendingRow) ..< rows.count {
                let nextRow = rows[index]
                if nextRow.displayMode == .editable && nextRow.dataState == .pending {
                    rows[index] = Row(type: nextRow.type, dataState: nextRow.dataState, displayMode: .disabled)
                }
            }
        }

        var summarySection: Section?
        if rows.allSatisfy({ (row) -> Bool in
            row.dataState == .validated && row.displayMode == .editable
        }) {
            summarySection = Section(title: Localization.orderSummaryHeader.uppercased(),
                                     rows: [Row(type: .orderSummary, dataState: .validated, displayMode: .editable)])
        }

        state.sections = [Section(title: nil, rows: rows), summarySection].compactMap { $0 }
    }

    func updateRowsForCustomsIfNeeded() {
        insertOrRemoveCustomsRowIfNeeded()

        guard let originAddress = originAddress else {
            return
        }
        // Require user to update phone address if customs form is required
        if customsFormRequired && originAddress.phone.isEmpty {
            updateRowState(type: .shipFrom, dataState: .pending, displayMode: .editable)
        }
    }

    func insertOrRemoveCustomsRowIfNeeded() {
        guard var rows = state.sections.first?.rows else {
            return
        }
        // Add customs row if customs form is required
        if customsFormRequired, rows.firstIndex(where: { $0.type == .customs }) == nil {
            guard let packageDetailsRow = rows.first(where: { $0.type == .packageDetails }),
                  let packageDetailsRowIndex = rows.firstIndex(of: packageDetailsRow) else {
                return
            }

            // Decide display mode for customs row based on whether package details has been validated
            let customsRowState: ShippingLabelFormViewController.DisplayMode = packageDetailsRow.dataState == .pending ? .disabled : .editable
            let customsRowIndex = rows.index(after: packageDetailsRowIndex)
            let customsRow = Row(type: .customs, dataState: .pending, displayMode: customsRowState)
            rows.insert(customsRow, at: customsRowIndex)
            state.sections[0] = Section(title: nil, rows: rows)
        }

        // Remove customs row if customs form is not required
        if !customsFormRequired, let index = rows.firstIndex(where: { $0.type == .customs }) {
            rows.remove(at: index)
            state.sections[0] = Section(title: nil, rows: rows)
        }
    }
}

// MARK: - Utils
private extension ShippingLabelFormViewModel {
    // We generate the default origin address using the information
    // of the logged Account and of the website.
    static func getDefaultOriginAddress(accountSettings: AccountSettings?,
                                        company: String?,
                                        siteAddress: SiteAddress,
                                        account: Account?) -> ShippingLabelAddress? {
        let address = Address(firstName: accountSettings?.firstName ?? "",
                              lastName: accountSettings?.lastName ?? "",
                              company: company ?? "",
                              address1: siteAddress.address,
                              address2: siteAddress.address2,
                              city: siteAddress.city,
                              state: siteAddress.state,
                              postcode: siteAddress.postalCode,
                              country: siteAddress.countryCode,
                              phone: "",
                              email: account?.email)
        return fromAddressToShippingLabelAddress(address: address)
    }

    static func fromAddressToShippingLabelAddress(address: Address?) -> ShippingLabelAddress? {
        guard let address = address else { return nil }

        // In this way we support localized name correctly,
        // because the order is often reversed in a few Asian languages.
        var components = PersonNameComponents()
        components.givenName = address.firstName
        components.familyName = address.lastName

        let shippingLabelAddress = ShippingLabelAddress(company: address.company ?? "",
                                                        name: PersonNameComponentsFormatter.localizedString(from: components, style: .medium, options: []),
                                                        phone: address.phone ?? "",
                                                        country: address.country,
                                                        state: address.state,
                                                        address1: address.address1,
                                                        address2: address.address2 ?? "",
                                                        city: address.city,
                                                        postcode: address.postcode)
        return shippingLabelAddress
    }

    static func getStoredAccountSettings() -> AccountSettings? {
        let storageManager = ServiceLocator.storageManager

        let resultsController = ResultsController<StorageAccountSettings>(storageManager: storageManager, sortedBy: [])
        try? resultsController.performFetch()
        return resultsController.fetchedObjects.first
    }

    func updateValidatingAddressState(_ validating: Bool, type: ShipType) {
        switch type {
        case .origin:
            state.isValidatingOriginAddress = validating
        case .destination:
            state.isValidatingDestinationAddress = validating
        }
    }

    // Search the custom package based on the id
    //
    private func searchCustomPackage(id: String?) -> ShippingLabelCustomPackage? {
        guard let packagesResponse = packagesResponse,
              let packageID = id else {
            return nil
        }

        for customPackage in packagesResponse.customPackages {
            if customPackage.title == packageID {
                return customPackage
            }
        }

        return nil
    }

    // Search the predefined package based on the id
    //
    private func searchPredefinedPackage(id: String?) -> ShippingLabelPredefinedPackage? {
        guard let packagesResponse = packagesResponse,
              let packageID = id else {
            return nil
        }

        for option in packagesResponse.predefinedOptions {
            for predefinedPackage in option.predefinedPackages {
                if predefinedPackage.id == packageID {
                    return predefinedPackage
                }
            }
        }

        return nil
    }

    /// Temporary solution for creating default customs forms.
    /// When multi-package support is available, we should create separate form for each package ID.
    ///
    private func createDefaultCustomsFormsIfNeeded() -> [ShippingLabelCustomsForm] {
        guard customsFormRequired, let packageID = selectedPackageID else {
            return []
        }
        let packageName: String = {
            guard let response = packagesResponse else {
                return ""
            }

            if let customPackage = response.customPackages.first(where: { $0.title == packageID }) {
                return customPackage.title
            }

            for option in response.predefinedOptions {
                if let package = option.predefinedPackages.first(where: { $0.id == packageID }) {
                    return package.title
                }
            }

            return ""
        }()
        let productIDs = order.items.map { $0.productOrVariationID }
        return [ShippingLabelCustomsForm(packageID: packageID, packageName: packageName, productIDs: productIDs)]
    }
}

// MARK: - Remote API
extension ShippingLabelFormViewModel {
    func fetchCountries() {
        try? resultsController.performFetch()
        let action = DataAction.synchronizeCountries(siteID: siteID) { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success:
                try? self.resultsController.performFetch()
            case .failure:
                break
            }
        }

        stores.dispatch(action)
    }

    func validateAddress(type: ShipType, onCompletion: ((ValidationState, ShippingLabelAddressValidationSuccess?) -> ())? = nil) {

        guard let address = type == .origin ? originAddress : destinationAddress else { return }

        let addressToBeVerified = ShippingLabelAddressVerification(address: address, type: type)

        // Validate name field locally before validating the address remotely.
        // The name field cannot be empty when creating a shipping label, but this is not part of the remote validation.
        // See: https://github.com/Automattic/woocommerce-services/issues/2457
        if address.name.isEmpty {
            let missingNameError = ShippingLabelAddressValidationError(addressError: nil, generalError: "Name is required")
            onCompletion?(.validationError(missingNameError), nil)
        }

        updateValidatingAddressState(true, type: type)

        let action = ShippingLabelAction.validateAddress(siteID: siteID, address: addressToBeVerified) { [weak self] (result) in

            guard let self = self else { return }
            switch result {
            case .success(let response):
                self.updateValidatingAddressState(false, type: type)
                if response.isTrivialNormalization {
                    onCompletion?(.validated, response)
                } else {
                    onCompletion?(.suggestedAddress, response)
                }
            case .failure(let error):
                DDLogError("⛔️ Error validating shipping label address: \(error)")
                self.updateValidatingAddressState(false, type: type)
                if let error = error as? ShippingLabelAddressValidationError {
                    onCompletion?(.validationError(error), nil)
                } else {
                    onCompletion?(.genericError(error), nil)
                }
            }
        }
        stores.dispatch(action)
    }

    /// Syncs account settings specific to shipping labels, such as the last selected package and payment methods.
    ///
    func syncShippingLabelAccountSettings() {
        let action = ShippingLabelAction.synchronizeShippingLabelAccountSettings(siteID: order.siteID) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let value):
                self.handlePaymentMethodValueChanges(settings: value, editable: false)
            case .failure:
                DDLogError("⛔️ Error synchronizing shipping label account settings")
            }
        }
        stores.dispatch(action)
    }

    func syncPackageDetails() {
        let action = ShippingLabelAction.packagesDetails(siteID: order.siteID) { [weak self] result in
            switch result {
            case .success(let value):
                self?.packagesResponse = value
            case .failure:
                DDLogError("⛔️ Error synchronizing package details")
                return
            }
        }
        stores.dispatch(action)
    }

    enum ValidationState {
        case validated
        case suggestedAddress
        case validationError(ShippingLabelAddressValidationError)
        case genericError(Error)
    }

    /// Purchases a shipping label with the origin and destination address, package, and rate selected in the Shipping Label Form.
    /// - Parameter onCompletion: Closure to be executed on completion with the success/failure result of the purchase.
    ///
    func purchaseLabel(onCompletion: @escaping ((Result<TimeInterval, Error>) -> Void)) {
        guard let originAddress = originAddress,
              let destinationAddress = destinationAddress,
              let selectedPackage = selectedPackage,
              let selectedRate = selectedRate,
              let accountSettings = shippingLabelAccountSettings else {
            onCompletion(.failure(PurchaseError.labelDetailsMissing))
            return
        }

        let productIDs = order.items.map { $0.productOrVariationID }
        let package = ShippingLabelPackagePurchase(package: selectedPackage,
                                                   rate: selectedRate,
                                                   productIDs: productIDs,
                                                   customsForm: selectedPackage.customsForm)
        let startTime = Date()
        let action = ShippingLabelAction.purchaseShippingLabel(siteID: siteID,
                                                               orderID: order.orderID,
                                                               originAddress: originAddress,
                                                               destinationAddress: destinationAddress,
                                                               packages: [package],
                                                               emailCustomerReceipt: accountSettings.isEmailReceiptsEnabled) { result in
            switch result {
            case .success(let labels):
                self.purchasedShippingLabel = labels.first(where: { $0.productIDs == productIDs })
                onCompletion(.success(Date().timeIntervalSince(startTime)))
            case .failure(let error):
                onCompletion(.failure(error))
            }
        }
        stores.dispatch(action)
    }

    private enum PurchaseError: Error {
        case labelDetailsMissing
    }
}

private extension ShippingLabelFormViewModel {
    enum Localization {
        static let packageDetailsPlaceholder = NSLocalizedString("Select the type of packaging you'd like to ship your items in",
                                                                 comment: "Placeholder in Shipping Label form for the Package Details row.")
        static let totalPackageWeight = NSLocalizedString("Total package weight: %1$@",
                                                          comment: "Total package weight label in Shipping Label form. %1$@ is a placeholder for the weight")
        static let carrierAndRatesPlaceholder = NSLocalizedString("Select your shipping carrier and rates",
                                                                  comment: "Placeholder in Shipping Label form for the Carrier and Rates row.")
        static let businessDaySingular = NSLocalizedString("%1$d business day",
                                                           comment: "Singular format of number of business day in Shipping Labels > Carrier and Rates")
        static let businessDaysPlural = NSLocalizedString("%1$d business days",
                                                          comment: "Plural format of number of business days in Shipping Labels > Carrier and Rates")
        static let paymentMethodPlaceholder = NSLocalizedString("Add a new credit card",
                                                                comment: "Placeholder in Shipping Label form for the Payment Method row.")
        static let paymentMethodLabel =
            NSLocalizedString("Credit card ending in %1$@",
                              comment: "Selected credit card in Shipping Label form. %1$@ is a placeholder for the last four digits of the credit card.")
        static let orderSummaryHeader = NSLocalizedString("Shipping label order summary",
                                                          comment: "Header of the order summary section in the shipping label creation form")
    }

    enum Constants {
        /// This is hardcoded for now based on: https://git.io/JBuja.
        /// It would be great if this can be fetched remotely.
        ///
        static let acceptedUSPSCountries = [
            "US", // United States
            "PR", // Puerto Rico
            "VI", // Virgin Islands
            "GU", // Guam
            "AS", // American Samoa
            "UM", // United States Minor Outlying Islands
            "MH", // Marshall Islands
            "FM", // Micronesia
            "MP" // Northern Mariana Islands
        ]

        /// Country code for US - to check for international shipment
        ///
        static let usCountryCode = "US"

        /// These US states are a special case because they represent military bases. They're considered "domestic",
        /// but they require a Customs form to ship from/to them.
        static let usMilitaryStates = ["AA", "AE", "AP"]

        // These destination countries require an ITN regardless of shipment value
        static let uspsITNRequiredDestination = ["IR", "SY", "KP", "CU", "SD"]
    }
}
