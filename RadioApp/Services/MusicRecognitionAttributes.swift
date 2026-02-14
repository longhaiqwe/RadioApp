//
//  MusicRecognitionAttributes.swift
//  RadioApp
//
//  Created for Dynamic Island Music Recognition.
//  IMPORTANT: This file must be included in BOTH "RadioApp" and "RadioAppWidget" targets.
//

import ActivityKit
import Foundation

struct MusicRecognitionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state (changes during the activity)
        
        enum RecognitionState: String, Codable, Hashable {
            case listening
            case success
            case failed
        }
        
        var state: RecognitionState
        var songTitle: String?
        var artistName: String?
        var coverImageURL: URL?
        
        // Helper for default/listening state
        static var listening: ContentState {
            ContentState(state: .listening, songTitle: nil, artistName: nil, coverImageURL: nil)
        }
    }

    // Fixed properties (setup once)
    // We don't really have fixed properties for this use case, but it's required.
    // Maybe the station name?
    var stationName: String
}
