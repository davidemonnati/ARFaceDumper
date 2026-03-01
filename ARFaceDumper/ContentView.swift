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
            print(faceAnchor.geometry.vertices.count)
            let pos = faceAnchor.transform.columns.3
            let distance = sqrt(
                pow(pos.x, 2) +
                pow(pos.y, 2) +
                pow(pos.z, 2)
            )
            
            print("Distanza: \(distance ) m")
            updateStatus(vertices: faceAnchor.geometry.vertices.count, distance: distance)
        }
    }
    
    func updateStatus(vertices: Int, distance: Float) {
        self.status = """
Vertices: \(vertices)
Distance: \(distance)
"""
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
