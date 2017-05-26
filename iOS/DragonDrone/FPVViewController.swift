//
//  FPVViewController.swift
//  iOS-FPVDemo-Swift
//

import UIKit
import DJISDK
import VideoPreviewer
import CoreImage

class FPVViewController: UIViewController,  DJIVideoFeedListener, DJISDKManagerDelegate, DJIBaseProductDelegate, DJICameraDelegate, AnalyzeImageDelegate {
    
    var isRecording : Bool!
    var isAnalyzing = false
    var camera : DJICamera!
    
    let analyzeQueue =
        DispatchQueue(label: "TheRobot.DragonDrone.AnalyzeQueue")
    
    let analyzeImage = CognitiveServices.sharedInstance.analyzeImage
    let analyzeInterval = TimeInterval(3.00)
    var analyzeLastUpdate = Date()
    let faceDetectInterval = TimeInterval(1.00)
    var faceDetectLastUpdate = Date()
    
    @IBOutlet var analyzeButton: UIButton!
    
    @IBOutlet var recordTimeLabel: UILabel!
    
    @IBOutlet var captureButton: UIButton!
    
    @IBOutlet var recordButton: UIButton!
    
    @IBOutlet var recordModeSegmentControl: UISegmentedControl!
    
    @IBOutlet var fpvView: UIView!
    
    @IBOutlet var logLabel: UILabel!
    
    @IBOutlet var faceBoxView: UIView!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        analyzeImage.delegate = self
        VideoPreviewer.instance().setView(self.fpvView)
        DJISDKManager.registerApp(with: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        analyzeImage.delegate = nil
        VideoPreviewer.instance().setView(nil)
        DJISDKManager.videoFeeder()?.primaryVideoFeed.remove(self)

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        recordTimeLabel.isHidden = true
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
    
    func formatSeconds(seconds: UInt) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm:ss"
        
        return(dateFormatter.string(from: date))
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
    
    func analyze() {
        
        if (self.intervalElapsed(interval: faceDetectInterval, lastUpdate: faceDetectLastUpdate) && isAnalyzing ) {
            self.faceDetectLastUpdate = Date()
        } else {
            return
        }
        
        VideoPreviewer.instance().snapshotPreview { (previewImage) in
            
            self.detectFaces(image: previewImage!, view: self.fpvView, faceBox: self.faceBoxView)
            
            let visualFeatures: [AnalyzeImage.AnalyzeImageVisualFeatures] = [.Categories, .Description, .Faces, .ImageType, .Color, .Adult]
            let requestObject: AnalyzeImageRequestObject = (previewImage!, visualFeatures)
            
            if (self.intervalElapsed(interval: self.analyzeInterval, lastUpdate: self.analyzeLastUpdate) && self.isAnalyzing ) {
                self.analyzeLastUpdate = Date()
            
                self.analyzeQueue.async {
                
                    try! self.analyzeImage.analyzeImageWithRequestObject(requestObject, completion: { (response) in
                        
                        DispatchQueue.main.async(execute: {
                            self.logLabel.text = response?.descriptionText
                        })
                        
                    })
                    
                }
            }
            
        }
        
    }
    
    func detectFaces(image: UIImage, view:UIView, faceBox:UIView) {
        
        guard let personciImage = CIImage(image: image) else {
            return
        }
        
        let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
        let faces = faceDetector?.features(in: personciImage)
        
        // For converting the Core Image Coordinates to UIView Coordinates
        let ciImageSize = personciImage.extent.size
        var transform = CGAffineTransform(scaleX: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -ciImageSize.height)
        
        if (faces!.count > 0) {
            faceBox.isHidden = false
        } else {
            faceBox.isHidden = true
            faceBox.layer.borderWidth = 3
            faceBox.layer.borderColor = UIColor.yellow.cgColor
            faceBox.layer.cornerRadius = 10
            faceBox.backgroundColor = UIColor.clear
            faceBox.layer.opacity = 0.4
        }
        
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
            
            UIView.animate(withDuration: 0.3, delay: 0.0, options: .curveEaseInOut, animations: {
                
                faceBox.frame = faceViewBounds

            }, completion: { (success:Bool) in
                
            })
     
            
         
//            
//            if face.hasLeftEyePosition {
//                print("Left eye bounds are \(face.leftEyePosition)")
//            }
//            
//            if face.hasRightEyePosition {
//                print("Right eye bounds are \(face.rightEyePosition)")
//            }
        }
    }
    
