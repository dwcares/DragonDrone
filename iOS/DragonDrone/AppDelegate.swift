//
//  AppDelegate.swift
//  DragonDrone
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        application.isIdleTimerDisabled = true
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
      
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        application.isIdleTimerDisabled = false
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        application.isIdleTimerDisabled = true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }

    func applicationWillTerminate(_ application: UIApplication) {
        
    }

}

extension CGImage {
    
    func createMatchingBackingDataWithImage( orienation: UIImageOrientation) -> CGImage? {
        var orientedImage: CGImage?
        let imageRef = self
        
        let originalWidth = imageRef.width
        let originalHeight = imageRef.height
        let bitsPerComponent = imageRef.bitsPerComponent
        let bytesPerRow = imageRef.bytesPerRow
        
        let colorSpace = imageRef.colorSpace
        let bitmapInfo = imageRef.bitmapInfo
        
        var degreesToRotate: Double
        var swapWidthHeight: Bool
        var mirrored: Bool
        switch orienation {
        case .up:
            degreesToRotate = 0.0
            swapWidthHeight = false
            mirrored = false
            break
        case .upMirrored:
            degreesToRotate = 0.0
            swapWidthHeight = false
            mirrored = true
            break
        case .right:
            degreesToRotate = 90.0
            swapWidthHeight = true
            mirrored = false
            break
        case .rightMirrored:
            degreesToRotate = 90.0
            swapWidthHeight = true
            mirrored = true
            break
        case .down:
            degreesToRotate = 180.0
            swapWidthHeight = false
            mirrored = false
            break
        case .downMirrored:
            degreesToRotate = 180.0
            swapWidthHeight = false
            mirrored = true
            break
        case .left:
            degreesToRotate = -90.0
            swapWidthHeight = true
            mirrored = false
            break
        case .leftMirrored:
            degreesToRotate = -90.0
            swapWidthHeight = true
            mirrored = true
            break
        }
        let radians = degreesToRotate * Double.pi / 180
        
        var width: Int
        var height: Int
        if swapWidthHeight {
            width = originalHeight
            height = originalWidth
        } else {
            width = originalWidth
            height = originalHeight
        }
        
        if let contextRef = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace!, bitmapInfo: bitmapInfo.rawValue) {
            
            contextRef.translateBy(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
            if mirrored {
                contextRef.scaleBy(x: -1.0, y: 1.0)
            }
            contextRef.rotate(by: CGFloat(radians))
            if swapWidthHeight {
                contextRef.translateBy(x: -CGFloat(height) / 2.0, y: -CGFloat(width) / 2.0)
            } else {
                contextRef.translateBy(x: -CGFloat(width) / 2.0, y: -CGFloat(height) / 2.0)
            }
            contextRef.draw(imageRef, in: CGRect(x: 0, y: 0, width: originalWidth, height: originalHeight))
            
            orientedImage = contextRef.makeImage()
        }
        
        return orientedImage
    }
}

