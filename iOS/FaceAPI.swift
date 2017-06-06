/*
 * Copyright (c) Microsoft. All rights reserved. Licensed under the MIT license.
 * See LICENSE in the project root for license information.
 */

import UIKit

enum FaceAPIResult<T, FaceError: Error> {
    case success(T)
    case failure(FaceError)
}

struct Face {
    let faceId: String
    let height: Int
    let width: Int
    let top: Int
    let left: Int
    var faceIdentity: String?
    var faceIdentityConfidence: Float?
}

class FaceAPI: NSObject {
    
    // Note: Set Cognitive Services Keys in Info.plist
    static let FaceKey = FaceAPI.getFaceKey()
    static let FaceGroupID = FaceAPI.getGroupID()
    static let ServiceURL = FaceAPI.getServiceURL()

    // Create person group
    static func createPersonGroup(_ personGroupId: String, name: String, userData: String?, completion: @escaping (_ result: FaceAPIResult<JSON, FaceError>) -> Void) {
        
        let url = "\(FaceAPI.ServiceURL)/face/v1.0/persongroups/"
        let urlWithParams = url + personGroupId
        
        let request = NSMutableURLRequest(url: URL(string: urlWithParams)!)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(FaceAPI.FaceKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        var json: [String: AnyObject] = ["name": name as AnyObject]
        
        if let userData = userData {
            json["userData"] = userData as AnyObject
        }
        
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
    
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) in
            
            if let nsError = error {
                completion(.failure(FaceError.unexpectedError(nsError: nsError as NSError)))
            }
            else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode

                if (statusCode == 200 || statusCode == 409) {
                    completion(.success([] as JSON))
                }

                else {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data!, options:.allowFragments) as! JSONDictionary
                        completion(.failure(FaceError.serviceError(json: json)))
                    }
                    catch {
                        completion(.failure(FaceError.jSonSerializationError))
                    }
                }
            }
        }) 
        task.resume()
    }
    
    
    // Create person
    static func createPerson(_ personName: String, userData: String?, personGroupId: String, completion: @escaping (_ result: FaceAPIResult<JSON, FaceError>) -> Void) {
        
        let url = "\(FaceAPI.ServiceURL)/face/v1.0/persongroups/\(personGroupId)/persons"
        let request = NSMutableURLRequest(url: URL(string: url)!)
        
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(FaceAPI.FaceKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        var json: [String: AnyObject] = ["name": personName as AnyObject]
        if let userData = userData {
            json["userData"] = userData as AnyObject
        }
        
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) in
            
            if let nsError = error {
                completion(.failure(FaceError.unexpectedError(nsError: nsError as NSError)))
            }
            else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options:.allowFragments)
                    if statusCode == 200 {
                        completion(.success(json as JSON))
                    }
                }
                catch {
                    completion(.failure(FaceError.jSonSerializationError))
                }
            }
        }) 
        task.resume()
    }

    
    // Upload face
    static func uploadFace(_ faceImage: UIImage, personId: String, personGroupId: String, completion: @escaping (_ result: FaceAPIResult<JSON, FaceError>) -> Void) {
        
        let url = "\(FaceAPI.ServiceURL)/face/v1.0/persongroups/\(personGroupId)/persons/\(personId)/persistedFaces"
        let request = NSMutableURLRequest(url: URL(string: url)!)
        
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(FaceAPI.FaceKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        let pngRepresentation = UIImagePNGRepresentation(faceImage)
        
        let task = URLSession.shared.uploadTask(with: request as URLRequest, from: pngRepresentation, completionHandler: { (data, response, error) in
            
            if let nsError = error {
                completion(.failure(FaceError.unexpectedError(nsError: nsError as NSError)))
            }
            else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options:.allowFragments) as JSON
                    if statusCode == 200 {
                        completion(.success(json))
                    }
                }
                catch {
                    completion(.failure(FaceError.jSonSerializationError))
                }
            }
        }) 
        task.resume()
    }
    
    
    // Post training
    static func trainPersonGroup(_ personGroupId: String, completion: @escaping (_ result: FaceAPIResult<JSON, FaceError>) -> Void) {
        
        let url = "\(FaceAPI.ServiceURL)/face/v1.0/persongroups/\(personGroupId)/train"
        let request = NSMutableURLRequest(url: URL(string: url)!)
        
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(FaceAPI.FaceKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) in
            
            if let nsError = error {
                completion(.failure(FaceError.unexpectedError(nsError: nsError as NSError)))
            }
            else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode
                
                do {
                    if statusCode == 202 {
                        completion(.success([] as JSON))
                    }
                    else {
                        let json = try JSONSerialization.jsonObject(with: data!, options:.allowFragments) as! JSONDictionary
                        completion(.failure(FaceError.serviceError(json: json)))
                    }
                }
                catch {
                    completion(.failure(FaceError.jSonSerializationError))
                }
            }
        }) 
        task.resume()
    }

    
    // Get training status
    static func getTrainingStatus(_ personGroupId: String, completion: @escaping (_ result: FaceAPIResult<JSON, FaceError>) -> Void) {
        
        let url = "\(FaceAPI.ServiceURL)/face/v1.0/persongroups/\(personGroupId)/training"
        let request = NSMutableURLRequest(url: URL(string: url)!)
        
        request.httpMethod = "GET"
        request.setValue(FaceAPI.FaceKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) in
            
            if let nsError = error {
                completion(.failure(FaceError.unexpectedError(nsError: nsError as NSError)))
            }
            else {
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options:.allowFragments)
                    completion(.success(json as JSON))
                }
                catch {
                    completion(.failure(FaceError.jSonSerializationError))
                }
            }
        }) 
        task.resume()
    }
    
    
    // Detect faces
    static func detect(_ facesPhoto: UIImage, completion: @escaping (_ result: FaceAPIResult<JSON, FaceError>) -> Void) {
        
        let url = "\(FaceAPI.ServiceURL)/face/v1.0/detect?returnFaceId=true&returnFaceLandmarks=false&returnFaceAttributes=age,gender"
        let request = NSMutableURLRequest(url: URL(string: url)!)
        
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(FaceAPI.FaceKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        let pngRepresentation = UIImagePNGRepresentation(facesPhoto)
        
        let task = URLSession.shared.uploadTask(with: request as URLRequest, from: pngRepresentation, completionHandler: { (data, response, error) in
            
            if let nsError = error {
                completion(.failure(FaceError.unexpectedError(nsError: nsError as NSError)))
            }
            else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options:.allowFragments) as JSON
                    if statusCode == 200 {
                        completion(.success(json))
                    }
                    else {
                        completion(.failure(FaceError.serviceError(json: json as! [String : AnyObject])))
                    }
                }
                catch {
                    completion(.failure(FaceError.jSonSerializationError))
                }
            }
        }) 
        task.resume()
    }
    
    
    // Identify faces in people group
    static func identify(faces faceIds: [String], personGroupId: String, completion: @escaping (_ result: FaceAPIResult<JSON, FaceError>) -> Void) {

        let url = "\(FaceAPI.ServiceURL)/face/v1.0/identify"
        let request = NSMutableURLRequest(url: URL(string: url)!)
        
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(FaceAPI.FaceKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        
        
        let json: [String: AnyObject] = ["personGroupId": personGroupId as AnyObject,
                                         "maxNumOfCandidatesReturned": 1 as AnyObject,
                                         "confidenceThreshold": 0.7 as AnyObject,
                                         "faceIds": faceIds as AnyObject
        ]
        
        let jsonData = try! JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { (data, response, error) in
            
            if let nsError = error {
                completion(.failure(FaceError.unexpectedError(nsError: nsError as NSError)))
            }
            else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode

                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options:.allowFragments)
                    if statusCode == 200 {
                        completion(.success(json as JSON))
                    }
                    else {
                        completion(.failure(FaceError.serviceError(json: json as! JSONDictionary)))
                    }
                }
                catch {
                    completion(.failure(FaceError.jSonSerializationError))
                }
            }
        }) 
        task.resume()
    }
    
    //
    // Face API Helpers
    //
    
    static func detectFaces(_ photo: UIImage, completion: @escaping (_ faces: [Face]) -> Void) {
        FaceAPI.detect(photo) { (result) in
            switch result {
            case .success(let json):
                var faces = [Face]()
                
                let detectedFaces = json as! JSONArray
                for item in detectedFaces {
                    let face = item as! JSONDictionary
                    let faceId = face["faceId"] as! String
                    let rectangle = face["faceRectangle"] as! [String: AnyObject]
                    
                    let detectedFace = Face(faceId: faceId,
                                            height: rectangle["top"] as! Int,
                                            width: rectangle["width"] as! Int,
                                            top: rectangle["top"] as! Int,
                                            left: rectangle["left"] as! Int, faceIdentity: nil, faceIdentityConfidence: nil)
                    
                    print("Found face \(detectedFace)")

                    faces.append(detectedFace)
                }
                if (faces.count > 0) { completion(faces) }
                break
            case .failure(let error):
                print("DetectFaces error - ", error)
                
                break
            }
        }
    }
    
    static func identifyFaces(_ faces: [Face], personGroupId: String, completion: @escaping (_ error: Error?, _ foundFaces: [Face]?) -> Void) {
        
        print("Looking in group", personGroupId)
        var faceIds = [String]()
        for face in faces {
            faceIds.append(face.faceId)
        }
        
        FaceAPI.identify(faces: faceIds, personGroupId: personGroupId) { (result) in
            switch result {
            case .success(let json):
                let jsonArray = json as! JSONArray
                
                var foundFaces = faces

                
                for item in jsonArray {
                    var face = item as! JSONDictionary
                    
                    let faceId = face["faceId"] as! String
                    let candidates = face["candidates"] as! JSONArray
                    
                    for candidate in candidates {
     
                        // find face information based on faceId
                        for (index,face) in faces.enumerated() {
                            if face.faceId == faceId {
                                foundFaces[index].faceIdentity = candidate["personId"] as? String
                                foundFaces[index].faceIdentityConfidence = candidate["confidence"] as? Float
                                
                                print("Found face: \(face)")
                            }
                        }
                    }
                }
                
                completion(nil, foundFaces)
            case .failure(let error):
                print("Identifying faces error - ", error)
                completion(error, nil)
                break
            }
        }
    }
    
    
    static func getFaceKey() -> String{
        
        var faceKey = ""
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"), let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            
            faceKey = dict["Microsoft Cognitive Services"]?["FaceKey"] as! String
        }
        
        return faceKey
    }
    
    static func getGroupID() -> String{
        
        var groupID = ""
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"), let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            
            groupID = dict["Microsoft Cognitive Services"]?["FaceGroupID"] as! String
        }
        
        return groupID
    }
    

    
    static func getServiceURL() -> String{
        
        var serviceUrl = ""
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"), let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            
            
            serviceUrl = dict["Microsoft Cognitive Services"]?["ServiceURL"] as! String
            
        }
        
        return serviceUrl
    }
}




typealias JSON = AnyObject
typealias JSONDictionary = [String: JSON]
typealias JSONArray = [JSON]

enum FaceError: Error {

    case unexpectedError(nsError: NSError?)
    case serviceError(json: [String: AnyObject])
    case jSonSerializationError
}
