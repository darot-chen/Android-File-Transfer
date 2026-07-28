import SwiftUI

struct ContentView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Text("Android File Transfer")
            .font(.title)
            .padding()
            .frame(minWidth: 480, minHeight: 320)
            .task {
                await environment.bootstrapADB()
            }
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment())
}
