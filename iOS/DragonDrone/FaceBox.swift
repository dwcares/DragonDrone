//
//  FaceBox.swift
//
//  FaceBox: UI Control for rendering annotated boxes around faces
//  FaceBoxCollection: A custom dynamic collection to add face boxes to a view with reuse and animation
//

import UIKit


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
                
                if (face!.faceIdentityConfidence! < 0.6) {
                    faceBox.addSecondaryLabel(labelText: "\(Int(face!.faceIdentityConfidence! * 100))%")
                }
                
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
    
    let indicatorTag = 400
    let indicatorLabelTag = 401
    
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
    
    func startActivityIndicator(text: String? = nil) {
        
        DispatchQueue.main.async(execute: {
            self.layer.backgroundColor = self.layer.borderColor
            
            
            let frame = CGRect(x: self.frame.width/2 - 20, y: self.frame.height/2 - 20, width: 40, height: 40)
            let indicator = UIActivityIndicatorView(frame: frame)
            indicator.layer.borderColor = UIColor.white.cgColor
            indicator.tag = self.indicatorTag
            
            self.addSubview(indicator)
            
            if (text != nil) {
                
                
                let indicatorLabel = UILabel()
                indicatorLabel.text = text!
                indicatorLabel.textColor = UIColor.white
                indicatorLabel.sizeToFit()
                
                indicatorLabel.frame =  CGRect(x: self.frame.width/2 - indicatorLabel.frame.width/2, y: self.frame.height/2 + 20, width: indicatorLabel.frame.width, height: indicatorLabel.frame.height)
                
                indicatorLabel.tag = self.indicatorLabelTag
                
                if (indicatorLabel.frame.width - 8 < self.frame.width) {
                    self.addSubview(indicatorLabel)
                }
            }
            indicator.startAnimating()
        })
    }
    
    func updateActivityIndicatorLabel(text: String) {
        
        DispatchQueue.main.async(execute: {
            let indicatorLabel = self.viewWithTag(self.indicatorLabelTag) as? UILabel
            if indicatorLabel != nil {
                indicatorLabel!.text = text
                indicatorLabel!.sizeToFit()
                indicatorLabel!.frame = CGRect(x: self.frame.width/2 - indicatorLabel!.frame.width/2, y: self.frame.height/2 + 20, width: indicatorLabel!.frame.width, height: indicatorLabel!.frame.height)
                
                if (indicatorLabel!.frame.width - 8 < self.frame.width) {
                    indicatorLabel!.isHidden = false
                } else {
                    indicatorLabel!.isHidden = true
                }
            }
            
            
            
        })
        
    }
    
    func stopActivityIndicator() {
        
        DispatchQueue.main.async(execute: {
            let indicator = self.viewWithTag(self.indicatorTag) as? UIActivityIndicatorView
            let indicatorLabel = self.viewWithTag(self.indicatorLabelTag) as? UILabel
            
            UIView.animate(withDuration: 0.7, delay: 0.5, options: .curveEaseInOut, animations: {
                self.layer.backgroundColor = UIColor.clear.cgColor
                indicator?.layer.opacity = 0
                indicatorLabel?.layer.opacity = 0
                
            }, completion: {(result) in
                indicator?.stopAnimating()
                indicator?.removeFromSuperview()
                
                indicatorLabel?.removeFromSuperview()
            })
        })
        
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

