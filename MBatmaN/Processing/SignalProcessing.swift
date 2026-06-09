//
//  SignalProcessing.swift
//  MBatmaN
//
//  Input: buffer of sound recording samples
//  Output: distance measurement candidates for distance-object association
//

import Foundation

/// Acoustic signal processing pipeline for BatMapper.
/// Steps: Bandpass Filter → Cross-Correlation → Smoothing → Peak Detection → Distance Generation
///
/// Marked nonisolated to allow calling from the audio engine's background thread.
nonisolated final class SignalProcessing: @unchecked Sendable {

    // MARK: - Constants

    /// Overlap window: 40ms at 48kHz
    private let overLap: Int = 40 * 48000 / 1000

    /// Sample rate
    private let sRate: Int = 48000

    /// Number of top distance candidates to return
    private let nCandidates: Int = 8

    /// Minimum measurable distance (meters)
    private let minRange: Float = 0.3

    /// Maximum measurable distance (meters)
    private let maxRange: Float = 5.0

    /// Chirp signal template (matched filter kernel)
    private let chirp: [Float] = [
        0, -0.0026132, -0.0042297, 0.034795, -0.059418,
        0.02043366, 0.0929047, -0.195618, 0.1606969, 0.0527688,
        -0.3189, 0.412045, -0.1913417, -0.248626, 0.60615,
        -0.584082, 0.130236, 0.487933, -0.84944, 0.675767,
        -0.040697, -0.663296, 0.9829, -0.705999, -3.919488e-15,
        0.70215938, -0.98290, 0.696682, -0.040697, -0.589379,
        0.849443, -0.63949, 0.130236, 0.369866, -0.60615,
        0.50764897, -0.19134, -0.13862, 0.3189, -0.304114,
        0.1606969, -0.000533, -0.0929047, 0.10128, -0.059418,
        0.01542, 0.00422975, -0.00339, 0
    ]

    /// IIR bandpass filter coefficients (denominator)
    private static let coeffA: [Float] = [
        1.0, -5.3191965, 12.7014, -17.702244, 15.70216,
        -9.05636137, 3.31085209, -0.70045, 0.0655805
    ]

    /// IIR bandpass filter coefficients (numerator)
    private static let coeffB: [Float] = [
        0.2560869, -2.048695, 7.1704337, -14.3408674, 17.926084266,
        -14.3408674, 7.1704337, -2.048695, 0.2560869
    ]

    // MARK: - State

    private var begin: Int = 0
    private var distanceFinal: [[Float]] = []

    // MARK: - Public API

    /// Main processing pipeline. Takes raw audio samples, returns distance candidates.
    /// - Parameter recording: Array of Int16 audio samples
    /// - Returns: Array of [distance, amplitude] pairs, sorted by amplitude descending
    func process(_ recording: [Int16]) -> [[Float]] {
        guard recording.count > chirp.count + 10 else {
            return [[Float]](repeating: [0, 0], count: nCandidates)
        }

        // Step 1: Bandpass filter
        var recFloat = bandPassFilter(recording, a: SignalProcessing.coeffA, b: SignalProcessing.coeffB)

        // Step 2: Cross-correlation with chirp template
        recFloat = crossCorrelate(recFloat, g: chirp)

        // Step 3: Gaussian smoothing
        smooth(&recFloat, amount: 5)

        // Step 4: Find beginning (chirp emission point)
        let limit = min(overLap, recFloat.count)
        begin = findBeginning(recFloat, limit: limit)

        // Step 5: Generate distance candidates from peaks
        distanceFinal = distanceGeneration(begin: begin, rec: recFloat, min: minRange, max: maxRange, rate: sRate)

        return distanceFinal
    }

    /// Returns the top distance from the last processing run
    func getFinalDistance() -> Float {
        if !distanceFinal.isEmpty {
            return distanceFinal[0][0]
        }
        return 0
    }

    // MARK: - Private Pipeline Steps

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

    /// Gaussian smoothing in-place
    private func smooth(_ buffer: inout [Float], amount: Int) {
        let temp = buffer
        let n = buffer.count

        for i in 0..<n {
            buffer[i] = 0
            let jStart = max(0, i - 2 * amount)
            let jEnd = min(n - 1, i + 2 * amount)
            for j in jStart...jEnd {
                let diff = Float(j - i) / Float(amount)
                buffer[i] += abs(temp[j]) * exp(-diff * diff / 2.0)
            }
        }
    }

    /// Find the index of maximum amplitude within the overlap window (chirp emission point)
    private func findBeginning(_ rec: [Float], limit: Int) -> Int {
        var maxVal: Float = 0
        var idx = 0

        for T in 0..<limit {
            if abs(rec[T]) > maxVal {
                maxVal = abs(rec[T])
                idx = T
            }
        }

        return idx
    }

    /// Extract top-N distance candidates from local maxima in the echo region
    private func distanceGeneration(begin: Int, rec: [Float], min: Float, max: Float, rate: Int) -> [[Float]] {
        let minPoints = Int(2 * min / 346 * Float(rate))
        let maxPoints = Int(2 * max / 346 * Float(rate))

        var dis = [Float]()
        var amp = [Float]()
        var result = [[Float]](repeating: [Float](repeating: 0, count: 2), count: nCandidates)

        let searchStart = begin + minPoints
        let searchEnd = Swift.min(begin + maxPoints, rec.count - 3)

        guard searchStart < searchEnd else { return result }

        for i in searchStart..<searchEnd {
            guard i >= 2 && i + 2 < rec.count else { continue }
            var localMax = true
            for j in -2..<2 {
                let idx = i + j
                if rec[idx] > rec[i] {
                    localMax = false
                }
            }
            if localMax {
                dis.append(173.0 * Float(i - begin) / Float(rate))
                amp.append(rec[i])
            }
        }

        // Guard against empty results
        guard !dis.isEmpty else { return result }

        var ampCopy = amp
        for i in 0..<Swift.min(nCandidates, dis.count) {
            let maxIdx = findMaxIndex(ampCopy)
            result[i][0] = dis[maxIdx]
            result[i][1] = ampCopy[maxIdx]
            ampCopy[maxIdx] = -.greatestFiniteMagnitude
        }

        return result
    }

    /// Find index of maximum value in array
    private func findMaxIndex(_ list: [Float]) -> Int {
        var idx = 0
        for i in 0..<list.count {
            if list[i] > list[idx] {
                idx = i
            }
        }
        return idx
    }
}
