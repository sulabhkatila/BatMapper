//
//  ContentView.swift
//  MBatmaN
//
//  Main interface for the BatMapper iOS app.
//

import SwiftUI

struct ContentView: View {
  @StateObject private var viewModel = BatMapperViewModel()
  @State private var showSettings = false
  @State private var showExportSheet = false
  @State private var exportURL: URL?
  @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView

            // MARK: - Sensor Cards
            sensorCardsView
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // MARK: - Map Canvas
            ZStack(alignment: .bottomLeading) {
                MapCanvasView(
                    trace: viewModel.trace,
                    wallCam: viewModel.wallCam,
                    wallMic: viewModel.wallMic,
                    doors: viewModel.doors
                )

                // Point count badge
                if viewModel.pointCount > 0 {
                    Text("\(viewModel.pointCount) pts")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .padding(12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Spacer(minLength: 8)

            // MARK: - Control Bar
            controlBar
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .background(backgroundView)
    .preferredColorScheme(.dark)
    .sheet(isPresented: $showSettings) {
      SettingsView(viewModel: viewModel)
    }
    .sheet(isPresented: $showExportSheet) {
      if let url = exportURL {
        ShareSheet(activityItems: [url])
      }
    }
    .onAppear {
      withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
        pulseAnimation = true
      }
    }
  }

  // MARK: - Background

  private var backgroundView: some View {
    ZStack {
      Color(red: 0.03, green: 0.03, blue: 0.07)
        .ignoresSafeArea()

      // Subtle gradient orbs
      Circle()
        .fill(
          RadialGradient(
            colors: [Color.cyan.opacity(0.08), Color.clear],
            center: .center,
            startRadius: 0,
            endRadius: 300
          )
        )
        .frame(width: 600, height: 600)
        .offset(x: -100, y: -200)
        .blur(radius: 80)

      Circle()
        .fill(
          RadialGradient(
            colors: [Color.purple.opacity(0.05), Color.clear],
            center: .center,
            startRadius: 0,
            endRadius: 250
          )
        )
        .frame(width: 500, height: 500)
        .offset(x: 150, y: 300)
        .blur(radius: 60)
    }
  }

  // MARK: - Header

  private var headerView: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Image(systemName: "waveform.badge.magnifyingglass")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(
              LinearGradient(
                colors: [.cyan, .blue],
                startPoint: .leading,
                endPoint: .trailing
              )
            )

          Text("MBatmaN")
            .font(.system(size: 22, weight: .bold, design: .monospaced))
            .foregroundStyle(
              LinearGradient(
                colors: [.white, .white.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
        }

        Text("ACOUSTIC INDOOR MAPPING")
          .font(.system(size: 9, weight: .bold, design: .monospaced))
          .foregroundColor(.cyan.opacity(0.5))
          .tracking(3)
      }

      Spacer()

      // Status indicator
      HStack(spacing: 6) {
        Circle()
          .fill(viewModel.isScanning ? Color.green : Color.white.opacity(0.2))
          .frame(width: 8, height: 8)
          .shadow(color: viewModel.isScanning ? .green.opacity(0.8) : .clear, radius: 4)
          .scaleEffect(viewModel.isScanning && pulseAnimation ? 1.3 : 1.0)

        Text(viewModel.isScanning ? "LIVE" : "IDLE")
          .font(.system(size: 10, weight: .bold, design: .monospaced))
          .foregroundColor(viewModel.isScanning ? .green : .white.opacity(0.3))
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(
        Capsule()
          .fill(Color.white.opacity(0.05))
          .overlay(
            Capsule()
              .stroke(Color.white.opacity(0.08), lineWidth: 1)
          )
      )

      // Settings button
      Button(action: { showSettings = true }) {
        Image(systemName: "gearshape.fill")
          .font(.system(size: 16))
          .foregroundColor(.white.opacity(0.5))
          .frame(width: 36, height: 36)
          .background(
            Circle()
              .fill(Color.white.opacity(0.05))
              .overlay(
                Circle()
                  .stroke(Color.white.opacity(0.08), lineWidth: 1)
              )
          )
      }
      .padding(.leading, 8)
    }
    .padding(.horizontal, 20)
    .padding(.top, 8)
  }

  // MARK: - Sensor Cards

  private var sensorCardsView: some View {
    HStack(spacing: 10) {
      sensorCard(
        icon: "location.north.fill",
        label: "YAW",
        value: String(format: "%.1f°", viewModel.yaw),
        color: .cyan
      )

      sensorCard(
        icon: "figure.walk",
        label: "STEPS",
        value: "\(viewModel.stepCount)",
        color: .green
      )

      sensorCard(
        icon: "arrow.left.to.line",
        label: "DIST L",
        value: String(format: "%.2fm", viewModel.distL),
        color: .orange
      )

      sensorCard(
        icon: "arrow.right.to.line",
        label: "DIST R",
        value: String(format: "%.2fm", viewModel.distR),
        color: Color(red: 0.4, green: 0.6, blue: 1.0)
      )
    }
  }

  private func sensorCard(icon: String, label: String, value: String, color: Color) -> some View {
    VStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(color.opacity(0.8))

      Text(value)
        .font(.system(size: 14, weight: .bold, design: .monospaced))
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)

      Text(label)
        .font(.system(size: 8, weight: .bold, design: .monospaced))
        .foregroundColor(.white.opacity(0.3))
        .tracking(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 10)
        .fill(Color.white.opacity(0.03))
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(
              LinearGradient(
                colors: [color.opacity(0.2), Color.white.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
              ),
              lineWidth: 1
            )
        )
    )
  }

  // MARK: - Control Bar

  private var controlBar: some View {
    HStack(spacing: 12) {
      // Loop Closure button
      controlButton(
        icon: "arrow.triangle.2.circlepath",
        label: "LOOP",
        enabled: !viewModel.trace.isEmpty && !viewModel.isScanning
      ) {
        viewModel.applyLoopClosure()
      }

      // Main START/STOP button
      Button(action: { viewModel.toggleScanning() }) {
        HStack(spacing: 8) {
          Image(systemName: viewModel.isScanning ? "stop.fill" : "waveform")
            .font(.system(size: 16, weight: .bold))

          Text(viewModel.isScanning ? "STOP" : "START")
            .font(.system(size: 14, weight: .heavy, design: .monospaced))
            .tracking(2)
        }
        .foregroundColor(viewModel.isScanning ? .red : .black)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
          RoundedRectangle(cornerRadius: 14)
            .fill(
              viewModel.isScanning
                ? AnyShapeStyle(Color.red.opacity(0.15))
                : AnyShapeStyle(
                  LinearGradient(
                    colors: [.cyan, Color(red: 0, green: 0.7, blue: 1.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
            )
            .overlay(
              RoundedRectangle(cornerRadius: 14)
                .stroke(
                  viewModel.isScanning ? Color.red.opacity(0.4) : Color.cyan.opacity(0.5),
                  lineWidth: 1
                )
            )
        )
        .shadow(
          color: viewModel.isScanning ? .red.opacity(0.2) : .cyan.opacity(0.3),
          radius: viewModel.isScanning ? 8 : 12,
          y: 4
        )
      }

      // Export / Reset button
      if !viewModel.trace.isEmpty && !viewModel.isScanning {
        controlButton(
          icon: "square.and.arrow.up",
          label: "SAVE",
          enabled: true
        ) {
          exportURL = viewModel.exportMap()
          if exportURL != nil {
            showExportSheet = true
          }
        }
      } else {
        controlButton(
          icon: "arrow.counterclockwise",
          label: "RESET",
          enabled: !viewModel.trace.isEmpty && !viewModel.isScanning
        ) {
          viewModel.resetMap()
        }
      }
    }
  }

  private func controlButton(
    icon: String, label: String, enabled: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      VStack(spacing: 4) {
        Image(systemName: icon)
          .font(.system(size: 16, weight: .semibold))
        Text(label)
          .font(.system(size: 8, weight: .bold, design: .monospaced))
          .tracking(1)
      }
      .foregroundColor(enabled ? .white.opacity(0.8) : .white.opacity(0.2))
      .frame(width: 56, height: 50)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.white.opacity(enabled ? 0.06 : 0.02))
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .stroke(Color.white.opacity(enabled ? 0.1 : 0.04), lineWidth: 1)
          )
      )
    }
    .disabled(!enabled)
  }
}

// MARK: - ShareSheet (UIKit bridge)

struct ShareSheet: UIViewControllerRepresentable {
  let activityItems: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
  ContentView()
}
