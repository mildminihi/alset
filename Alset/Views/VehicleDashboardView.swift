import SwiftUI

struct VehicleDashboardView: View {
    @Bindable var viewModel: AppViewModel

    var body: some View {
        NavigationStack {
            List {
                if let snapshot = viewModel.vehicleSnapshot {
                    Section("Battery") {
                        LabeledContent("Level", value: percent(snapshot.batteryLevel))
                        LabeledContent("Usable", value: percent(snapshot.usableBatteryLevel))
                    }

                    Section("Climate") {
                        LabeledContent("Inside", value: temperature(snapshot.insideTemp))
                        LabeledContent("Outside", value: temperature(snapshot.outsideTemp))
                        LabeledContent("Climate On", value: yesNo(snapshot.isClimateOn))
                    }

                    Section("Vehicle") {
                        LabeledContent("Firmware", value: snapshot.carVersion ?? "—")
                        LabeledContent("Locked", value: yesNo(snapshot.locked))
                    }
                } else {
                    Section {
                        Text("Pull to refresh or tap Refresh to load live vehicle data.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Task { await viewModel.fetchVehicleData() }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .refreshable {
                await viewModel.fetchVehicleData()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
        }
    }

    private func percent(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value)%"
    }

    private func temperature(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f°C", value)
    }

    private func yesNo(_ value: Bool?) -> String {
        guard let value else { return "—" }
        return value ? "Yes" : "No"
    }
}
