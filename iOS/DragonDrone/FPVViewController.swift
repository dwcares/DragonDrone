//
//  FPVViewController.swift
//  iOS-FPVDemo-Swift
//

import UIKit
import DJISDK
import VideoPreviewer
import CoreImage

class FPVViewController: UIViewController,  DJIVideoFeedListener, DJISDKManagerDelegate, DJIBaseProductDelegate, DJICameraDelegate {
    
    var isPreviewShowing = false
    var camera : DJICamera!
    
    let personToIdentifyID = "fc6ef0d7-4fa3-4d70-88ce-09cfa9b02646"
    let faceGroupID = "dragon_drone"

    let analyzeQueue =
        DispatchQueue(label: "TheRobot.DragonDrone.AnalyzeQueue")
    
    let faceDetectInterval = TimeInterval(1.00)
    var faceDetectLastUpdate = Date()
    
    var faceBoxes:[UIView] = []
    var reuseFaceBoxes:[UIView] = []
    
    @IBOutlet var analyzeButton: UIButton!
    @IBOutlet var recordModeSegmentControl: UISegmentedControl!
    @IBOutlet var fpvView: UIView!
    @IBOutlet var logLabel: UILabel!
  
    @IBOutlet var analyzePreviewImageView: UIImageView!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        VideoPreviewer.instance().setView(self.fpvView)
        DJISDKManager.registerApp(with: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        VideoPreviewer.instance().setView(nil)
        DJISDKManager.videoFeeder()?.primaryVideoFeed.remove(self)

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //
    //  Helpers
    //
    
    func fetchCamera() -> DJICamera? {
        let product = DJISDKManager.product()
        
        if (product == nil) {
            return nil
        }
        
        if (product!.isKind(of: DJIAircraft.self)) {
            return (product as! DJIAircraft).camera
        } else if (product!.isKind(of: DJIHandheld.self)) {
            return (product as! DJIHandheld).camera
        }
        
        return nil
    }
    
    func analyzeFaces() {
        
        if (camera == nil) { return }
        
        self.setDroneLEDs(setOn: false)

        VideoPreviewer.instance().snapshotPreview { (previewImage) in
        
//        let previewImage:UIImage?
//        previewImage = #imageLiteral(resourceName: "bigger")

            self.showPreview(previewImage: previewImage!)
      
            self.detectFacesCI(image: previewImage!, parentView: self.fpvView)
      
            FaceAPI.detectFaces(previewImage!) { (faces) in
                
                DispatchQueue.main.async(execute: {
                    self.logLabel.text = "faces detected: \(faces[0])"
                    
                    self.drawDetectedFaces(faces: faces, parentView: self.fpvView)
                })

                
                FaceAPI.identifyFaces(faces, personGroupId: self.faceGroupID, personToFind:self.personToIdentifyID ) { (matchedFaceIdentity) in
                    
                    DispatchQueue.main.async(execute: {
                        self.logLabel.text = "id: \(matchedFaceIdentity.faceIdentity!) confidence: \(String(format: "%.2f", matchedFaceIdentity.faceIdentityConfidence!)))"
                        
                        self.setDroneLEDs(setOn: true)
                        print("Found face identity: \(matchedFaceIdentity)")
                    })
                }
            }
        }
    }

    func detectFacesRealTime() {
        
        if (self.intervalElapsed(interval: faceDetectInterval, lastUpdate: faceDetectLastUpdate) && !isPreviewShowing) {
            self.faceDetectLastUpdate = Date()
        } else {
            return
        }
        
        VideoPreviewer.instance().snapshotPreview { (previewImage) in
            self.detectFacesCI(image: previewImage!, parentView: self.fpvView)
        }
    }
    
    func detectFacesCI(image: UIImage, parentView: UIView) -> [CIFeature]?  {
        
        guard let personciImage = CIImage(image: image) else {
            return nil
        }
        
        let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
        let faces = faceDetector?.features(in: personciImage)
        
        // For converting the Core Image Coordinates to UIView Coordinates
        let ciImageSize = personciImage.extent.size
        var transform = CGAffineTransform(scaleX: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -ciImageSize.height)
        
        clearFaceBoxes(reuseCount: faces!.count)
        
        for face in faces as! [CIFaceFeature] {
            
            print("Found bounds are \(face.bounds)")
            
            // Apply the transform to convert the coordinates
            var faceViewBounds = face.bounds.applying(transform)
            
            // Calculate the actual position and size of the rectangle in the image view
            let viewSize = view.bounds.size
            let scale = min(viewSize.width / ciImageSize.width,
                            viewSize.height / ciImageSize.height)
            let offsetX = (viewSize.width - ciImageSize.width * scale) / 2
            let offsetY = (viewSize.height - ciImageSize.height * scale) / 2
            
            faceViewBounds = faceViewBounds.applying(CGAffineTransform(scaleX: scale, y: scale))
            faceViewBounds.origin.x += offsetX
            faceViewBounds.origin.y += offsetY
            
            addFaceBoxToView(frame: faceViewBounds, view: parentView, color: UIColor.yellow.cgColor)
            
        }
        return faces

    }
    
    func drawDetectedFaces(faces: [Face], parentView: UIView) {
        clearFaceBoxes(reuseCount: faces.count)
        
        let scale = CGFloat(analyzePreviewImageView.image!.cgImage!.height) / analyzePreviewImageView.layer.frame.height
        
        print(scale)
        
        for face in faces {
            
            let faceRect = CGRect(x: CGFloat(face.left) / scale, y: CGFloat(face.top - face.height / 2) / scale, width:CGFloat(face.width) / scale, height: CGFloat(face.width) / scale)
            addFaceBoxToView(frame: faceRect, view: parentView, color: UIColor.green.cgColor)
        }
    }
    
    func addFaceBoxToView(frame:CGRect, view: UIView, color: CGColor) {
        let faceBox:UIView
        
        if (reuseFaceBoxes.count > 0) {
            faceBox = reuseFaceBoxes.first!
            reuseFaceBoxes.removeFirst()
        } else {
            faceBox = createFaceBox(frame: frame)
            view.addSubview(faceBox)
        }
        
        faceBoxes.append(faceBox)
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseInOut, animations: {
            faceBox.layer.borderColor = color
            faceBox.layer.opacity = 0.4
            faceBox.frame = frame
            
        }, completion: { (success:Bool) in
            
        })
        
    }
    
