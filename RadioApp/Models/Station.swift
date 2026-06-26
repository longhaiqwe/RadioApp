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
    
    // MARK: - Equatable & Hashable
    // Only compare by consistent ID, ignoring dynamic fields like clickcount/votes
    static func == (lhs: Station, rhs: Station) -> Bool {
        return lhs.stationuuid == rhs.stationuuid
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(stationuuid)
    }
}

extension Station {
    static func sanitizedFavicon(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if trimmed.hasPrefix("bundle://") {
            let assetName = String(trimmed.dropFirst("bundle://".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return assetName == "asiafm_new_cover" ? "" : trimmed
        }

        if let url = URL(string: trimmed),
           let host = url.host?.lowercased(),
           ["radiotaiwan.tw", "www.radiotaiwan.tw"].contains(host),
           url.path.lowercased() == "/favicon.ico" {
            return ""
        }

        return trimmed
    }

    func withSanitizedFavicon() -> Station {
        let sanitized = Self.sanitizedFavicon(favicon)
        guard sanitized != favicon else { return self }

        return Station(
            changeuuid: changeuuid,
            stationuuid: stationuuid,
            name: name,
            url: url,
            urlResolved: urlResolved,
            homepage: homepage,
            favicon: sanitized,
            tags: tags,
            country: country,
            countrycode: countrycode,
            state: state,
            language: language,
            languagecodes: languagecodes,
            votes: votes,
            lastchangetime: lastchangetime,
            codec: codec,
            bitrate: bitrate,
            hls: hls,
            lastcheckok: lastcheckok,
            lastchecktime: lastchecktime,
            lastcheckoktime: lastcheckoktime,
            lastlocalchecktime: lastlocalchecktime,
            clicktimestamp: clicktimestamp,
            clickcount: clickcount,
            clicktrend: clicktrend
        )
    }
}
