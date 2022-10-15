//
//  Decoder.swift
//  cvAruco
//
//  Created by Gabriel Alvarez on 15/10/2022.
//  Copyright © 2022 Dan Park. All rights reserved.
//

import Foundation
import ARKit
import UIKit

public enum BlockFace: String, CaseIterable {
    case red = "red"
    case blue = "blue"
    case green = "green"
    case yellow = "yellow"
    case white = "white"
    case black = "black"
    case unknown = "unknown"
}

public class Decoder {
    let frame: ARFrame
    let viewPortSize: CGSize
    
    public init(frame: ARFrame, viewPortSize: CGSize) {
        self.frame = frame
        self.viewPortSize = viewPortSize
    }
    
    public func decode(detectedCorners corners: [[[Float]]]) -> [CALayer] {
        var shapeLayers: [CALayer] = []
        for rawCornerArray in corners {
            let cornerArray = convertCornerArray(rawCornerArray)
            shapeLayers.append(decodeAndVisualize(cornerArray: cornerArray))
        }
        return shapeLayers
    }
    
    private func decodeAndVisualize(cornerArray: [CGPoint]) -> CALayer {
        let blockFace, cubeNumber, pointsToDraw = decodeOne(cornerArray: cornerArray)
        
        return visualizeDetected(cornerArray: cornerArray, blockFace: blockFace, cubeNumber: cubeNumber, pointsToDraw: pointsToDraw)
    }
    
    private func transformPoint(_ point: CGPoint) -> CGPoint {
        let imageBuffer = frame.capturedImage
        let imageSize = CGSize(width: CVPixelBufferGetWidth(imageBuffer), height: CVPixelBufferGetHeight(imageBuffer))
        let normalizeTransform = CGAffineTransform(scaleX: 1.0/imageSize.width, y: 1.0/imageSize.height)
        let displayTransform = frame.displayTransform(for: UIApplication.shared.statusBarOrientation, viewportSize: viewPortSize)
        let toViewPortTransform = CGAffineTransform(scaleX: viewPortSize.width, y: viewPortSize.height)
        return point.applying(normalizeTransform.concatenating(displayTransform).concatenating(toViewPortTransform))
    }
    
    private func convertCornerArray(_ rawCornerArray: [[Float]]) -> [CGPoint] {
        let topLeft = CGPoint(x: CGFloat(rawCornerArray[0][1]), y: CGFloat(rawCornerArray[0][0]))
        let topRight = CGPoint(x: CGFloat(rawCornerArray[1][1]), y: CGFloat(rawCornerArray[1][0]))
        let bottomLeft = CGPoint(x: CGFloat(rawCornerArray[2][1]), y: CGFloat(rawCornerArray[2][0]))
        let bottomRight = CGPoint(x: CGFloat(rawCornerArray[3][1]), y: CGFloat(rawCornerArray[3][0]))
        return [topLeft, topRight, bottomLeft, bottomRight]
    }

    private func visualizeDetected(cornerArray: [CGPoint], blockFace: BlockFace, cubeNumber: Int, pointsToDraw: [CGPoint]) -> CALayer {
        let outerLayer = CALayer()
        let topLeft = transformPoint(cornerArray[0])
        let topRight = transformPoint(cornerArray[1])
        let bottomLeft = transformPoint(cornerArray[2])
        let bottomRight = transformPoint(cornerArray[3])
        let path = UIBezierPath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomLeft)
        path.addLine(to: bottomRight)
        path.addLine(to: topLeft)
        let shapeLayer = CAShapeLayer()
        // Draw boundary
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.green.cgColor
        shapeLayer.lineWidth = 3.0
        shapeLayer.fillColor = UIColor.clear.cgColor
        outerLayer.addSublayer(shapeLayer)
        
        // Draw tracked points as small circles
        for pointToDraw in pointsToDraw {
            let circleLayer = CAShapeLayer()
            circleLayer.path = UIBezierPath(ovalIn: CGRect(x: pointToDraw.x - 2, y: pointToDraw.y - 2, width: 4, height: 4)).cgPath
            circleLayer.fillColor = UIColor.red.cgColor
            outerLayer.addSublayer(circleLayer)
        }
        
        // Draw text label
        let detectedText = blockFace.rawValue + " " + String(cubeNumber)
        let textLayer = CATextLayer()
        textLayer.fontSize = 10
        textLayer.position = topRight
        textLayer.string = detectedText
        textLayer.foregroundColor = UIColor.green.cgColor
        outerLayer.addSublayer(textLayer)
        
        return outerLayer
    }
}
