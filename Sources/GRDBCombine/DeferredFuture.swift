import Combine
import Dispatch
import Foundation

/// A publisher that eventually produces one value and then finishes or fails.
///
/// Unlike Combine.Future, DeferredFuture doesn't start producing its value
/// until it is subscribed to.
///
/// Unlike Combine.Deferred wrapping a Combine.Future, DeferredFuture works
/// reliably. More seriously, `Deferred { Future { ... } }` has our tests fail,
/// for no reason I can understand.
struct DeferredFuture<Output, Failure : Error>: Publisher {
    public typealias Promise = (Result<Output, Failure>) -> Void
    public typealias Output = Output
    public typealias Failure = Failure
    private let attemptToFulfill: (@escaping Promise) -> Void
    
    init(_ attemptToFulfill: @escaping (@escaping Promise) -> Void) {
        self.attemptToFulfill = attemptToFulfill
    }
    
    /// :nodoc:
    public func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
        let subscription = DeferredFutureSubscription(
            attemptToFulfill: attemptToFulfill,
            receiveCompletion: subscriber.receive(completion:),
            receive: subscriber.receive(_:))
        subscriber.receive(subscription: subscription)
    }
}

private class DeferredFutureSubscription<Output, Failure : Error>: Subscription {
    private enum State {
        case waitingForDemand
        case waitingForFulfillment
        case finished
    }
    
    private let attemptToFulfill: (@escaping DeferredFuture<Output, Failure>.Promise) -> Void
    private let _receiveCompletion: (Subscribers.Completion<Failure>) -> Void
    private let _receive: (Output) -> Subscribers.Demand
    private var state: State = .waitingForDemand
    private var lock = NSRecursiveLock() // Allow re-entrancy
    
    init(
        attemptToFulfill: @escaping (@escaping DeferredFuture<Output, Failure>.Promise) -> Void,
        receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
        receive: @escaping (Output) -> Subscribers.Demand)
    {
        self.attemptToFulfill = attemptToFulfill
        self._receiveCompletion = receiveCompletion
        self._receive = receive
    }
    
    func request(_ demand: Subscribers.Demand) {
        lock.synchronized {
            switch state {
            case .waitingForDemand:
                guard demand > 0 else {
                    return
                }
                state = .waitingForFulfillment
                attemptToFulfill { result in
                    switch result {
                    case let .success(value):
                        self.receiveAndComplete(value)
                    case let .failure(error):
                        self.receiveCompletion(.failure(error))
                    }
                }
                
            case .waitingForFulfillment, .finished:
                break
            }
        }
    }
    
    func cancel() {
        lock.synchronized {
            state = .finished
        }
    }
    
    private func receiveAndComplete(_ value: Output) {
        lock.synchronized {
            guard case .waitingForFulfillment = state else {
                return
            }
            
            state = .finished
            _ = _receive(value)
            _receiveCompletion(.finished)
        }
    }
    
    private func receiveCompletion(_ completion: Subscribers.Completion<Failure>) {
        lock.synchronized {
            guard case .waitingForFulfillment = state else {
                return
            }
            
            state = .finished
            _receiveCompletion(completion)
        }
    }
}
