// MARK: - CardPresentPaymentAction: Defines all of the Actions supported by the CardPresentPaymentStore.
//

import Combine

public enum CardPresentPaymentAction: Action {
    /// Start the Card Reader discovery process.
    ///
    case startCardReaderDiscovery(siteID: Int64, onReaderDiscovered: ([CardReader]) -> Void, onError: (Error) -> Void)

    /// Cancels the Card Reader discovery process.
    ///
    case cancelCardReaderDiscovery(onCompletion: (Result<Void, Error>) -> Void)

    /// Connect to a specific CardReader.
    /// Stops Card Reader discovery
    ///
    case connect(reader: CardReader, onCompletion: (Result<CardReader, Error>) -> Void)

    /// Disconnect from currently connected Reader
    ///
    case disconnect(onCompletion: (Result<Void, Error>) -> Void)

    /// Calls the completion block everytime the list of connected readers changes
    /// with an array of connected readers.
    ///
    case observeConnectedReaders(onCompletion: ([CardReader]) -> Void)

    /// Get a Stripe Customer for an order.
    ///
    case fetchOrderCustomer(siteID: Int64, orderID: Int64, onCompletion: (Result<WCPayCustomer, Error>) -> Void)

    /// Collected payment for an order.
    ///
    case collectPayment(siteID: Int64,
                        orderID: Int64,
                        parameters: PaymentParameters,
                        onCardReaderMessage: (CardReaderEvent) -> Void,
                        onCompletion: (Result<PaymentIntent, Error>) -> Void)

    /// Cancels an active attempt to collect a payment.
    case cancelPayment(onCompletion: ((Result<Void, Error>) -> Void)?)

    /// Check whether there is a software update available.
    case checkForCardReaderUpdate(onCompletion: (Result<CardReaderSoftwareUpdate?, Error>) -> Void)

    /// Update card reader firmware.
    case startCardReaderUpdate(onProgress: (Float) -> Void,
                        onCompletion: (Result<Void, Error>) -> Void)

    /// Restarts the card present payments system
    /// This might imply, but not be limited to:
    /// 1. Disconnect from a connected reader
    /// 2. Clear all credentials, cached data
    /// 3. Reset all status indicators
    case reset

    /// Checks if a reader is connected
    case checkCardReaderConnected(onCompletion: (AnyPublisher<[CardReader], Never>) -> Void)
}
