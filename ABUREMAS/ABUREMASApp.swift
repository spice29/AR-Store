
import SwiftUI

@main
struct ABUREMASApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow)

                Text("ABUREMAS")
                    .font(.largeTitle.bold())

                Text("متجر أبو ريماس")
                    .font(.title3)

                Text("Your Private IPA Store")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("ABUREMAS")
        }
    }
}
