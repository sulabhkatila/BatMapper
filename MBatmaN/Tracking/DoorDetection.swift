//
//  DoorDetection.swift
//  MBatmaN
//
//  Detects doors from wall distance discontinuities.
//

import Foundation

/// Door detection from wall distance measurements.
/// Doors appear as sudden increases in measured wall distance
/// (the sonar "sees" through the door opening to the far wall).
struct DoorDetection {

    // MARK: - Constants

    static let circleRadius: Float = 1.0

    // MARK: - Public API

    /// Generate circle markers at door locations based on slope changes in wall data.
    /// - Parameters:
    ///   - wallCam: Interleaved [x, y, ...] wall points from left channel
    ///   - wallMic: Interleaved [x, y, ...] wall points from right channel
    /// - Returns: Interleaved [x, y, ...] circle points marking door locations
    static func generateCircles(wallCam: [Double], wallMic: [Double]) -> [Double] {
        var circles = [Double]()

        let allLists = [wallCam, wallMic]

        for list in allLists {
            guard list.count > 20 else { continue }

            var prevSlope: Double = 0
            var firstTime = true
            let limit = (list.count / 2) - 10

            for i in 3..<limit {
                if firstTime {
                    let deltaX1 = list[(2 * i) - 2] - list[(2 * i) - 4]
                    let deltaY1 = list[(2 * i) - 3] - list[(2 * i) - 5]
                    prevSlope = deltaX1 != 0 ? deltaY1 / deltaX1 : 0
                    firstTime = false
                }

                let deltaX2 = list[2 * i] - list[(2 * i) - 2]
                let deltaY2 = list[(2 * i) - 1] - list[(2 * i) - 3]
                let nextSlope = deltaX2 != 0 ? deltaY2 / deltaX2 : 0

                if abs(prevSlope - nextSlope) > 0.1 {
                    var m: Double = 0
                    while m <= 2 * Double.pi {
                        circles.append(list[2 * i] + cos(m))
                        circles.append(list[(2 * i) + 1] + sin(m))
                        m += Double.pi / 16
                    }
                }

                prevSlope = nextSlope
            }
        }

        return circles
    }

    /// Check if currently passing through a door based on distance buffer.
    /// - Parameters:
    ///   - queue: Recent distance measurements
    ///   - windowSize: Size of the analysis window
    /// - Returns: true if a door is detected
    static func getDoorState(queue: [Float], windowSize: Int) -> Bool {
        guard queue.count == windowSize else { return false }

        let half = windowSize / 2
        var dPre: Float = 0
        var dNew: Float = 0

        for i in 0..<half {
            dPre += queue[i]
            dNew += queue[i + half]
        }

        dPre /= Float(half)
        dNew /= Float(half)

        if dNew - dPre > 0.2 && dNew - dPre < 0.3 {
            return true
        }

        return false
    }
}
