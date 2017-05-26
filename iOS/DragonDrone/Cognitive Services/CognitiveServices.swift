//  CognitiveServices.swift


import Foundation

class CognitiveServices: NSObject {
    static let sharedInstance = CognitiveServices()
    
    // Note: Set Cognitive Services Keys in Info.plist
    static var ComputerVisionKey = ""
    static var EmotionKey = ""
    static var FaceKey = ""
    static var ServiceURL = ""

    let analyzeImage = AnalyzeImage()
    
    override init() {
        
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"), let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {

            CognitiveServices.ComputerVisionKey = dict["Microsoft Cognitive Services"]?["ComputerVisionKey"] as! String
            
            CognitiveServices.EmotionKey = dict["Microsoft Cognitive Services"]?["EmotionKey"] as! String
            
            CognitiveServices.FaceKey = dict["Microsoft Cognitive Services"]?["FaceKey"] as! String
            
            CognitiveServices.ServiceURL = dict["Microsoft Cognitive Services"]?["ServiceURL"] as! String

        }
    }
    
}
