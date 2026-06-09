//
//  InertialTracking.swift
//  MBatmaN
//
//  Loop closure calibration for indoor mapping traces.
//

import Foundation

/// Loop closure correction for indoor mapping.
/// When the user walks a loop and returns to the start, this algorithm
/// distributes the accumulated drift error evenly across all trace points.
struct InertialTracking {

    // MARK: - Public API

    /// Apply loop closure correction to trace and wall data.
    /// Assumes the user has returned to the starting point.
    /// Distributes drift error linearly across all points.
    ///
    /// - Parameters:
    ///   - trace: Interleaved [x0, y0, x1, y1, ...] trace positions
    ///   - wallCam: Interleaved wall points from left channel
    ///   - wallMic: Interleaved wall points from right channel
    /// - Returns: Corrected trace array (wallCam/wallMic are modified in place)
    static func loopClosure(
        trace: inout [Double],
        wallCam: inout [Double],
        wallMic: inout [Double]
    ) {
        guard trace.count > 4 else { return }

        let n = trace.count
        let deltaX = trace[n - 2] / Double(n)
        let deltaY = trace[n - 1] / Double(n)

        var i = 2
        while i < n - 1 {
            // Correct X
            trace[i] -= Double(i) * deltaX
            if i < wallCam.count {
                wallCam[i] -= Double(i) * deltaX
            }
            if i < wallMic.count {
                wallMic[i] -= Double(i) * deltaX
            }

            i += 1

            // Correct Y
            if i < n {
                trace[i] -= Double(i) * deltaY
                if i < wallCam.count {
                    wallCam[i] -= Double(i) * deltaY
                }
                if i < wallMic.count {
                    wallMic[i] -= Double(i) * deltaY
                }
            }

            i += 1
        }
    }
}
