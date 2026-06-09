//
//  SettingsView.swift
//  MBatmaN
//
//  Settings panel with futuristic dark UI.
//

import SwiftUI

/// Settings view for configuring BatMapper parameters.
struct SettingsView: View {
    @ObservedObject var viewModel: BatMapperViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.04, green: 0.05, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Map Settings
                        settingsSection(title: "MAP CONFIGURATION", icon: "map") {
                            sliderSetting(
                                title: "Map Range",
                                value: $viewModel.mapRange,
                                range: 10...100,
                                unit: "m",
                                icon: "arrow.left.and.right"
                            )

                            sliderSetting(
                                title: "Step Length",
                                value: $viewModel.stepLength,
                                range: 0.3...2.0,
                                unit: "m",
                                icon: "figure.walk"
                            )
                        }

                        // Sensor Settings
                        settingsSection(title: "SENSOR PARAMETERS", icon: "waveform") {
                            stepperSetting(
                                title: "Scan Rate",
                                value: $viewModel.sensorScanRate,
                                range: 5...60,
                                unit: "Hz",
                                icon: "gauge.with.dots.needle.33percent"
                            )
                        }

                        // Export Settings
                        settingsSection(title: "EXPORT", icon: "square.and.arrow.up") {
                            textFieldSetting(
                                title: "Building Name",
                                text: $viewModel.buildingName,
                                icon: "building.2"
                            )
                        }

                        // About
                        settingsSection(title: "ABOUT", icon: "info.circle") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MBatmaN")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)

                                Text("Based on BatMapper research by Zhou et al.")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))

                                Text("\"Acoustic sensing based indoor floor plan construction using smartphones\" — MobiSys 2017")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.35))
                                    .padding(.top, 2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)
                }
            }
        }
    }

    // MARK: - Section Builder

    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.cyan.opacity(0.7))
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(2)
            }

            // Section content
            VStack(spacing: 16) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Setting Controls

    private func sliderSetting(title: String, value: Binding<Float>, range: ClosedRange<Float>, unit: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.cyan.opacity(0.6))
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(String(format: "%.1f %@", value.wrappedValue, unit))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            Slider(value: value, in: range)
                .tint(.cyan)
        }
    }

    private func stepperSetting(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.cyan.opacity(0.6))
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Spacer()

            HStack(spacing: 12) {
                Button(action: { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.cyan.opacity(0.6))
                        .font(.system(size: 20))
                }

                Text("\(value.wrappedValue) \(unit)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .frame(minWidth: 50)

                Button(action: { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.cyan.opacity(0.6))
                        .font(.system(size: 20))
                }
            }
        }
    }

    private func textFieldSetting(title: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.cyan.opacity(0.6))
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            Spacer()

            TextField("Name", text: text)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.cyan)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 150)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.05))
                )
        }
    }
}
