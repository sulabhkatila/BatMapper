//
//  MotionTracker.swift
//  MBatmaN
//
//  Handles device orientation, step detection, and map point generation.
//

import Foundation
import CoreMotion

/// Tracks device motion (orientation) and fuses with acoustic
/// distance measurements to generate floor plan points.
///
/// This is a plain class (not ObservableObject). The ViewModel reads
/// its properties via a timer to ensure reliable SwiftUI updates.
final class MotionTracker {

    // MARK: - State (read by ViewModel via timer)

    var yaw: Float = 0
    var isTracking: Bool = false

    // Map data (interleaved [x0, y0, x1, y1, ...])
    var trace: [Double] = []
    var wallCam: [Double] = []
    var wallMic: [Double] = []
    var doors: [Double] = []

    /// Count of generated map points (for UI feedback)
    var pointCount: Int = 0

    // MARK: - Settings

    var stepLength: Float = 1.0
    var sensorScanRate: Int = 20

    // MARK: - Private state

    private let motionManager = CMMotionManager()
    private var timer: Timer?

    // Walking state: track whether user is actively moving
    private var isWalking: Bool = false
    private var walkingTicks: Int = 0
    private var idleTicks: Int = 0
    private let walkingTimeout: Int = 40  // Stop generating after ~2s of no movement

    // Orientation smoothing state
    private var queueOrientation: [Float] = []
    private var rawReading: [Float] = []
    private var mean: Float = 0
    private var sum: Float = 0
    private var drift: Float = 0
    private var delay: Float = 0
    private var diffInputMean: Float = 0
    private var turnDrift: Float = 0

    // Door detection state
    private var dCamBuffer: [Float] = []
    private var dMicBuffer: [Float] = []
    private var dCamDoorBuffer: [Double] = []
    private var dMicDoorBuffer: [Double] = []
    private var inDoorCam: Bool = false
    private var inDoorMic: Bool = false
    private var camCount: Int = 0
    private var micCount: Int = 0
    private let doorDepth: Double = 0.05
    private let doorCountMax: Int = 20
    private let doorCountMin: Int = 4

    // Door queues
    private var doorLQ: [Float] = []
    private var doorRQ: [Float] = []
    private let doorWindow: Int = 50

    // Kalman filters for smoothing
    private let yawFilter = KalmanFilter(q: 0.1, r: 0.1, p: 1.0)
    private let dCamFilter = KalmanFilter(q: 0.01, r: 0.1, p: 1.0)
    private let dMicFilter = KalmanFilter(q: 0.01, r: 0.1, p: 1.0)

    // Audio recorder reference for getting distances
    weak var audioRecorder: AudioRecorder?

    // MARK: - Public API

    /// Start tracking motion and building the map.
    func startTracking() {
        guard !isTracking else { return }

        resetState()
        isTracking = true

        // Start device motion updates
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / Double(sensorScanRate)
            motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        }

