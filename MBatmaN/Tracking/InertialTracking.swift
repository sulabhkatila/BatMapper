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

        let numPoints = trace.count / 2
        let errorX = trace[trace.count - 2]
        let errorY = trace[trace.count - 1]

        for k in 1..<numPoints {
            // Use (numPoints - 1) so the final point gets a ratio of exactly 1.0 (100% correction to origin)
            let ratio = Double(k) / Double(numPoints - 1)
            
            let iX = 2 * k
            let iY = 2 * k + 1
            
            let corrX = errorX * ratio
            let corrY = errorY * ratio
            
            trace[iX] -= corrX
            trace[iY] -= corrY
            
            if iX < wallCam.count { wallCam[iX] -= corrX }
            if iY < wallCam.count { wallCam[iY] -= corrY }
            
            if iX < wallMic.count { wallMic[iX] -= corrX }
            if iY < wallMic.count { wallMic[iY] -= corrY }
        }
    }
}
