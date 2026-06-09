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

    /// Cross-correlation of signal f with template g
    private func crossCorrelate(_ f: [Float], g: [Float]) -> [Float] {
        let n = f.count
        var res = [Float](repeating: 0, count: n)

        guard n > g.count else { return res }

        for T in 0..<(n - g.count) {
            res[T] = 0
            for t in 0..<g.count {
                res[T] += f[t + T] * g[t]
            }
        }

        return res
    }

}
