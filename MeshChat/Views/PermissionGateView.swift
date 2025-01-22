import SwiftUI
import CoreBluetooth
import CoreLocation

struct PermissionGateView: View {
    @State private var bleAuthorized = false
    @State private var locationAuthorized = false

    let locationService: LocationService
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("MeshChat")
                .font(.largeTitle.bold())

            Text("災害時メッシュメッセージング")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 16) {
                PermissionRow(
                    icon: "bluetooth",
                    title: "Bluetooth",
                    description: "近くのデバイスとメッシュ通信するために必要です",
                    isGranted: bleAuthorized
                )

                PermissionRow(
                    icon: "location",
                    title: "位置情報",
                    description: "メッセージに位置情報を付加します",
                    isGranted: locationAuthorized
                )
            }
            .padding(.horizontal)

            Spacer()

            if !bleAuthorized || !locationAuthorized {
                Button {
                    if !locationAuthorized {
                        locationService.requestPermission()
                    }
                    startPolling()
                } label: {
                    Text("権限を許可する")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            } else {
                Button {
                    onComplete()
                } label: {
                    Text("続ける")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }

            Spacer().frame(height: 32)
        }
        .onAppear {
            checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkPermissions()
        }
    }

    private func checkPermissions() {
        bleAuthorized = CBCentralManager.authorization == .allowedAlways
        locationAuthorized = CLLocationManager.authorizationStatus() == .authorizedWhenInUse ||
                             CLLocationManager.authorizationStatus() == .authorizedAlways

        if bleAuthorized && locationAuthorized {
            onComplete()
        }
    }

    private func startPolling() {
        for delay in [0.5, 1.0, 2.0, 3.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                checkPermissions()
            }
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32)
                .foregroundStyle(isGranted ? .green : .gray)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isGranted ? .green : .gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
