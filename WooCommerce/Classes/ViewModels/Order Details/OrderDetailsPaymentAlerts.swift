import MessageUI
import UIKit
import WordPressUI

/// A layer of indirection between OrderDetailsViewController and the modal alerts
/// presented to provide user-facing feedback about the progress
/// of the payment collection process
final class OrderDetailsPaymentAlerts {
    private weak var presentingController: UIViewController?

    // Storing this as a weak variable means that iOS should automatically set this to nil
    // when the VC is dismissed, unless there is a retain cycle somewhere else.
    private weak var _modalController: CardPresentPaymentsModalViewController?
    private var modalController: CardPresentPaymentsModalViewController {
        if let controller = _modalController {
            return controller
        } else {
            let controller = CardPresentPaymentsModalViewController(viewModel: readerIsReady())
            _modalController = controller
            return controller
        }
    }

    private var name: String = ""
    private var amount: String = ""

    init(presentingController: UIViewController) {
        self.presentingController = presentingController
    }

    func presentViewModel(viewModel: CardPresentPaymentsModalViewModel) {
        let controller = modalController
        controller.setViewModel(viewModel)
        if controller.presentingViewController == nil {
            controller.modalPresentationStyle = .custom
            controller.transitioningDelegate = AppDelegate.shared.tabBarController
            presentingController?.present(controller, animated: true)
        }
    }

    func readerIsReady(title: String, amount: String) {
        self.name = title
        self.amount = amount

        // Initial presentation of the modal view controller. We need to provide
        // a customer name and an amount.
        let viewModel = readerIsReady()
        presentViewModel(viewModel: viewModel)
    }

    func tapOrInsertCard() {
        let viewModel = tapOrInsert()
        presentViewModel(viewModel: viewModel)
    }

    func removeCard() {
        let viewModel = remove()
        presentViewModel(viewModel: viewModel)
    }

    func processingPayment() {
        let viewModel = processing()
        presentViewModel(viewModel: viewModel)
    }

    func success(printReceipt: @escaping () -> Void, emailReceipt: @escaping () -> Void) {
        let viewModel = successViewModel(printReceipt: printReceipt, emailReceipt: emailReceipt)
        presentViewModel(viewModel: viewModel)
    }

    func error(error: Error, tryAgain: @escaping () -> Void) {
        let viewModel = errorViewModel(amount: amount, error: error, tryAgain: tryAgain)
        presentViewModel(viewModel: viewModel)
    }

    func nonRetryableError(from: UIViewController?, error: Error) {
        let viewModel = nonRetryableErrorViewModel(amount: amount, error: error)
        presentViewModel(viewModel: viewModel)
    }
}

private extension OrderDetailsPaymentAlerts {
    func readerIsReady() -> CardPresentPaymentsModalViewModel {
        CardPresentModalReaderIsReady(name: name, amount: amount)
    }

    func tapOrInsert() -> CardPresentPaymentsModalViewModel {
        CardPresentModalTapCard(name: name, amount: amount)
    }

    func remove() -> CardPresentPaymentsModalViewModel {
        CardPresentModalRemoveCard(name: name, amount: amount)
    }

    func processing() -> CardPresentPaymentsModalViewModel {
        CardPresentModalProcessing(name: name, amount: amount)
    }

    func successViewModel(printReceipt: @escaping () -> Void, emailReceipt: @escaping () -> Void) -> CardPresentPaymentsModalViewModel {
        if MFMailComposeViewController.canSendMail() {
            return CardPresentModalSuccess(amount: amount, printReceipt: printReceipt, emailReceipt: emailReceipt)
        } else {
            return CardPresentModalSuccessWithoutEmail(amount: amount, printReceipt: printReceipt)
        }
    }

    func errorViewModel(amount: String, error: Error, tryAgain: @escaping () -> Void) -> CardPresentPaymentsModalViewModel {
        CardPresentModalError(amount: amount, error: error, primaryAction: tryAgain)
    }

    func nonRetryableErrorViewModel(amount: String, error: Error) -> CardPresentPaymentsModalViewModel {
        CardPresentModalNonRetryableError(amount: amount, error: error)
    }
}
