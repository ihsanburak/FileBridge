import AppKit
import QuickLookUI
import SwiftUI

struct QuickLookPreview: NSViewRepresentable {
    let url: URL?

    func makeNSView(context: Context) -> QLPreviewView {
        QLPreviewView(frame: .zero, style: .compact)
    }

    func updateNSView(_ previewView: QLPreviewView, context: Context) {
        previewView.previewItem = url as NSURL?
    }
}
