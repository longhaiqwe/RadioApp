import Foundation

@main
struct RadioBrowserRegionQueryTests {
    static func main() {
        let expectedMainlandStates: [String: String] = [
            "Beijing": "Beijing",
            "Shanghai": "Shanghai",
            "Tianjin": "Tientsin",
            "Chongqing": "Chungking",
            "Hunan": "Hunan",
            "Guangdong": "Kwangtung",
            "Hubei": "Hupei",
            "Jiangsu": "Kiangsu",
            "Zhejiang": "Chekiang",
            "Sichuan": "Szechuan",
            "Shandong": "Shantung",
            "Henan": "Honan",
            "Hebei": "Hopei",
            "Liaoning": "Liaoning",
            "Shaanxi": "Shensi",
            "Fujian": "Fukien",
            "Jiangxi": "Kiangsi",
            "Heilongjiang": "黑龙江",
            "Jilin": "Jilin",
            "Anhui": "Anhwei",
            "Shanxi": "Shansi",
            "Yunnan": "Yunnan",
            "Guangxi": "Kwangsi",
            "Guizhou": "Kweichow",
            "Hainan": "Hainan",
            "Gansu": "Kansu",
            "Qinghai": "Tsinghai",
            "Inner Mongolia": "Inner Mongolia",
            "Ningxia": "Ningsia",
            "Xinjiang": "Sinkiang",
            "Tibet": "xizang"
        ]

        for (regionCode, expectedState) in expectedMainlandStates {
            let query = RadioBrowserRegionQuery.make(regionCode: regionCode)
            expectEqual(query.state, expectedState, "Unexpected Radio Browser state for \(regionCode)")
            expectEqual(query.countryCode, "CN", "Mainland region \(regionCode) should remain in China")
        }

        let expectedCountryRegions: [String: String] = [
            "Hong Kong": "HK",
            "Macau": "MO",
            "Taiwan": "TW"
        ]

        for (regionCode, expectedCountryCode) in expectedCountryRegions {
            let query = RadioBrowserRegionQuery.make(regionCode: regionCode)
            expectEqual(query.state, nil, "Country-level region \(regionCode) should not add a state filter")
            expectEqual(query.countryCode, expectedCountryCode, "Unexpected country code for \(regionCode)")
        }
    }
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
    guard actual == expected else {
        fatalError("\(message). Expected \(expected), got \(actual)")
    }
}
