//
//  ViewController.swift
//  cvAruco
//
//  Created by Dan Park on 3/25/19.
//  Copyright © 2019 Dan Park. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, ARSessionObserver {

    @IBOutlet var sceneView: ARSCNView!
    var mutexlock = false;
    var shapeLayers: [CAShapeLayer] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.showsStatistics = true
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]

        sceneView.delegate = self
        sceneView.session.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        //configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true
        configuration.worldAlignment = .gravity

        // Run the view's session
        sceneView.autoenablesDefaultLighting = true;
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func updateContentNodeCache(targTransforms: Array<SKWorldTransform>, cameraTransform:SCNMatrix4) {
        
        for transform in targTransforms {
            
            let targTransform = SCNMatrix4Mult(transform.transform, cameraTransform);
            
            if let box = findCube(arucoId: Int(transform.arucoId)) {
                box.setWorldTransform(targTransform);
                
            } else {
                
                let arucoCube = ArucoNode(arucoId: Int(transform.arucoId))
                sceneView.scene.rootNode.addChildNode(arucoCube);
                arucoCube.setWorldTransform(targTransform);
            }
        }
    }
    
    func findCube(arucoId:Int) -> ArucoNode? {
        for node in sceneView.scene.rootNode.childNodes {
            if node is ArucoNode {
                let box = node as! ArucoNode
                if (arucoId == box.id) {
                    return box
                }
            }
        }
        return nil
    }
    
    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        if self.mutexlock {
            return;
        }

        self.mutexlock = true;
        let pixelBuffer = frame.capturedImage

        // 1) cv::aruco::detectMarkers
        // 2) cv::aruco::estimatePoseSingleMarkers
        // 3) transform offset and rotation of marker's corners in OpenGL coords
        // 4) return them as an array of matrixes

        let detected: [[[Float]]] = ArucoCV.detectPotentialMarkers(pixelBuffer) as! [[[Float]]];
        drawPaths(detected: detected, frame: frame)
        
        print(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer))
        let transMatrixArray:Array<SKWorldTransform> = ArucoCV.estimatePose(pixelBuffer, withIntrinsics: frame.camera.intrinsics, andMarkerSize: Float64(ArucoProperty.ArucoMarkerSize)) as! Array<SKWorldTransform>;

        
        if(transMatrixArray.count == 0) {
            self.mutexlock = false;
            return;
        }

        let cameraMatrix = SCNMatrix4.init(frame.camera.transform);
        
        DispatchQueue.main.async(execute: {
//            self.updateContentNodeCache(targTransforms: transMatrixArray, cameraTransform:cameraMatrix)
//
            self.mutexlock = false;
        })
    }
    
    func transformPoint(_ point: CGPoint, _ frame: ARFrame) -> CGPoint {
//        let normalized_x = point.x / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
//        let flipped_x = 1 - normalized_x
//        let rescaled_x = UIScreen.main.bounds.maxX * flipped_x
//
//        let normalized_y = point.y / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
//        //let flipped_y = 1 - normalized_y
//        let rescaled_y = UIScreen.main.bounds.maxY * normalized_y
        let imageBuffer = frame.capturedImage
        let imageSize = CGSize(width: CVPixelBufferGetWidth(imageBuffer), height: CVPixelBufferGetHeight(imageBuffer))
        let viewPortSize = sceneView.bounds.size
        let normalizeTransform = CGAffineTransform(scaleX: 1.0/imageSize.width, y: 1.0/imageSize.height)
//        let flipTransform = CGAffineTransform(scaleX: -1, y: -1).translatedBy(x: -1, y: -1)
        let displayTransform = frame.displayTransform(for: interfaceOrientation, viewportSize: viewPortSize)
        // 4) Convert to view size
        let toViewPortTransform = CGAffineTransform(scaleX: viewPortSize.width, y: viewPortSize.height)
        return point.applying(normalizeTransform.concatenating(displayTransform).concatenating(toViewPortTransform))
    }
    
    func drawPaths(detected: [[[Float]]], frame: ARFrame) {
//        shapeLayers.forEach { $0.removeFromSuperlayer() }
        //shapeLayers = []
        
        for i in 0..<detected.count {
            let corners = detected[i];
            // TODO: Figure out correct indices
            let topLeft = transformPoint(CGPoint(x: CGFloat(corners[0][1]), y: CGFloat(corners[0][0])), frame)
            let topRight = transformPoint(CGPoint(x: CGFloat(corners[1][1]), y: CGFloat(corners[1][0])), frame)
            let bottomLeft = transformPoint(CGPoint(x: CGFloat(corners[2][1]), y: CGFloat(corners[2][0])), frame)
            let bottomRight = transformPoint(CGPoint(x: CGFloat(corners[3][1]), y: CGFloat(corners[3][0])), frame)
            let path = UIBezierPath()
            path.move(to: topLeft)
            path.addLine(to: topRight)
            path.addLine(to: bottomLeft)
            path.addLine(to: bottomRight)
            path.addLine(to: topLeft)
            let shapeLayer = CAShapeLayer()
            shapeLayer.path = path.cgPath
            shapeLayer.strokeColor = UIColor.green.cgColor
            shapeLayer.lineWidth = 3.0
            shapeLayer.fillColor = UIColor.clear.cgColor
            print(i)
            print(shapeLayers.count)
            if (shapeLayers.count <= i) {
                print("ADD")
                shapeLayers.append(shapeLayer)
            } else {
                print("Do not add")
                shapeLayers[i].removeFromSuperlayer()
                shapeLayers[i] = shapeLayer
            }
            view.layer.addSublayer(shapeLayer)
        }
        let numToRemove = shapeLayers.count - detected.count
        for _ in 0..<numToRemove {
            shapeLayers[shapeLayers.count-1].removeFromSuperlayer()
            shapeLayers.remove(at: shapeLayers.count-1)
        }

    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//        NSLog("%s", __FUNC__)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
    }
    
    // MARK: - ARSessionObserver

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    }
    
    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
}
