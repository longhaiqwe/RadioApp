import Foundation

/// PostHog 管理器 - 使用 URLSession 直接调用 PostHog API（无需 SDK 依赖）
class PostHogManager {
    static let shared = PostHogManager()
    
    private let apiKey = "phc_8YPhXVkNgP3KyEs1AfoUgdrE7oSC8N0JQXJwGcIurvE"
    private let host = "https://us.i.posthog.com"
    
    private init() {}
    
    /// 初始化（打印日志）
    func configure() {
        print("[PostHog] 初始化完成 (使用 REST API)")
    }
    
    /// 上报用户反馈
    func trackFeedback(content: String, type: String, contact: String?) {
        var properties: [String: Any] = [
            "content": content,
            "type": type,
            "device_model": deviceModel,
            "app_version": appVersion
        ]
        
        if let contact = contact, !contact.isEmpty {
            properties["contact"] = contact
        }
        
        capture(event: "feedback_submitted", properties: properties)
        print("[PostHog] 反馈已上报: \(type) - \(content.prefix(50))...")
    }
    
    /// 通用事件上报
    private func capture(event: String, properties: [String: Any] = [:]) {
        guard let url = URL(string: "\(host)/capture") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "api_key": apiKey,
            "event": event,
            "properties": properties,
            "distinct_id": distinctId
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("[PostHog] 序列化失败: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[PostHog] 上报失败: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("[PostHog] 上报成功")
                } else {
                    print("[PostHog] 上报失败，状态码: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    /// 获取设备唯一标识（简化版，使用 UUID）
    private var distinctId: String {
        if let id = UserDefaults.standard.string(forKey: "posthog_distinct_id") {
            return id
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "posthog_distinct_id")
        return newId
    }
    
    /// 获取设备型号（用户友好名称）
    private var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return mapToDeviceName(identifier: identifier)
    }
    
    /// 将设备标识符映射为用户友好名称
    private func mapToDeviceName(identifier: String) -> String {
        let deviceMapping: [String: String] = [
            // iPhone 17 系列 (2025)
            "iPhone18,1": "iPhone 17 Pro",
            "iPhone18,2": "iPhone 17 Pro Max",
            "iPhone18,3": "iPhone 17",
            "iPhone18,4": "iPhone Air",
            // iPhone 16 系列
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
            // iPhone 15 系列
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            // iPhone 14 系列
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            // iPhone 13 系列
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            // iPhone 12 系列
            "iPhone13,1": "iPhone 12 mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            // iPhone SE
            "iPhone14,6": "iPhone SE (3rd gen)",
            "iPhone12,8": "iPhone SE (2nd gen)",
            // iPad 常用型号
            "iPad14,1": "iPad mini (6th gen)",
            "iPad13,1": "iPad Air (4th gen)",
            "iPad13,16": "iPad Air (5th gen)",
            // 模拟器
            "x86_64": "Simulator (x86_64)",
            "arm64": "Simulator (arm64)"
        ]
        
        return deviceMapping[identifier] ?? identifier
    }
    
    /// 获取 App 版本
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
