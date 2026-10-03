import SwiftUI

struct FileBridgeLogo: View {
    var size: CGFloat = 64

    var body: some View {
        Image("FileBridgeLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
            .accessibilityLabel("FileBridge logo")
    }
}
