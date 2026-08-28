//
//  ContentView.swift
//  ARFaceDumper
//
//  Created by Davide Monnati on 01/03/26.
//

import SwiftUI
import ARKit
import RealityKit
import Combine

// MARK: - Main SwiftUI View

struct ContentView: View {
    @StateObject private var arSceneView = ARSceneView()
    
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            ARFaceSceneView(arSceneView: arSceneView)
                .edgesIgnoringSafeArea(.all)
                .padding(.bottom, 20)
            
            VStack(spacing: 20) {
                Spacer()
                
                Text(arSceneView.status)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width:  lastOffset.width  + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                
                if let feedback = arSceneView.captureFeedback {
                    Text(feedback.message)
                        .font(.system(.footnote, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(feedback.isError ? Color.red.opacity(0.85) : Color.green.opacity(0.85))
                        .clipShape(Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.25), value: arSceneView.captureFeedback)
                        .padding(.bottom, 10)
                }
                
                Spacer()
            
                ZStack {
                    Rectangle()
                        .fill(.black)
                        .frame(height: 140)
                        .edgesIgnoringSafeArea(.bottom)
                    
                    Spacer()
                    
                    VStack(spacing: 0) {
                        Button(action: {
                            arSceneView.captureDepthImage()
                        }) {
                            ZStack {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 3)
                                    .frame(width: 72, height: 72)
                                
                                Circle()
                                    .fill(.white)
                                    .frame(width: 60, height: 60)
                            }
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 20)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct ARFaceSceneView: UIViewRepresentable {
    let arSceneView: ARSceneView
    
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        let config = ARFaceTrackingConfiguration()
        
        config.isWorldTrackingEnabled = false
        view.session.delegate = arSceneView
        view.session.run(config)
        
        arSceneView.arView = view
        
        return view
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

enum CaptureFeedback: Equatable {
    case success
    case noDepthData
    case saveError(String)
    
    var message: String {
        switch self {
        case .success: return "✅ Image saved"
        case .noDepthData: return "⚠️ No depth data yet, try again"
        case .saveError(let reason): return "❌ Save failed: \(reason)"
        }
    }
    
    var isError: Bool {
        if case .success = self { return false }
        return true
    }
}

class ARSceneView: NSObject, ObservableObject, ARSessionDelegate {
    @Published var status: String = "Waiting for the face..."
    @Published var captureFeedback: CaptureFeedback?
    
    private var frameCount = 0
    var arView: ARView?
    private var lastFaceAnchor: ARFaceAnchor?
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let faceAnchor = anchor as? ARFaceAnchor else {
                continue
            }
            self.lastFaceAnchor = faceAnchor
            self.getParameters(faceAnchor: faceAnchor)
        }
    }
    
    func getParameters(faceAnchor: ARFaceAnchor) {
        frameCount += 1;
        
        if frameCount % 20 == 0 {
            let pos = faceAnchor.transform.columns.3
            let distance = sqrt(
                pow(pos.x, 2) +
                pow(pos.y, 2) +
                pow(pos.z, 2)
            )
            
            let blendShapes = faceAnchor.blendShapes
            
            updateStatus(vertices: faceAnchor.geometry.vertices.count, distance: distance, blendShapes: blendShapes)
        }
    }
    
    func updateStatus(vertices: Int, distance: Float, blendShapes: [ARFaceAnchor.BlendShapeLocation : NSNumber]) {
        let mouth = blendShapes[.jawOpen]?.floatValue ?? 0
        let eyeBlinkL = blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
        let eyeBlinkR = blendShapes[.eyeBlinkRight]?.floatValue ?? 0
        let tongue = (blendShapes[.tongueOut]?.floatValue ?? 0)
        let smile = ((blendShapes[.mouthSmileLeft]?.floatValue ?? 0) + (blendShapes[.mouthSmileRight]?.floatValue ?? 0)) / 2
        self.status = """
Vertices: \(vertices)
Distance: \(distance)
Mouth: \(mouth>0.2 ? "OPEN" : "CLOSED") (\(String(format: "%.2f", mouth)))
Eyes L: \(eyeBlinkL>0.3 ? "CLOSED" : "OPEN") \(String(format: "%.2f", eyeBlinkL)) 
Eyes R: \(eyeBlinkR>0.3 ? "CLOSED" : "OPEN") \(String(format: "%.2f", eyeBlinkR))
Smile: \(String(format: "%.0f%%", smile * 100))
Tongue: \(tongue > 0.5 ? "OUT" : "IN")
"""
    }
    
    /// Tries to capture depth data, retrying across a few frames since
    /// capturedDepthData isn't guaranteed to be present on every single frame.
    func captureDepthImage(attemptsLeft: Int = 10) {
        guard let frame = arView?.session.currentFrame else {
            return
        }
        
        guard let depthData = frame.capturedDepthData else {
            if attemptsLeft > 0 {
                // Wait for the next frame (~1/60s) and try again.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0) { [weak self] in
                    self?.captureDepthImage(attemptsLeft: attemptsLeft - 1)
                }
            } else {
                print("Depth data not captured after several attempts")
                showFeedback(.noDepthData)
            }
            return
        }
        
        let depthMap = depthData.depthDataMap
        
        saveDepthImage(depthMap: depthMap)
        
        if let faceAnchor = lastFaceAnchor {
            saveFaceOBJ(faceAnchor: faceAnchor)
        }
    }
    
    func saveDepthImage(depthMap: CVPixelBuffer) {
        let ciImage = CIImage(cvPixelBuffer: depthMap)
        let context = CIContext()
        
        // Normalize depth for visualization (depth is in meters as Float32)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        print(uiImage)
        
        UIImageWriteToSavedPhotosAlbum(uiImage, self, #selector(imageSaved(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeMutableRawPointer) {
        if let error = error {
            print("Save error: \(error.localizedDescription)")
            showFeedback(.saveError(error.localizedDescription))
        } else {
            print("Depth image saved!")
            showFeedback(.success)
        }
    }
    
    /// Shows a transient feedback message, auto-dismissed after a couple of seconds.
    private func showFeedback(_ feedback: CaptureFeedback) {
        DispatchQueue.main.async {
            self.captureFeedback = feedback
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.captureFeedback == feedback {
                    self.captureFeedback = nil
                }
            }
        }
    }
    
    func exportFaceAnchorToOBJ(faceAnchor: ARFaceAnchor) -> String {
        let geometry = faceAnchor.geometry
        
        var objContent = "# ARFaceAnchor OBJ Export\n"
        objContent += "o Face\n\n"
        
        // vertices
        for vertex in geometry.vertices {
            objContent += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
        }
        objContent += "\n"
        
        // uv coordinates
        for uv in geometry.textureCoordinates {
            objContent += "vt \(uv.x) \(uv.y)\n"
        }
        objContent += "\n"
        
        // faces (triangles)
        let indices = geometry.triangleIndices
        let triangleCount = geometry.triangleCount
        
        for i in 0..<triangleCount {
            let i0 = Int(indices[i * 3 + 0]) + 1
            let i1 = Int(indices[i * 3 + 1]) + 1
            let i2 = Int(indices[i * 3 + 2]) + 1
            // formato: f vertice/uv vertice/uv vertice/uv
            objContent += "f \(i0)/\(i0) \(i1)/\(i1) \(i2)/\(i2)\n"
        }
        
        return objContent
    }
    
    func saveFaceOBJ(faceAnchor: ARFaceAnchor) {
        let objString = exportFaceAnchorToOBJ(faceAnchor: faceAnchor)
        
        let fileName = "face_mesh.obj"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        do {
            try objString.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch { }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