    func createFaceBox(frame: CGRect) -> UIView {
        let faceBox = UIView()
        faceBox.isHidden = false
        faceBox.layer.borderWidth = 3
        faceBox.layer.borderColor = UIColor.yellow.cgColor
        faceBox.layer.cornerRadius = 10
        faceBox.backgroundColor = UIColor.clear
        faceBox.layer.opacity = 0.0
        faceBox.layer.frame = frame
        
        return faceBox
    }
    
    func clearFaceBoxes(reuseCount:Int) {
        
        for faceBox in faceBoxes  {
            if (reuseFaceBoxes.count >= reuseCount) {
                faceBox.removeFromSuperview()
 
            } else {
                reuseFaceBoxes.append(faceBox)
            }

        }
        
        faceBoxes.removeAll()
    }
    
    func showPreview(previewImage: UIImage) {
        
        analyzePreviewImageView.image = previewImage
        
        analyzePreviewImageView.isHidden = false
        
        isPreviewShowing = true
    }
    
    func hidePreview() {
        
        analyzePreviewImageView.image = nil
        
        analyzePreviewImageView.isHidden = true
        
        isPreviewShowing = false
    }
    
    
    func intervalElapsed (interval: TimeInterval, lastUpdate: Date ) -> Bool {
        
        return (Int(Date().timeIntervalSince(lastUpdate)) >= Int(interval))
    }
    
    // 
    // Drone Helpers
    //
    func setDroneLEDs(setOn: Bool) {
        let product = DJISDKManager.product()
        
        if (product == nil) {
            return
        }
        
        if (product!.isKind(of: DJIAircraft.self)) {
            let controller = (product as! DJIAircraft).flightController
            controller!.setLEDsEnabled(setOn) { (error) in
            }
        }

    }

    
    
    //
    //  DJIBaseProductDelegate
    //
    
    func productConnected(_ product: DJIBaseProduct?) {
        
        NSLog("Product Connected")
        
        
        if (product != nil) {
            product!.delegate = self
            
            camera = self.fetchCamera()
            
            if (camera != nil) {
                camera!.delegate = self
                
    
                self.setDroneLEDs(setOn: false)
    
                
                VideoPreviewer.instance().start()
                
            }
        }
    }
    
    func productDisconnected() {
        
        NSLog("Product Disconnected")
        
        camera = nil
        
        VideoPreviewer.instance().clearVideoData()
        VideoPreviewer.instance().close()
    }
    
    
    //
    //  DJISDKManagerDelegate
    //
    
    func appRegisteredWithError(_ error: Error?) {
        
        if (error != nil) {
            NSLog("Register app failed! Please enter your app key and check the network.")
        } else {
            NSLog("Register app succeeded!")
        }
        
        DJISDKManager.startConnectionToProduct()
        DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)
        
    }
    
    //
    //  DJIVideoFeedListener
    //
    
    func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData rawData: Data) {
        
        let videoData = rawData as NSData
        let videoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: videoData.length)
        
        videoData.getBytes(videoBuffer, length: videoData.length)
        
        
        
        VideoPreviewer.instance().push(videoBuffer, length: Int32(videoData.length))
        
        detectFacesRealTime()
        
    }
    
   
    //
    //  IBAction Methods
    //    
    
    
    @IBAction func analyzeAction(_ sender: UIButton) {
        if (isPreviewShowing) {
            analyzeButton.setTitle("Analyze",  for: UIControlState.normal)
            self.logLabel.text = ""
            self.setDroneLEDs(setOn: false)
            

            hidePreview()
        } else {
            analyzeButton.setTitle("< Back", for: UIControlState.normal)
            analyzeFaces()
        }

    }
    
    @IBAction func recordModeSegmentChange(_ sender: UISegmentedControl) {
        
        if (camera != nil) {
            if (sender.selectedSegmentIndex == 0) {
                camera.setMode(DJICameraMode.shootPhoto,  withCompletion: { (error) in
                    
                })
                
            } else if (sender.selectedSegmentIndex == 1) {
                camera.setMode(DJICameraMode.recordVideo,  withCompletion: { (error) in
                    
                })
                
                
            }
        }
    }
    

}
