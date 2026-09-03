import Foundation

struct CaptureWorkflowToken: Equatable {
    fileprivate let value: UInt64
}

struct CaptureWorkflowGate {
    private var nextValue: UInt64 = 0
    private(set) var activeToken: CaptureWorkflowToken?

    var isActive: Bool { activeToken != nil }

    mutating func acquire() -> CaptureWorkflowToken? {
        guard activeToken == nil else { return nil }
        nextValue &+= 1
        let token = CaptureWorkflowToken(value: nextValue)
        activeToken = token
        return token
    }

    func isActive(_ token: CaptureWorkflowToken) -> Bool {
        activeToken == token
    }

    @discardableResult
    mutating func release(_ token: CaptureWorkflowToken) -> Bool {
        guard activeToken == token else { return false }
        activeToken = nil
        return true
    }
}
