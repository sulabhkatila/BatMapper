//
//  MapCanvasView.swift
//  MBatmaN
//
//  Real-time floor plan canvas with neon glow effects,
//  grid overlay, and pan/zoom gesture support.
//

import SwiftUI

/// Custom canvas view that renders the acoustic floor plan
/// with a futuristic neon aesthetic.
struct MapCanvasView: View {
    let trace: [Double]
    let wallCam: [Double]
    let wallMic: [Double]
    let doors: [Double]

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0

    // Colors
    private let traceColor = Color(red: 0, green: 0.95, blue: 1.0)       // Cyan neon
    private let wallCamColor = Color(red: 1.0, green: 0.55, blue: 0.0)   // Orange
    private let wallMicColor = Color(red: 0.4, green: 0.6, blue: 1.0)    // Blue
    private let doorColor = Color(red: 1.0, green: 0.85, blue: 0.0)      // Gold
    private let gridColor = Color.white.opacity(0.06)
    private let gridAccentColor = Color.white.opacity(0.12)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.04, green: 0.05, blue: 0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(0.3),
                                        Color.blue.opacity(0.1),
                                        Color.purple.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2 + offset.width, y: size.height / 2 + offset.height)
                    let baseScale = min(size.width, size.height) / 80.0 * scale

                    // Draw grid
                    drawGrid(context: context, size: size, center: center, scale: baseScale)

                    // Draw wall points (rendered before trace so trace is on top)
                    drawPoints(context: context, data: wallCam, center: center, scale: baseScale,
                               color: wallCamColor, radius: 2.5, glow: true)
                    drawPoints(context: context, data: wallMic, center: center, scale: baseScale,
                               color: wallMicColor, radius: 2.5, glow: true)

                    // Draw doors
                    drawPoints(context: context, data: doors, center: center, scale: baseScale,
                               color: doorColor, radius: 4, glow: true)

                    // Draw trace path
                    drawTracePath(context: context, data: trace, center: center, scale: baseScale)

                    // Draw current position marker
                    if trace.count >= 2 {
                        let lastX = trace[trace.count - 2]
                        let lastY = trace[trace.count - 1]
                        let pt = worldToScreen(lastX, lastY, center: center, scale: baseScale)
                        drawCurrentPosition(context: context, at: pt)
                    }

                    // Draw origin marker
                    let origin = worldToScreen(0, 0, center: center, scale: baseScale)
                    drawOriginMarker(context: context, at: origin)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Legend overlay
                VStack {
                    HStack {
                        Spacer()
                        legendView
                    }
                    Spacer()
                }
                .padding(12)

                // "No data" overlay
                if trace.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 44, weight: .thin))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text("Start scanning to map")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        },
                    MagnifyGesture()
                        .onChanged { value in
                            scale = lastScale * value.magnification
                        }
                        .onEnded { _ in
                            lastScale = scale
                        }
                )
            )
        }
    }

    // MARK: - Legend

    private var legendView: some View {
        VStack(alignment: .leading, spacing: 4) {
            legendItem(color: traceColor, label: "Trace")
            legendItem(color: wallCamColor, label: "Wall L")
            legendItem(color: wallMicColor, label: "Wall R")
            legendItem(color: doorColor, label: "Doors")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                )
        )
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Drawing Helpers

    private func worldToScreen(_ wx: Double, _ wy: Double, center: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(wx) * scale,
            y: center.y - CGFloat(wy) * scale // Flip Y
        )
    }

    private func drawGrid(context: GraphicsContext, size: CGSize, center: CGPoint, scale: CGFloat) {
        let gridSpacing: CGFloat = 5.0 * scale // 5 meters per grid line

        guard gridSpacing > 5 else { return } // Don't draw if too zoomed out

        // Vertical lines
        let startX = center.x.truncatingRemainder(dividingBy: gridSpacing) - gridSpacing
        var x = startX
        while x < size.width + gridSpacing {
            let isCenter = abs(x - center.x) < 1
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(isCenter ? gridAccentColor : gridColor), lineWidth: isCenter ? 1 : 0.5)
            x += gridSpacing
        }

        // Horizontal lines
        let startY = center.y.truncatingRemainder(dividingBy: gridSpacing) - gridSpacing
        var y = startY
        while y < size.height + gridSpacing {
            let isCenter = abs(y - center.y) < 1
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(isCenter ? gridAccentColor : gridColor), lineWidth: isCenter ? 1 : 0.5)
            y += gridSpacing
        }
    }

    private func drawPoints(context: GraphicsContext, data: [Double], center: CGPoint, scale: CGFloat,
                            color: Color, radius: CGFloat, glow: Bool) {
        var i = 0
        while i + 1 < data.count {
            let wx = data[i]
            let wy = data[i + 1]
            i += 2

            // Skip zero points
            guard wx != 0 || wy != 0 else { continue }

            let pt = worldToScreen(wx, wy, center: center, scale: scale)

            if glow {
                // Outer glow
                let glowRect = CGRect(x: pt.x - radius * 2, y: pt.y - radius * 2, width: radius * 4, height: radius * 4)
                context.fill(Path(ellipseIn: glowRect), with: .color(color.opacity(0.15)))
            }

            // Core point
            let rect = CGRect(x: pt.x - radius, y: pt.y - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.85)))
        }
    }

    private func drawTracePath(context: GraphicsContext, data: [Double], center: CGPoint, scale: CGFloat) {
        guard data.count >= 4 else { return }

        var path = Path()
        let first = worldToScreen(data[0], data[1], center: center, scale: scale)
        path.move(to: first)

        var i = 2
        while i + 1 < data.count {
            let pt = worldToScreen(data[i], data[i + 1], center: center, scale: scale)
            path.addLine(to: pt)
            i += 2
        }

        // Glow layer
        context.stroke(path, with: .color(traceColor.opacity(0.2)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

        // Main line
        context.stroke(path, with: .color(traceColor.opacity(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

        // Bright core
        context.stroke(path, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 0.5, lineCap: .round, lineJoin: .round))
    }

    private func drawCurrentPosition(context: GraphicsContext, at pt: CGPoint) {
        // Pulsing rings
        let ringRadii: [CGFloat] = [12, 8, 4]
        let opacities: [Double] = [0.1, 0.2, 0.5]

        for (radius, opacity) in zip(ringRadii, opacities) {
            let rect = CGRect(x: pt.x - radius, y: pt.y - radius, width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(traceColor.opacity(opacity)), lineWidth: 1)
        }

        // Center dot
        let dotRect = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
        context.fill(Path(ellipseIn: dotRect), with: .color(.white))
    }

    private func drawOriginMarker(context: GraphicsContext, at pt: CGPoint) {
        let size: CGFloat = 8
        // Crosshair
        var h = Path()
        h.move(to: CGPoint(x: pt.x - size, y: pt.y))
        h.addLine(to: CGPoint(x: pt.x + size, y: pt.y))
        var v = Path()
        v.move(to: CGPoint(x: pt.x, y: pt.y - size))
        v.addLine(to: CGPoint(x: pt.x, y: pt.y + size))

        context.stroke(h, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
        context.stroke(v, with: .color(.white.opacity(0.3)), lineWidth: 0.5)
    }
}
