//
//  OutlierRemoval.swift
//  MBatmaN
//
//  Input: ranked distance measurements
//  Output: smoothed single distance value
//

import Foundation

/// Windowed mean-based outlier removal for distance measurements.
/// Marked nonisolated to allow calling from audio background thread.
nonisolated final class OutlierRemoval: @unchecked Sendable {

    // MARK: - State

    private var qTop: [Float] = []
    private let windowLength: Int = 10
    private var dMean: Float = 0
    private var output: Float = 0
    private var found: Bool = false

    // MARK: - Public API

    /// Process ranked distance/amplitude pairs and return smoothed distance.
    func getFinalDis(_ disAmp: [[Float]]) -> Float {
        let ds = disAmp.map { $0[0] }
        found = false

        if qTop.isEmpty {
            qTop.append(ds[0])
            dMean = ds[0]
        } else if qTop.count < windowLength {
            dMean = (dMean * Float(qTop.count) + ds[0]) / Float(qTop.count + 1)
            qTop.append(ds[0])
        } else {
            output = qTop.removeFirst()

            for d in ds {
                if abs(d - dMean) < 0.3 {
                    qTop.append(d)
                    dMean = dMean + (d - output) / Float(windowLength)
                    found = true
                    return output
                }
            }

            if !found {
                qTop.append(dMean)
                dMean = dMean + (dMean - output) / Float(windowLength)
            }
        }

        return output
    }
}
