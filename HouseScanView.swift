import SwiftUI
import ARKit

struct HouseScanView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Continuous LiDAR Wall Scanner").font(.title2.bold())
                Text("Walk slowly around the first floor to build a live LiDAR mesh. When enough walls are detected, mark the first floor, then keep the SAME scan session running as you go upstairs. Show saved walls below to compare placement.")
                Text("Scanning can drift between floors. The orange mesh is a visual reference only; do not use it to select an actual drill point without physical verification.")
                    .font(.callout).foregroundStyle(.orange)
                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                    NavigationLink("Start Continuous Scan") {
                        ContinuousScannerView()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("This device does not support LiDAR mesh reconstruction.")
                        .foregroundStyle(.secondary)
                }
            }.padding()
        }
        .navigationTitle("House Scanner")
    }
}
