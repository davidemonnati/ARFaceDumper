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
    
    var body: some View {
        ZStack {
            ARFaceSceneView(arSceneView: arSceneView)
                .edgesIgnoringSafeArea(.all)
                .padding(.bottom, 20)
            
            VStack(spacing: 20) {
                Spacer()
                
                Text(arSceneView.status)
                    .font(.system(.caption, design: .monospaced))
            }
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
        
        return view
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

class ARSceneView: NSObject, ObservableObject, ARSessionDelegate {
    @Published var status: String = "Waiting for the face..."
    
    private var frameCount = 0;
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let faceAnchor = anchor as? ARFaceAnchor else {
                continue
            }
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
}

// MARK: - Preview

#Preview {
    ContentView()
}
