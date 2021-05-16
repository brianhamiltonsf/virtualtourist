//
//  SetOfPhotos.swift
//  virtualtourist
//
//  Created by Brian Hamilton on 5/4/21.
//

import Foundation

struct SetOfPhotos: Codable {
    let page: Int
    let pages: Int
    let perpage: Int
    let total: Int
    let photo: [PhotoURL]
}
