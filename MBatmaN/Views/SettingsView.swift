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

                Form {
                    Section {
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
                    } header: {
                        Text("MAP CONFIGURATION")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan.opacity(0.7))
                            .tracking(2)
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                    .listRowSeparatorTint(Color.white.opacity(0.1))

                    Section {
                        stepperSetting(
                            title: "Scan Rate",
                            value: $viewModel.sensorScanRate,
                            range: 5...60,
                            unit: "Hz",
                            icon: "gauge.with.dots.needle.33percent"
                        )
                    } header: {
                        Text("SENSOR PARAMETERS")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan.opacity(0.7))
                            .tracking(2)
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                    .listRowSeparatorTint(Color.white.opacity(0.1))

                    Section {
                        textFieldSetting(
                            title: "Building Name",
                            text: $viewModel.buildingName,
                            icon: "building.2"
                        )
                    } header: {
                        Text("EXPORT")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan.opacity(0.7))
                            .tracking(2)
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                    .listRowSeparatorTint(Color.white.opacity(0.1))

                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("MBatmaN")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("Based on BatMapper research by Zhou et al.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))

                            Text("\"Acoustic sensing based indoor floor plan construction using smartphones\" — MobiSys 2017")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.white.opacity(0.35))
                                .padding(.top, 2)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("ABOUT")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan.opacity(0.7))
                            .tracking(2)
                    }
                    .listRowBackground(Color.white.opacity(0.04))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.cyan)
                }
            }
        }
    }

    // MARK: - Setting Controls

    private func sliderSetting(title: String, value: Binding<Float>, range: ClosedRange<Float>, unit: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.cyan.opacity(0.8))
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text(String(format: "%.1f %@", value.wrappedValue, unit))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            Slider(value: value, in: range)
                .tint(.cyan)
        }
        .padding(.vertical, 4)
    }

    private func stepperSetting(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.cyan.opacity(0.8))
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            Spacer()

            HStack(spacing: 16) {
                Button(action: { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.cyan.opacity(0.8))
                        .font(.system(size: 22))
                }

                Text("\(value.wrappedValue) \(unit)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
                    .frame(minWidth: 50, alignment: .center)

                Button(action: { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.cyan.opacity(0.8))
                        .font(.system(size: 22))
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func textFieldSetting(title: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.cyan.opacity(0.8))
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            Spacer()

            TextField("Name", text: text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.cyan)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 160)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                )
        }
        .padding(.vertical, 4)
    }
}
