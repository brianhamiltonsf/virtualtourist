//
//  flickerclient.swift
//  virtualtourist
//
//  Created by Brian Hamilton on 4/27/21.
//

import Foundation

class FlickrClient {
   
    static let apiKey = "b9dd43ccd5352cad493a694ae8021a26"
    static let secret = "a0f1f77fbac7e248"
    static var lastNumberOfPages = 1
    
    class func getPlacesURL(latitude: Double, longitude: Double, perPage: Int, page: Int) -> URL {
        let urlString = "https://www.flickr.com/services/rest/?method=flickr.photos.search&api_key=b9dd43ccd5352cad493a694ae8021a26&lat=\(latitude.description)&lon=\(longitude.description)&per_page=\(perPage)&page=\(page)&format=json&nojsoncallback=1"
        return URL(string: urlString)!
    }
    
    class func getImageIDs(url: URL, latitude: Double, longitude: Double, perPage: Int, page: Int, completion: @escaping (Bool, Photos?, Error?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let flickrRequest = FlickrRequest(api_key: FlickrClient.apiKey, lat: latitude.description, lon: longitude.description, per_page: perPage.description, page: page.description)
        do {
            let jsonData = try JSONEncoder().encode(flickrRequest)
            request.httpBody = jsonData
        } catch {
            print("error encoding, \(error)")
            completion(false, nil, error)
            return
        }
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data else {
                print("error getting response")
                completion(false, nil, error)
                return
            }
            let decoder = JSONDecoder()
//            print(String(data: data, encoding: .utf8)!)
            do {
                let flickrResponse = try decoder.decode(Photos.self, from: data)
                completion(true, flickrResponse, nil)
                
            } catch {
                print("error decoding")
                DispatchQueue.main.async {
                    completion(false, nil, error)
                }
            }
        }.resume()
    }
    
    class func generatePhotoURL(photo: PhotoURL) -> String {
        let url = "https://live.staticflickr.com/\(photo.server)/\(photo.id)_\(photo.secret).jpg"
        return url
    }
    
    class func downloadImage(path: URL, completion: @escaping (Data?, Error?) -> Void) {
        URLSession.shared.dataTask(with: path) { data, response, error in
            completion(data, error)
        }.resume()
    }
}



