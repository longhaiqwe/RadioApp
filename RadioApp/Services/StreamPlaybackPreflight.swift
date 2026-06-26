import Foundation

enum StreamPlaybackPreflight {
    static func requiresProbe(for url: URL) -> Bool {
        url.host?.lowercased() == "stream.zeno.fm"
    }

    static func isPlayableHTTPResponse(statusCode: Int, contentType: String?) -> Bool {
        guard (200..<400).contains(statusCode) else {
            return false
        }

        guard let contentType = contentType?.lowercased(), !contentType.isEmpty else {
            return true
        }

        return contentType.hasPrefix("audio/")
            || contentType.hasPrefix("video/")
            || contentType.contains("mpegurl")
            || contentType.contains("octet-stream")
    }

    static func probe(_ url: URL, timeout: TimeInterval = 8.0) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        request.setValue("audio/mpeg,audio/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("iOS-Radio-App/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return true
            }

            return isPlayableHTTPResponse(
                statusCode: httpResponse.statusCode,
                contentType: httpResponse.value(forHTTPHeaderField: "Content-Type")
            )
        } catch {
            return false
        }
    }

    static func filterPlayableStations(
        _ stations: [Station],
        probe: (URL) async -> Bool = { await StreamPlaybackPreflight.probe($0) }
    ) async -> [Station] {
        var filtered: [Station] = []

        for station in stations {
            guard let url = URL(string: station.urlResolved) else {
                continue
            }

            guard requiresProbe(for: url) else {
                filtered.append(station)
                continue
            }

            if await probe(url) {
                filtered.append(station)
            }
        }

        return filtered
    }
}
