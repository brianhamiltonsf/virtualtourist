//
//  FlickrRequest.swift
//  virtualtourist
//
//  Created by Brian Hamilton on 5/4/21.
//

import Foundation

struct FlickrRequest: Codable {
    let api_key: String
    let lat: String
    let lon: String
    let per_page: String
    let page: String
}
