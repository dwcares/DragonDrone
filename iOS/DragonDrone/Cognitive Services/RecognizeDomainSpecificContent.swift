//  RecognizeDomainSpecificContent.swift
//


import UIKit

class RecognizeDomainSpecificContent: NSObject {

    /// The url to perform the requests on
    
    let url = CognitiveServices.ServiceURL + "/vision/v1.0/models/{model}/analyze"
    
    /// Your private API key. If you havn't changed it yet, go ahead!
    let key = CognitiveServices.ComputerVisionKey
    
    override init() {
        print(url)

    }
}
