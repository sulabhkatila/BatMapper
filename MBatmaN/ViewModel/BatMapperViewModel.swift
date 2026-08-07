//
//  BatMapperViewModel.swift
//  MBatmaN
//
//  Central view model orchestrating all BatMapper components.
//

import Foundation
import Combine
import UIKit
import AVFoundation

/// Main view model that orchestrates audio emission, recording,
/// motion tracking, and map generation for the BatMapper system.
///
/// Uses a refresh timer to sync data from sub-components to @Published
/// properties, ensuring reliable SwiftUI view updates.
@MainActor
final class BatMapperViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isScanning: Bool = false
    @Published var yaw: Float = 0
    @Published var distL: Float = 0
    @Published var distR: Float = 0
    @Published var pointCount: Int = 0

    // Map data
    @Published var trace: [Double] = []
    @Published var wallCam: [Double] = []
    @Published var wallMic: [Double] = []
    @Published var doors: [Double] = []

    // Settings
    @Published var mapRange: Float = 40
    @Published var stepLength: Float = 1.0
    @Published var sensorScanRate: Int = 20
    @Published var buildingName: String = "Floor Plan"

    // MARK: - Components

    private let chirpEmitter = ChirpEmitter()
    private let audioRecorder = AudioRecorder()
    private let motionTracker = MotionTracker()

    /// Timer that syncs data from components to @Published properties.
    /// This is the key mechanism that ensures SwiftUI picks up changes.
    private var refreshTimer: Timer?

    // MARK: - Actions

    /// Start the BatMapper scanning process.
    func startScanning() {
        guard !isScanning else { return }

        // Apply settings
        motionTracker.stepLength = stepLength
        motionTracker.sensorScanRate = sensorScanRate
        motionTracker.audioRecorder = audioRecorder

        // Start components
        chirpEmitter.start()

        // Small delay for audio to stabilize before recording
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self else { return }
            self.audioRecorder.start()
            self.motionTracker.startTracking()
        }

        // Start refresh timer at ~20fps to sync data → SwiftUI
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            self?.syncData()
        }

        isScanning = true
    }

    /// Stop scanning.
    func stopScanning() {
        guard isScanning else { return }

        chirpEmitter.stop()
        audioRecorder.stop()
        motionTracker.stopTracking()
        refreshTimer?.invalidate()
        refreshTimer = nil
        isScanning = false

        // Final sync to capture last data
        syncData()
    }

    /// Toggle scanning on/off.
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }

    /// Apply loop closure correction.
    func applyLoopClosure() {
        motionTracker.applyLoopClosure()
        
        // Force UI update (syncData skips if .count doesn't change)
        trace = motionTracker.trace
        wallCam = motionTracker.wallCam
        wallMic = motionTracker.wallMic
        
        syncData()
    }

    /// Export the current map as a PDF.
    func exportMap() -> URL? {
        guard !trace.isEmpty else { return nil }

        let renderer = MapPDFRenderer(
            trace: trace,
            wallCam: wallCam,
            wallMic: wallMic,
            doors: doors,
            title: buildingName
        )

        return renderer.renderPDF()
    }

    /// Reset all map data.
    func resetMap() {
        trace.removeAll()
        wallCam.removeAll()
        wallMic.removeAll()
        doors.removeAll()
        pointCount = 0
    }

    // MARK: - Data Sync

    /// Copy data from sub-components to @Published properties.
    /// This triggers SwiftUI view updates.
    private func syncData() {
        // Sync scalar values
        yaw = motionTracker.yaw
        distL = audioRecorder.distL
        distR = audioRecorder.distR
        pointCount = motionTracker.pointCount

        // Sync map arrays — only update if changed (check count as fast proxy)
        let trackerTrace = motionTracker.trace
        if trackerTrace.count != trace.count {
            trace = trackerTrace
            wallCam = motionTracker.wallCam
            wallMic = motionTracker.wallMic
            doors = motionTracker.doors
        }
    }
}

