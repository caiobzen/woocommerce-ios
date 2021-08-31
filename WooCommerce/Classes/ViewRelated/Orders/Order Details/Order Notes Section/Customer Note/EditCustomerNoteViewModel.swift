import Foundation
import Yosemite
import Combine

/// View Model for the Edit Customer Note screen
///
final class EditCustomerNoteViewModel: ObservableObject {

    /// New content to submit.
    /// Binding property modified at the view level.
    ///
    @Published var newNote: String

    /// Active navigation bar trailing item.
    /// Defaults to a disabled done button.
    ///
    @Published private(set) var navigationTrailingItem: NavigationItem = .done(enabled: false)

    /// Defines the current notice that should be shown.
    /// Defaults to `nil`.
    ///
    @Published var presentNotice: Notice?

    /// Order to be edited.
    ///
    private let order: Order

    /// Tracks if a network request is being performed.
    ///
    private let performingNetworkRequest: CurrentValueSubject<Bool, Never> = .init(false)

    /// Action dispatcher
    ///
    private let stores: StoresManager

    init(order: Order, stores: StoresManager = ServiceLocator.stores) {
        self.order = order
        self.newNote = order.customerNote ?? ""
        self.stores = stores
        bindNavigationTrailingItemPublisher()
    }

    /// Update the note remotely and invoke a completion block when finished
    ///
    func updateNote(onFinish: @escaping (Bool) -> Void) {
        let modifiedOrder = order.copy(customerNote: newNote)
        let action = OrderAction.updateOrder(siteID: order.siteID, order: modifiedOrder, fields: [.customerNote]) { [weak self] result in
            guard let self = self else { return }

            self.performingNetworkRequest.send(false)
            switch result {
            case .success:
                self.presentNotice = .success
            case .failure(let error):
                self.presentNotice = .error
                DDLogError("⛔️ Unable to update the order: \(error)")
            }

            onFinish(result.isSuccess)
        }

        performingNetworkRequest.send(true)
        stores.dispatch(action)
    }
}

// MARK: Definitions
extension EditCustomerNoteViewModel {
    /// Representation of possible navigation bar trailing buttons
    ///
    enum NavigationItem: Equatable {
        case done(enabled: Bool)
        case loading
    }

    /// Representation of possible notices that can be displayed
    enum Notice: Equatable {
        case success
        case error
    }
}

// MARK: Helper Methods
private extension EditCustomerNoteViewModel {
    /// Calculates what navigation trailing item should be shown depending on our internal state.
    ///
    private func bindNavigationTrailingItemPublisher() {
        Publishers.CombineLatest($newNote, performingNetworkRequest)
            .map { [order] newNote, performingNetworkRequest -> NavigationItem in
                guard !performingNetworkRequest else {
                    return .loading
                }
                return .done(enabled: order.customerNote != newNote)
            }
            .assign(to: &$navigationTrailingItem)
    }
}
