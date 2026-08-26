import Foundation

struct RadioBrowserRegionQuery: Equatable, Sendable {
    let state: String?
    let countryCode: String

    static func make(regionCode: String) -> RadioBrowserRegionQuery {
        if let countryCode = countryCodes[regionCode] {
            return RadioBrowserRegionQuery(state: nil, countryCode: countryCode)
        }

        return RadioBrowserRegionQuery(
            state: mainlandStates[regionCode] ?? regionCode,
            countryCode: "CN"
        )
    }

    private static let countryCodes: [String: String] = [
        "Hong Kong": "HK",
        "Macau": "MO",
        "Taiwan": "TW"
    ]

    // Radio Browser's China data mostly uses legacy postal spellings for state names.
    private static let mainlandStates: [String: String] = [
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
}