// MARK: - PDF Renderer

/// Renders the floor plan map to a PDF file.
struct MapPDFRenderer {
    let trace: [Double]
    let wallCam: [Double]
    let wallMic: [Double]
    let doors: [Double]
    let title: String

    func renderPDF() -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let mapRect = CGRect(x: 56, y: 100, width: 500, height: 500)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(title)_\(formattedDate()).pdf")

        UIGraphicsBeginPDFContextToFile(url.path, pageRect, nil)
        UIGraphicsBeginPDFPage()

        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndPDFContext()
            return nil
        }

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttrs)
        titleStr.draw(at: CGPoint(x: 56, y: 40))

        // Date
        let dateAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.gray
        ]
        let dateStr = NSAttributedString(string: formattedDate(), attributes: dateAttrs)
        dateStr.draw(at: CGPoint(x: 56, y: 65))

        // Calculate bounds
        let (minX, maxX, minY, maxY) = calculateBounds()
        let rangeX = maxX - minX
        let rangeY = maxY - minY
        let maxRange = max(rangeX, rangeY, 1)
        let scale = Double(min(mapRect.width, mapRect.height)) / maxRange
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2

        func transform(_ wx: Double, _ wy: Double) -> CGPoint {
            let sx = mapRect.midX + CGFloat((wx - centerX) * scale)
            let sy = mapRect.midY - CGFloat((wy - centerY) * scale)
            return CGPoint(x: sx, y: sy)
        }

        // Draw wall points
        context.setFillColor(UIColor.systemOrange.cgColor)
        drawPoints(wallCam, transform: transform, context: context, radius: 2)

        context.setFillColor(UIColor.systemBlue.cgColor)
        drawPoints(wallMic, transform: transform, context: context, radius: 2)

        // Draw doors
        context.setFillColor(UIColor.systemYellow.cgColor)
        drawPoints(doors, transform: transform, context: context, radius: 3)

        // Draw trace
        context.setStrokeColor(UIColor.systemRed.cgColor)
        context.setLineWidth(1.5)
        drawPath(trace, transform: transform, context: context)

        UIGraphicsEndPDFContext()
        return url
    }

    private func drawPoints(_ data: [Double], transform: (Double, Double) -> CGPoint, context: CGContext, radius: CGFloat) {
        var i = 0
        while i + 1 < data.count {
            let pt = transform(data[i], data[i + 1])
            if data[i] != 0 || data[i + 1] != 0 {
                context.fillEllipse(in: CGRect(x: pt.x - radius, y: pt.y - radius, width: radius * 2, height: radius * 2))
            }
            i += 2
        }
    }

    private func drawPath(_ data: [Double], transform: (Double, Double) -> CGPoint, context: CGContext) {
        guard data.count >= 4 else { return }
        context.beginPath()
        let first = transform(data[0], data[1])
        context.move(to: first)
        var i = 2
        while i + 1 < data.count {
            let pt = transform(data[i], data[i + 1])
            context.addLine(to: pt)
            i += 2
        }
        context.strokePath()
    }

    private func calculateBounds() -> (Double, Double, Double, Double) {
        var allX = [Double]()
        var allY = [Double]()

        let allData = [trace, wallCam, wallMic, doors]
        for data in allData {
            var i = 0
            while i + 1 < data.count {
                if data[i] != 0 || data[i + 1] != 0 {
                    allX.append(data[i])
                    allY.append(data[i + 1])
                }
                i += 2
            }
        }

        guard !allX.isEmpty else { return (-1, 1, -1, 1) }

        let padding = 2.0
        return (
            (allX.min() ?? -1) - padding,
            (allX.max() ?? 1) + padding,
            (allY.min() ?? -1) - padding,
            (allY.max() ?? 1) + padding
        )
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM_dd_HH_mm_ss"
        return formatter.string(from: Date())
    }
}
