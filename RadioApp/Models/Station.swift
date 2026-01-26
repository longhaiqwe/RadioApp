import Foundation

struct Station: Codable, Identifiable, Hashable {
    let changeuuid: String
    let stationuuid: String
    let name: String
    let url: String
    let urlResolved: String
    let homepage: String
    let favicon: String
    let tags: String
    let country: String
    let countrycode: String
    let state: String
    let language: String
    let languagecodes: String?
    let votes: Int
    let lastchangetime: String
    let codec: String
    let bitrate: Int
    let hls: Int
    let lastcheckok: Int
    let lastchecktime: String
    let lastcheckoktime: String
    let lastlocalchecktime: String
    let clicktimestamp: String
    let clickcount: Int
    let clicktrend: Int
    
    var id: String { stationuuid }
    
    enum CodingKeys: String, CodingKey {
        case changeuuid, stationuuid, name, url, homepage, favicon, tags, country, countrycode, state, language, languagecodes, votes, lastchangetime, codec, bitrate, hls, lastcheckok, lastchecktime, lastcheckoktime, lastlocalchecktime, clicktimestamp, clickcount, clicktrend
        case urlResolved = "url_resolved"
    }
}
