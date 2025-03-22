import SwiftUI
import AVFoundation
import UIKit

struct QRScannerView: UIViewRepresentable {
    @Binding var scannedCode: String?
    
    class QRScannerUIView: UIView {
        var captureSession: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        
        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = self.bounds
        }
    }
    
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: QRScannerView
        var scannerView: QRScannerUIView?
        
        init(_ parent: QRScannerView) {
            self.parent = parent
            super.init()
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               let stringValue = metadataObject.stringValue {
                parent.scannedCode = stringValue
            }
        }
        
        func setupCaptureSession(_ scannerView: QRScannerUIView) {
            let captureSession = AVCaptureSession()
            
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
                return
            }
            
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                return
            }
            
            let metadataOutput = AVCaptureMetadataOutput()
            
            if captureSession.canAddOutput(metadataOutput) {
                captureSession.addOutput(metadataOutput)
                
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                return
            }
            
            let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = scannerView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            scannerView.layer.addSublayer(previewLayer)
            
            scannerView.captureSession = captureSession
            scannerView.previewLayer = previewLayer
            
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIView(context: Context) -> QRScannerUIView {
        let scannerView = QRScannerUIView()
        context.coordinator.scannerView = scannerView
        context.coordinator.setupCaptureSession(scannerView)
        return scannerView
    }
    
    func updateUIView(_ uiView: QRScannerUIView, context: Context) {
        // No updates needed
    }
} 