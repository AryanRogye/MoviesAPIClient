//
//  SearchResult.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

enum MediaType: String, Decodable {
    case tv
    case movie
    case person
}

struct SearchResult: Decodable, Identifiable {
    let id: Int
    let mediaType: MediaType
    let title: String?
    let name: String?
    let posterPath: String?
    let overview: String?
}

struct SearchResponse: Decodable {
    let results: [SearchResult]
}
