//
//  SignalProcessing.swift
//  MBatmaN
//
//

import Foundation

nonisolated final class SignalProcessing: @unchecked Sendable {

    /// IIR bandpass filter
    private func bandPassFilter(_ x: [Int16], a: [Float], b: [Float]) -> [Float] {
        let n = x.count
        var y = [Float](repeating: 0, count: n)

        y[0] = b[0] * Float(x[0])

        for i in 1..<min(a.count, n) {
            y[i] = b[0] * Float(x[i])
            for j in 1...i {
                y[i] += b[j] * Float(x[i - j]) - a[j] * y[i - j]
            }
        }

        for i in a.count..<(n - 1) {
            y[i] = b[0] * Float(x[i])
            for j in 1..<a.count {
                y[i] += b[j] * Float(x[i - j]) - a[j] * y[i - j]
            }
        }

        y[n - 1] = 0
        return y
    }
}