    func intervalElapsed (interval: TimeInterval, lastUpdate: Date ) -> Bool {
    
        return (Int(Date().timeIntervalSince(lastUpdate)) >= Int(interval))
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
    //  DJICameraDelegate
    //
    
    func camera(_ camera: DJICamera, didUpdate cameraState: DJICameraSystemState) {
        self.isRecording = cameraState.isRecording
        self.recordTimeLabel.isHidden = !self.isRecording
        
        self.recordTimeLabel.text = formatSeconds(seconds: cameraState.currentVideoRecordingTimeInSeconds)
        
        if (self.isRecording == true) {
            self.recordButton.setTitle("Stop Record", for: UIControlState.normal)
        } else {
            self.recordButton.setTitle("Start Record", for: UIControlState.normal)
        }
        
        if (cameraState.mode == DJICameraMode.shootPhoto) {
            self.recordModeSegmentControl.selectedSegmentIndex = 0
        } else {
            self.recordModeSegmentControl.selectedSegmentIndex = 1
        }
        
    }
    
    //
    //  DJIVideoFeedListener
    //
    
    func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData rawData: Data) {
        
        let videoData = rawData as NSData
        let videoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: videoData.length)
        
        videoData.getBytes(videoBuffer, length: videoData.length)
        
        
        
        VideoPreviewer.instance().push(videoBuffer, length: Int32(videoData.length))
        
        analyze()
    }
    
    //
    //  IBAction Methods
    //    
    
    
    @IBAction func captureAction(_ sender: UIButton) {
       
        if (camera != nil) {
            camera.setMode(DJICameraMode.shootPhoto, withCompletion: { (error) in
                
                if (error != nil) {
                    NSLog("Set Photo Mode Error: " + String(describing: error))
                }
            
                self.camera.startShootPhoto(completion: { (error) in
                    if (error != nil) {
                        NSLog("Shoot Photo Mode Error: " + String(describing: error))
                    }
                })
            })
        }
    }
    
    @IBAction func recordAction(_ sender: UIButton) {
        
        if (camera != nil) {
            if (self.isRecording) {
                camera.stopRecordVideo(completion: { (error) in
                    if (error != nil) {
                        NSLog("Stop Record Video Error: " + String(describing: error))
                    }
                })
            } else {
                camera.setMode(DJICameraMode.recordVideo,  withCompletion: { (error) in
                    
                    self.camera.startRecordVideo(completion: { (error) in
                        if (error != nil) {
                            NSLog("Stop Record Video Error: " + String(describing: error))
                        }
                    })
                })
            }
        }
    }
    
    @IBAction func analyzeAction(_ sender: UIButton) {
        isAnalyzing = !isAnalyzing
        
        if (self.isAnalyzing == true) {
            self.analyzeButton.setTitle("Stop Analyzing", for: UIControlState.normal)
            self.logLabel.isHidden = false
        } else {
            self.analyzeButton.setTitle("Analyze", for: UIControlState.normal)
            self.logLabel.text = ""
            self.logLabel.isHidden = true

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
    
    
    // MARK: - AnalyzeImageDelegate
    
    func finishedGeneratingObject(_ analyzeImageObject: AnalyzeImage.AnalyzeImageObject) {
        
        // Here you could do more with this object. It for instance contains the recognized emotions that weren't available before.
        print(analyzeImageObject)
        
//        DispatchQueue.main.async(execute: {
//            
//            if ((analyzeImageObject.faces?.count)! > 0) {
//                self.logLabel.text = analyzeImageObject.faces?[0].emotion
//            }
//        })
        
    }


}
