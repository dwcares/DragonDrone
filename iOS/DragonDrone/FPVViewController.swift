//
//  FPVViewController.swift
//  DragonDrone
//

import UIKit
import DJISDK
import VideoPreviewer
import CoreImage
import AVFoundation

class FPVViewController: UIViewController,  DJIVideoFeedListener, DJISDKManagerDelegate, DJIBaseProductDelegate, DJICameraDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    
    var isPreviewShowing = false
    
    var camera : DJICamera!
    let analyzeQueue =
        DispatchQueue(label: "TheRobot.DragonDrone.AnalyzeQueue")
    
    var iPhonePhotoOutput: AVCapturePhotoOutput?
    var iPhoneVideoSession: AVCaptureSession?
    var iPhonePreviewLayer: AVCaptureVideoPreviewLayer?
    let iPhoneVideoSessionQueue = DispatchQueue(label: "TheRobot.DragonDrone.SessionQueue")
    
    let faceDetectInterval = TimeInterval(1.00)
    var faceDetectLastUpdate = Date()
    
    var faceBoxes:[UIView] = []
    var reuseFaceBoxes:[UIView] = []
    
    @IBOutlet var iPhoneFPVView: UIView!
    @IBOutlet var analyzeButton: UIButton!
    @IBOutlet var fpvView: UIView!
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
    
    
    ///
    /// Cloud AI Helpers
    ///
    
    func analyzeIPhoneCameraFaces() {
        
        if (iPhonePhotoOutput == nil) { return }
        
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [
            kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
            kCVPixelBufferWidthKey as String: 160,
            kCVPixelBufferHeightKey as String: 160
        ]
        settings.previewPhotoFormat = previewFormat
        
        // AVCapturePhotoCaptureDelegate capture() does analyze
        iPhonePhotoOutput!.capturePhoto(with: settings, delegate: self)
        
    }
    
    
    func analyzeDroneCameraFaces() {
        
        if (camera == nil) { return }
        
        VideoPreviewer.instance().snapshotPreview { (previewImage) in
            DispatchQueue.main.async(execute: {
                self.showPreview(previewImage: previewImage!)
           
                self.analyzeButton.setTitle("Back", for: UIControlState.normal)
           
                self.setDroneLEDs(setOn: false)
                
                self.analyzeFaces(previewImage: previewImage)
            })
            
        }
    }
    
    func analyzeFaces(previewImage: UIImage?) {
      
            self.detectFacesCI(image: previewImage!, parentView: self.fpvView, withAnimation: true)
      
            FaceAPI.detectFaces(previewImage!) { (faces) in
                
                DispatchQueue.main.async(execute: {
                    self.drawDetectedFaces(faces: faces, parentView: self.fpvView)
                })

                FaceAPI.identifyFaceWithNames(faces, personGroupId: FaceAPI.FaceGroupID) { (error, foundFaces) in
                    
                    if (foundFaces != nil) {
                        DispatchQueue.main.async(execute: {
                            self.drawDetectedFaces(faces: foundFaces!, parentView: self.fpvView)
                            
                            if (self.isIdentityFound(faces: foundFaces!)) {
                                self.setDroneLEDs(setOn: true)
                            }
                            
                            print("Found faces identity: \(foundFaces!)")
                        })
                    } else {
                        DispatchQueue.main.async(execute: {
                            
                            if (error != nil) {
                                self.clearFaceBoxes()
                                print(error!)
                            }
                        })
                    }
                }
            }
    }
    
    func isIdentityFound(faces: [Face]) -> Bool {
        var found = false
        
        for face in faces {
            found = (face.faceIdentity != nil || found)
        }
        
        return found
    }
    
    ///
    /// Local AI Helpers
    ///

    
    func detectFacesCI(image: UIImage, parentView: UIView, withAnimation: Bool = false) {

        guard let ciImage = CIImage(image: image) else {
            return
        }
        
        // For converting the Core Image Coordinates to UIView Coordinates
        let ciImageSize = ciImage.extent.size
        var transform = CGAffineTransform(scaleX: 1, y: -1)
        transform = transform.translatedBy(x: 0, y: -ciImageSize.height)
        
        detectFacesCI(ciImage: ciImage, transform: transform, parentView: parentView, withAnimation: withAnimation)
    }
    
 
    func detectFacesCI(ciImage: CIImage, transform: CGAffineTransform, parentView: UIView, withAnimation: Bool = false) {
    
        let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
        let faces = faceDetector?.features(in: ciImage)
        
        DispatchQueue.main.async(execute: {
            

            self.clearFaceBoxes(reuseCount: faces!.count)
        
            
            for face in faces as! [CIFaceFeature] {
                
                print("Found bounds are \(face.bounds)")
                
                // Apply the transform to convert the coordinates
                var faceViewBounds = face.bounds.applying(transform)
                
                // Calculate the actual position and size of the rectangle in the image view
                let viewSize = self.view.bounds.size
                let ciImageSize = ciImage.extent.size

                let scale = min(viewSize.width / ciImageSize.width,
                                viewSize.height / ciImageSize.height)
                let offsetX = (viewSize.width - ciImageSize.width * scale) / 2
                let offsetY = (viewSize.height - ciImageSize.height * scale) / 2
                
                faceViewBounds = faceViewBounds.applying(CGAffineTransform(scaleX: scale, y: scale))
                faceViewBounds.origin.x += offsetX
                faceViewBounds.origin.y += offsetY

                    self.addFaceBoxToView(frame: faceViewBounds, view: parentView, color: UIColor.white.cgColor, withAnimation: withAnimation)
           
                
            }
        })
    }
    
    /// 
    /// UI Helpers
    ///
    
    func drawDetectedFaces(faces: [Face], parentView: UIView) {
        clearFaceBoxes(reuseCount: faces.count)
        
        let scale = CGFloat(analyzePreviewImageView.image!.cgImage!.height) / analyzePreviewImageView.layer.frame.height
        
        
        for face in faces {
            
            let faceRect = CGRect(x: CGFloat(face.left) / scale, y: CGFloat(face.top) / scale, width:CGFloat(face.width) / scale, height: CGFloat(face.width) / scale)
            
            let color = face.faceIdentity != nil ? UIColor.red.cgColor : UIColor.yellow.cgColor
            
            addFaceBoxToView(frame: faceRect, view: parentView, color: color, labelText: face.faceIdentityName)
        }
    }
    
    func addFaceBoxToView(frame:CGRect, view: UIView, color: CGColor, withAnimation: Bool = false, labelText: String? = nil) {
        let faceBox:UIView
        
        if (reuseFaceBoxes.count > 0) {
            faceBox = reuseFaceBoxes.first!
            reuseFaceBoxes.removeFirst()
        } else {
            faceBox = createFaceBox(frame: frame)
            view.addSubview(faceBox)
        }
        
        if (labelText != nil) {
            addFaceBoxLabel(labelText: labelText!, faceBox: faceBox)
        }
        
        faceBoxes.append(faceBox)
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseInOut, animations: {
            faceBox.layer.borderColor = color
            faceBox.layer.opacity = 0.6
            faceBox.frame = frame
            
         
            
        }, completion: { (success:Bool) in
            if (withAnimation) {
                self.startFaceBoxScanAnimation(faceBox: faceBox)
            }
        })
        
    }
    
    func createFaceBox(frame: CGRect) -> UIView {
        let faceBox = UIView()
        faceBox.isHidden = false
        faceBox.layer.borderWidth = 3
        faceBox.layer.borderColor = UIColor.yellow.cgColor
        faceBox.layer.cornerRadius = 10
        faceBox.backgroundColor = UIColor.clear
        faceBox.layer.opacity = 0
        faceBox.layer.frame = frame
        
        return faceBox
    }
    
    func startFaceBoxScanAnimation(faceBox: UIView) {
        
        let scanFrame = CGRect(x: 0, y: 10, width: faceBox.frame.width, height: 2)
        let scanView = UIView(frame: scanFrame)
        scanView.layer.backgroundColor = UIColor.yellow.cgColor
        scanView.layer.opacity = 0.5
        
        let scanFrame2 = CGRect(x: 0, y: faceBox.frame.height - 10, width: faceBox.frame.width, height: 2)
        let scanView2 = UIView(frame: scanFrame2)
        scanView2.layer.backgroundColor = UIColor.yellow.cgColor
        scanView2.layer.opacity = 0.5
    
        faceBox.addSubview(scanView)
        faceBox.addSubview(scanView2)
        
        UIView.animate(withDuration: 1.0, delay: 0.0, options: .curveEaseInOut, animations: {
            
            scanView.layer.opacity = 1
            let endScanFrame = CGRect(x: 0, y: faceBox.frame.height - 10, width: faceBox.frame.width, height: 2)
            scanView.frame = endScanFrame
            
            scanView2.layer.opacity = 1
            let endScanFrame2 = CGRect(x: 0, y: 10, width: faceBox.frame.width, height: 2)
            scanView2.frame = endScanFrame2
            
        }, completion: { (success:Bool) in
            
            UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseInOut, animations: {
                
                scanView.layer.opacity = 0
                let endScanFrame = CGRect(x: 0, y: 10, width: faceBox.frame.width, height: 2)
                scanView.frame = endScanFrame
                
                scanView2.layer.opacity = 0
                let endScanFrame2 = CGRect(x: 0, y: faceBox.frame.height - 10, width: faceBox.frame.width, height: 2)
                scanView2.frame = endScanFrame2

                
            }, completion: { (success:Bool) in
                scanView.removeFromSuperview()
            })

        })
    }
    
    func addFaceBoxLabel(labelText: String, faceBox: UIView) {
        
        let labelFrame = CGRect(x: 0, y: faceBox.frame.height + 5, width: 0, height: 0)

        let label = UILabel(frame: labelFrame)
        label.text = labelText
        label.layer.backgroundColor = UIColor.red.cgColor
        label.textColor = UIColor.white
        label.sizeToFit()
        
        faceBox.addSubview(label)
    }
    
    func clearFaceBoxes(reuseCount:Int = 0) {
        
        for faceBox in faceBoxes  {
            if (reuseFaceBoxes.count >= reuseCount) {
                faceBox.layer.opacity = 0
                faceBoxes[0].layer.opacity = 0
                faceBox.removeFromSuperview()
 
            } else {
                reuseFaceBoxes.append(faceBox)
            }
            
            for sub in faceBox.subviews {
                sub.removeFromSuperview()
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
            
            if (controller != nil) {
                controller!.setLEDsEnabled(setOn) { (error) in
                }
            }
        }

    }
    
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
    
    //
    // iPhone Video Feed
    //
    
    func setupPhoneFPView() {
        
        iPhoneVideoSession = AVCaptureSession()
        iPhoneVideoSession!.sessionPreset = AVCaptureSessionPreset1280x720
        
        let frontCamera = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front)
        
        
        var error: NSError?
        var input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: frontCamera)
        } catch let error1 as NSError {
            error = error1
            input = nil
            print(error!.localizedDescription)
        }
        
        if error == nil && iPhoneVideoSession!.canAddInput(input) {
            iPhoneVideoSession!.addInput(input)
            
            let videoOutput = AVCaptureVideoDataOutput()
            iPhonePhotoOutput = AVCapturePhotoOutput()
            if iPhoneVideoSession!.canAddOutput(iPhonePhotoOutput) {
                iPhoneVideoSession!.addOutput(iPhonePhotoOutput)
            }
            
            if iPhoneVideoSession!.canAddOutput(videoOutput) {
                iPhoneVideoSession!.addOutput(videoOutput)
                
                
                iPhonePreviewLayer = AVCaptureVideoPreviewLayer(session: iPhoneVideoSession)
                iPhonePreviewLayer!.videoGravity = AVLayerVideoGravityResizeAspect
                iPhonePreviewLayer!.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
                iPhoneFPVView.layer.insertSublayer(iPhonePreviewLayer!, at: 0)
                
                videoOutput.setSampleBufferDelegate(self, queue: iPhoneVideoSessionQueue)
                
                iPhoneVideoSession!.startRunning()
                
                iPhonePreviewLayer!.frame = iPhoneFPVView.bounds
            }
        }
        
    }
    
    //
    // AVCapturePhotoCaptureDelegate
    //
    
    func capture(_ captureOutput: AVCapturePhotoOutput,  didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,  previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings:  AVCaptureResolvedPhotoSettings, bracketSettings:   AVCaptureBracketedStillImageSettings?, error: Error?) {
        
        if  let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage =  AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer:  sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            
            let dataProvider = CGDataProvider(data: dataImage as CFData)
            let cgImageRef: CGImage! = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
            
            let newImageRef = cgImageRef.createMatchingBackingDataWithImage(orienation: UIImageOrientation.upMirrored)
            
            let image = UIImage(cgImage: newImageRef!)
            
            DispatchQueue.main.async(execute: {
                self.showPreview(previewImage: image)
                
                self.analyzeButton.setTitle("Back", for: UIControlState.normal)
                
                self.analyzeFaces(previewImage: image)
            })
        }
    }
    
    //
    //  AVCaptureVideoDataOutputSampleBufferDelegate
    //
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        
        if (self.intervalElapsed(interval: faceDetectInterval, lastUpdate: faceDetectLastUpdate) && !isPreviewShowing) {
            self.faceDetectLastUpdate = Date()
        } else {
            return
        }
        
        if sampleBuffer != nil {
            
            let cvImage = CMSampleBufferGetImageBuffer(sampleBuffer)
            let ciImage = CIImage(cvPixelBuffer: cvImage!)
            

            var transform = CGAffineTransform(scaleX: -1, y: -1)
            transform = transform.translatedBy(x: -ciImage.extent.size.width, y: -ciImage.extent.size.height)
            
            detectFacesCI(ciImage: ciImage, transform: transform, parentView: self.fpvView)
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

        // DEBUG: Use bridge app instead of connected drone
        // DJISDKManager.enableBridgeMode(withBridgeAppIP: "192.168.2.12")

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
        
        if (self.intervalElapsed(interval: faceDetectInterval, lastUpdate: faceDetectLastUpdate) && !isPreviewShowing) {
            self.faceDetectLastUpdate = Date()
        } else {
            return
        }
        
        VideoPreviewer.instance().snapshotPreview { (previewImage) in
            
            if (previewImage != nil) {
                self.detectFacesCI(image: previewImage!, parentView: self.fpvView)
            }
        }
        
    }
    
   
    //
    //  IBAction Methods
    //    
    
    
    @IBAction func analyzeAction(_ sender: UIButton) {
      
//    //  DEBUG: Use local image instead of drone image -- use 16:9 image
//        
//        DispatchQueue.main.async(execute: {
//            self.showPreview(previewImage: #imageLiteral(resourceName: "smaller"))
//            self.analyzeFaces(previewImage: #imageLiteral(resourceName: "smaller"))
//        })
//        return

        if (isPreviewShowing) {
            
            DispatchQueue.main.async(execute: {
                self.setDroneLEDs(setOn: false)
                self.hidePreview()
                self.analyzeButton.setTitle("Analyze", for: UIControlState.normal)
            })
        } else if (camera != nil) {
            
            analyzeDroneCameraFaces()
            
        } else if (iPhoneVideoSession == nil) {
             setupPhoneFPView()
        } else {
        
            analyzeIPhoneCameraFaces()
            
        }

    }
    
}




