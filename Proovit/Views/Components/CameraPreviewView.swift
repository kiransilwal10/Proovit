//
//  CameraPreviewView.swift
//  Proovit
//
//  Bridges UIKit's `AVCaptureVideoPreviewLayer` into SwiftUI. SwiftUI
//  has no native camera-preview view, so we wrap a `UIView` whose
//  *backing* layer IS the preview layer (via `layerClass`) and expose
//  it through `UIViewRepresentable`.
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.previewLayer.session = session
        // resizeAspectFill = fill the bounds, cropping if needed —
        // matches what users expect from a phone camera.
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        // Session is set once at make-time. Nothing to update.
    }

    /// `UIView` subclass whose root layer IS the preview layer, so frame
    /// changes (rotation, autolayout) propagate automatically.
    final class PreviewContainerView: UIView {
        // 💡 Learn: Overriding `layerClass` tells UIKit which CALayer
        // subclass to instantiate as the view's backing layer. Done at
        // the type level, not per-instance.
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // The cast is safe by construction (we declared layerClass
            // above). Using `guard let` instead of `as!` to honor the
            // project's no-force-unwrap rule — same behavior on success,
            // explicit fatalError on the impossible-by-construction path.
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                fatalError("PreviewContainerView.layer must be AVCaptureVideoPreviewLayer")
            }
            return layer
        }
    }
}
