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
    
    var faceBoxCollection:FaceBoxCollection?

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
        faceBoxCollection = FaceBoxCollection(parentView: fpvView)

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
                                self.faceBoxCollection!.clearAll()
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
            

            self.faceBoxCollection!.clearAll(reuseCount: faces!.count)
            
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

                self.faceBoxCollection!.add(frame: faceViewBounds, withAnimation: withAnimation)
           
            }
        })
    }
    
    /// 
    /// UI Helpers
    ///
    
    func drawDetectedFaces(faces: [Face], parentView: UIView) {
        faceBoxCollection!.clearAll(reuseCount: faces.count)
        let scale = CGFloat(analyzePreviewImageView.image!.cgImage!.height) / analyzePreviewImageView.layer.frame.height
        
        
        for face in faces {
            
            let faceRect = CGRect(x: CGFloat(face.left) / scale, y: CGFloat(face.top) / scale, width:CGFloat(face.width) / scale, height: CGFloat(face.width) / scale)
            
            var tapGesture:UIGestureRecognizer? = nil
            
            if (face.faceIdentityName != nil) {
                tapGesture = UITapGestureRecognizer(target: self, action:  #selector (faceBoxAction (_:)))
                
            }
            
            faceBoxCollection!.add(frame: faceRect, face: face, gestureRecognizer: tapGesture)
            
            
        }
    }
    
    func faceBoxAction(_ sender:UITapGestureRecognizer) {
        let facebox = sender.view as! FaceBox
        let image = analyzePreviewImageView.image
        
        DispatchQueue.main.async(execute: {
            facebox.layer.backgroundColor = facebox.layer.borderColor
            facebox.startActivityIndicator()
        })
        
        FaceAPI.uploadFace(image!, personId: facebox.face!.faceIdentity!, personGroupId: FaceAPI.FaceGroupID) { (result) in
            
            DispatchQueue.main.async(execute: {
                facebox.layer.backgroundColor = UIColor.clear.cgColor
                facebox.stopActivityIndicator()
            })

            print(result)

        }
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

class FaceBoxCollection  {
    var faceBoxes:[FaceBox] = []
    var reuseFaceBoxes:[FaceBox] = []
    
    let parentView:UIView
    
    init(parentView: UIView) {
        self.parentView = parentView
    }
    
    func add(frame:CGRect, withAnimation: Bool = false, face: Face? = nil, gestureRecognizer: UIGestureRecognizer? = nil) {
        let faceBox:FaceBox
        
        if (reuseFaceBoxes.count > 0) {
            faceBox = reuseFaceBoxes.first!
            reuseFaceBoxes.removeFirst()
        } else {
            faceBox = FaceBox(frame: frame)
            parentView.addSubview(faceBox)
        }
        
        var color = UIColor.white.cgColor
        
        if (face != nil) {
            faceBox.face = face
            color = face!.faceIdentity != nil ? UIColor.red.cgColor : UIColor.yellow.cgColor
            
            if (face!.faceIdentityName != nil) {
                faceBox.addLabel(labelText: face!.faceIdentityName!)
//                faceBox.addSecondaryLabel(labelText: "\(Int(face!.faceIdentityConfidence! * 100))%")
        
            } 
            
        }
        
        if (gestureRecognizer != nil) {
            faceBox.addGestureRecognizer(gestureRecognizer!)
        }
        
        faceBoxes.append(faceBox)
        
        UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseInOut, animations: {
            faceBox.layer.borderColor = color
            faceBox.layer.opacity = 0.6
            faceBox.frame = frame
            
            
            
        }, completion: { (success:Bool) in
            if (withAnimation) {
                faceBox.startScanAnimation()
            }
        })
        
    }

  
    func clearAll(reuseCount:Int = 0) {
        
        for faceBox in faceBoxes  {
            if (reuseFaceBoxes.count >= reuseCount) {
                faceBox.layer.opacity = 0
                faceBoxes[0].layer.opacity = 0
                faceBox.removeFromSuperview()
                
            } else {
                faceBox.layer.backgroundColor = UIColor.clear.cgColor
                reuseFaceBoxes.append(faceBox)
            }
            
            for sub in faceBox.subviews {
                sub.removeFromSuperview()
            }
            
            faceBox.gestureRecognizers?.removeAll()
        }
        
        faceBoxes.removeAll()
    }
    
}

class FaceBox: UIView {
    
    var face: Face?

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isHidden = false
        self.layer.borderWidth = 3
        self.layer.borderColor = UIColor.yellow.cgColor
        self.layer.cornerRadius = 10
        self.backgroundColor = UIColor.clear
        self.layer.opacity = 0
    }
    
    convenience init(frame: CGRect, face: Face) {
        self.init(frame: frame)
        self.face = face
    }

    convenience init() {
        self.init(frame: CGRect.zero)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("This class does not support NSCoding")
    }
    
    func startActivityIndicator() {
        
        let frame = CGRect(x: self.frame.width/2, y: self.frame.height/2 , width: 30, height: 30)
        let indicator = UIActivityIndicatorView(frame: frame)
        self.addSubview(indicator)
        
        indicator.startAnimating()
        
        
        
    }
    
    func stopActivityIndicator() {
        
        for view in self.subviews {
            if view is UIActivityIndicatorView {
                let indicator = view as! UIActivityIndicatorView
                indicator.stopAnimating()
                indicator.removeFromSuperview()
            }
        }
        
    }
    
    
    func addLabel(labelText: String) {
        
        let labelFrame = CGRect(x: 0, y: self.frame.height + 5, width: 0, height: 0)
        
        let label = UILabel(frame: labelFrame)
        label.text = labelText
        label.layer.backgroundColor = UIColor.red.cgColor
        label.textColor = UIColor.white
        label.sizeToFit()
        
        self.addSubview(label)
    }
    
    func addSecondaryLabel(labelText: String) {
        
        
        let label = UILabel(frame: CGRect(x: 0, y: self.frame.height + 25, width: 0, height: 0))
        label.text = labelText
        label.layer.backgroundColor = UIColor.red.cgColor
        label.textColor = UIColor.white
        label.sizeToFit()
        
        self.addSubview(label)
    }
    
    
    func startScanAnimation() {
        
        let scanFrame = CGRect(x: 0, y: 10, width: self.frame.width, height: 2)
        let scanView = UIView(frame: scanFrame)
        scanView.layer.backgroundColor = UIColor.yellow.cgColor
        scanView.layer.opacity = 0.5
        
        let scanFrame2 = CGRect(x: 0, y: self.frame.height - 10, width: self.frame.width, height: 2)
        let scanView2 = UIView(frame: scanFrame2)
        scanView2.layer.backgroundColor = UIColor.yellow.cgColor
        scanView2.layer.opacity = 0.5
        
        self.addSubview(scanView)
        self.addSubview(scanView2)
        
        UIView.animate(withDuration: 1.0, delay: 0.0, options: .curveEaseInOut, animations: {
            
            scanView.layer.opacity = 1
            let endScanFrame = CGRect(x: 0, y: self.frame.height - 10, width: self.frame.width, height: 2)
            scanView.frame = endScanFrame
            
            scanView2.layer.opacity = 1
            let endScanFrame2 = CGRect(x: 0, y: 10, width: self.frame.width, height: 2)
            scanView2.frame = endScanFrame2
            
        }, completion: { (success:Bool) in
            
            UIView.animate(withDuration: 0.5, delay: 0.0, options: .curveEaseInOut, animations: {
                
                scanView.layer.opacity = 0
                let endScanFrame = CGRect(x: 0, y: 10, width: self.frame.width, height: 2)
                scanView.frame = endScanFrame
                
                scanView2.layer.opacity = 0
                let endScanFrame2 = CGRect(x: 0, y: self.frame.height - 10, width: self.frame.width, height: 2)
                scanView2.frame = endScanFrame2
                
                
            }, completion: { (success:Bool) in
                scanView.removeFromSuperview()
            })
            
        })
    }
}




