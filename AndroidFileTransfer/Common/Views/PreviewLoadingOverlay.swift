import SwiftUI

/// Immediate feedback for the gap between "user asked to preview a file"
/// and "Quick Look panel actually has something to show" — that gap is a
/// real, unavoidable pull for anything not already cached, so this fades in
/// right away rather than leaving the screen looking unresponsive until the
/// system Quick Look panel appears.
struct PreviewLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.12)
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading Preview…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 12)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }
}