        // Main processing timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / Double(sensorScanRate), repeats: true) { [weak self] _ in
            self?.processSensorUpdate()
        }
    }

    /// Stop tracking.
    func stopTracking() {
        isTracking = false
        timer?.invalidate()
        timer = nil
        motionManager.stopDeviceMotionUpdates()
    }

    /// Apply loop closure correction.
    func applyLoopClosure() {
        InertialTracking.loopClosure(trace: &trace, wallCam: &wallCam, wallMic: &wallMic)
    }

    // MARK: - Private Processing

    private func resetState() {
        trace.removeAll()
        wallCam.removeAll()
        wallMic.removeAll()
        doors.removeAll()
        pointCount = 0
        yaw = 0
        isWalking = false
        walkingTicks = 0
        idleTicks = 0
        queueOrientation.removeAll()
        rawReading.removeAll()
        mean = 0
        sum = 0
        drift = 0
        delay = 0
        diffInputMean = 0
        turnDrift = 0
        dCamBuffer.removeAll()
        dMicBuffer.removeAll()
        dCamDoorBuffer.removeAll()
        dMicDoorBuffer.removeAll()
        inDoorCam = false
        inDoorMic = false
        camCount = 0
        micCount = 0
        doorLQ.removeAll()
        doorRQ.removeAll()
        yawFilter.reset()
        dCamFilter.reset()
        dMicFilter.reset()
    }

    private func processSensorUpdate() {
        guard isTracking else { return }

        // Get current device orientation
        guard let motion = motionManager.deviceMotion else { return }

        // Get yaw in degrees and smooth it
        var rawYaw = Float(motion.attitude.yaw * 180.0 / .pi)
        rawYaw = smoothOrientation(rawYaw)
        yaw = yawFilter.filter(rawYaw)

        // Get current distances from audio recorder
        var dCam = audioRecorder?.distL ?? 0
        var dMic = audioRecorder?.distR ?? 0
        
        if dCam != 0 {
            dCam = dCamFilter.filter(dCam)
        } else {
            dCamFilter.reset()
        }
        
        if dMic != 0 {
            dMic = dMicFilter.filter(dMic)
        } else {
            dMicFilter.reset()
        }

        // Update door detection queues
        if doorLQ.count < doorWindow {
            doorLQ.append(dCam)
        } else {
            doorLQ.removeFirst()
            doorLQ.append(dCam)
        }

        if doorRQ.count < doorWindow {
            doorRQ.append(dMic)
        } else {
            doorRQ.removeFirst()
            doorRQ.append(dMic)
        }

        // Determine if we should generate trace points
        // Use user acceleration magnitude as a walking indicator
        let accelMag = sqrt(
            motion.userAcceleration.x * motion.userAcceleration.x +
            motion.userAcceleration.y * motion.userAcceleration.y +
            motion.userAcceleration.z * motion.userAcceleration.z
        )

        // If user acceleration > threshold, they're moving
        if accelMag > 0.05 {
            isWalking = true
            walkingTicks = max(walkingTicks, sensorScanRate / 2)
            idleTicks = 0
        }

        // Manage walking state
        if walkingTicks > 0 {
            walkingTicks -= 1
        } else if isWalking {
            idleTicks += 1
            if idleTicks > walkingTimeout {
                isWalking = false
            }
        }

        // Build map points
        if trace.isEmpty {
            // Initialize with origin
            trace.append(contentsOf: [0.0, 0.0])
            wallCam.append(contentsOf: [0.0, 0.0])
            wallMic.append(contentsOf: [0.0, 0.0])
            dCamBuffer.append(contentsOf: [dCam, dCam, dCam])
            dMicBuffer.append(contentsOf: [dMic, dMic, dMic])
            pointCount = 1
        } else if isWalking || walkingTicks > 0 {
            // Calculate new trace position
            let yawRad = Double(yaw) * .pi / 180.0
            let displacement = Double(stepLength) / Double(sensorScanRate)
            let x = trace[trace.count - 2] + cos(yawRad) * displacement
            let y = trace[trace.count - 1] + sin(yawRad) * displacement

            var xCam: Double = 0
            var yCam: Double = 0
            var xMic: Double = 0
            var yMic: Double = 0

            let tracingDelay = 5
            if trace.count > tracingDelay {
                let negYawRad = Double(-yaw) * .pi / 180.0 + .pi

                if dCam != 0 {
                    xCam = trace[trace.count - tracingDelay - 1] - Double(dCam) * sin(negYawRad)
                    yCam = trace[trace.count - tracingDelay] - Double(dCam) * cos(negYawRad)
                }
                if dMic != 0 {
                    xMic = trace[trace.count - tracingDelay - 1] + Double(dMic) * sin(negYawRad)
                    yMic = trace[trace.count - tracingDelay] + Double(dMic) * cos(negYawRad)
                }
            }

            trace.append(x)
            trace.append(y)
            wallCam.append(xCam)
            wallCam.append(yCam)
            wallMic.append(xMic)
            wallMic.append(yMic)
            pointCount += 1

            // Door detection logic
            processDoorDetection(
                dCam: dCam, dMic: dMic,
                xCam: xCam, yCam: yCam,
                xMic: xMic, yMic: yMic
            )

            // Update distance buffers
            dCamBuffer.append(dCam)
            dMicBuffer.append(dMic)
            if dCamBuffer.count > 4 {
                dCamBuffer.removeFirst()
                dMicBuffer.removeFirst()
            }
        }
    }

    // MARK: - Door Detection

    private func processDoorDetection(dCam: Float, dMic: Float, xCam: Double, yCam: Double, xMic: Double, yMic: Double) {
        guard dCamBuffer.count >= 3 else { return }

        // Check entering door (left wall)
        if Double(dCam - dCamBuffer[0]) > doorDepth &&
           Double(dCam - dCamBuffer[1]) > doorDepth &&
           Double(dCam - dCamBuffer[2]) > doorDepth {
            inDoorCam = true
        }

        // Check entering door (right wall)
        if Double(dMic - dMicBuffer[0]) > doorDepth &&
           Double(dMic - dMicBuffer[1]) > doorDepth &&
           Double(dMic - dMicBuffer[2]) > doorDepth {
            inDoorMic = true
        }

        // Buffer door points
        if inDoorCam {
            dCamDoorBuffer.append(xCam)
            dCamDoorBuffer.append(yCam)
            camCount += 1
        }
        if inDoorMic {
            dMicDoorBuffer.append(xMic)
            dMicDoorBuffer.append(yMic)
            micCount += 1
        }

        // Check exiting door (left wall)
        if Double(dCamBuffer[0] - dCam) > doorDepth &&
           camCount < doorCountMax && camCount > doorCountMin &&
           Double(dCamBuffer[1] - dCam) > doorDepth {
            inDoorCam = false
            doors.append(contentsOf: dCamDoorBuffer)
            dCamDoorBuffer.removeAll()
            camCount = 0
        }

        // Check exiting door (right wall)
        if Double(dMicBuffer[0] - dMic) > doorDepth &&
           micCount < doorCountMax && micCount > doorCountMin &&
           Double(dMicBuffer[1] - dMic) > doorDepth {
            inDoorMic = false
            doors.append(contentsOf: dMicDoorBuffer)
            dMicDoorBuffer.removeAll()
            micCount = 0
        }

        // Clear if door too large
        if camCount > doorCountMax {
            dCamDoorBuffer.removeAll()
            camCount = 0
            inDoorCam = false
        }
        if micCount > doorCountMax {
            dMicDoorBuffer.removeAll()
            micCount = 0
            inDoorMic = false
        }
    }

    // MARK: - Orientation Smoothing

    /// Turn detection + right-angle snapping
    private func smoothOrientation(_ input: Float) -> Float {
        var input = input
        let numberOfPoints = 10
        let orientationTolerance: Float = 5
        let bufferLength = 10

        // Reset initial orientation to zero
        if queueOrientation.isEmpty {
            drift = input
            input = 0
        } else {
            input = input - drift
        }

        // If queue < 10 points, return directly
        if queueOrientation.count < numberOfPoints {
            queueOrientation.append(input)
            rawReading.append(input)
            sum += input
            mean = 0
            return input
        } else {
            // Calculate buffer average and variance
            var sumBuffer: Float = 0
            let readingCount = rawReading.count
            for i in 1...bufferLength {
                if readingCount - i >= 0 {
                    sumBuffer += rawReading[readingCount - i]
                }
            }
            let averageBuffer = sumBuffer / Float(bufferLength)

            var sumVariance: Float = 0
            for i in 1...bufferLength {
                if readingCount - i >= 0 {
                    let diff = rawReading[readingCount - i] - averageBuffer
                    sumVariance += diff * diff
                }
            }
            let averageVariance = sumVariance / Float(bufferLength)

            if averageVariance < orientationTolerance {
                // No turn detected
                queueOrientation.removeFirst()
                queueOrientation.append(mean)
                rawReading.append(input)
            } else {
                delay = 120
            }

            if delay >= 0 {
                // Turn detected
                delay -= 1
                rawReading.append(input)
                diffInputMean = input - mean

                let direction: Float = diffInputMean > 0 ? 1 : -1
                let absDiff = abs(diffInputMean)

                // Check for right-angle turn
                if absDiff > (90 - orientationTolerance) && absDiff < (90 + orientationTolerance) {
                    mean += direction * 90
                    turnDrift += mean - input
                }

                return input
            } else {
                mean = input + turnDrift
            }
        }

        return mean
    }
}
//
//  KalmanFilter.swift
//  MBatmaN
//
//  A simple 1D Kalman Filter for smoothing noisy sensor data.
//

import Foundation

class KalmanFilter {
    var q: Float // Process noise covariance
    var r: Float // Measurement noise covariance
    var x: Float // Value
    var p: Float // Estimation error covariance
    var k: Float // Kalman gain
    var isInitialized: Bool = false

    init(q: Float = 0.01, r: Float = 0.1, p: Float = 0.1) {
        self.q = q
        self.r = r
        self.p = p
        self.x = 0.0
        self.k = 0.0
    }

    func filter(_ measurement: Float) -> Float {
        if !isInitialized {
            self.x = measurement
            self.isInitialized = true
            return x
        }
        // Prediction update
        p = p + q

        // Measurement update
        k = p / (p + r)
        x = x + k * (measurement - x)
        p = (1 - k) * p

        return x
    }
    
    func reset() {
        self.isInitialized = false
        self.x = 0.0
    }
}
