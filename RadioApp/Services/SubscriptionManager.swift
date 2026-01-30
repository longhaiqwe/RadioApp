import Foundation
import StoreKit
import Combine

/// 订阅管理器 - 使用 StoreKit 2 处理 Pro 终身版购买
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    // MARK: - 产品 ID
    // ⚠️ 请将此 ID 替换为你在 App Store Connect 配置的实际产品 ID
    static let proLifetimeProductID = "com.shiyinFM.pro.lifetime"
    
    // MARK: - Published 属性
    @Published var isPro: Bool = false
    @Published var proProduct: Product?
    @Published var purchaseInProgress: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - 持久化 Key
    private let isPurchasedKey = "isPro_purchased"
    private let creditsKey = "recognition_credits"
    private let initialCredits = 200
    
    private init() {
        // 启动时检查购买状态
        let purchased = UserDefaults.standard.bool(forKey: isPurchasedKey)
        isPro = purchased
        
        // 加载配额 (如果是 Pro 但没有配额记录，则初始化)
        if purchased {
            if UserDefaults.standard.object(forKey: creditsKey) == nil {
                UserDefaults.standard.set(initialCredits, forKey: creditsKey)
            }
        }
        
        // 异步加载产品和验证购买
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
        
        // 监听交易更新
        listenForTransactions()
    }
    
    // MARK: - 加载产品信息
    
    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proLifetimeProductID])
            if let product = products.first {
                self.proProduct = product
                print("SubscriptionManager: 加载产品成功 - \(product.displayName) (\(product.displayPrice))")
            } else {
                print("SubscriptionManager: 未找到产品 \(Self.proLifetimeProductID)")
                errorMessage = "未找到可购买的商品"
            }
        } catch {
            print("SubscriptionManager: 加载产品失败 - \(error.localizedDescription)")
            errorMessage = "无法加载商品信息"
        }
    }
    
    // MARK: - 购买
    
    func purchase() async {
        guard let product = proProduct else {
            errorMessage = "商品信息未加载"
            return
        }
        
        guard !purchaseInProgress else { return }
        
        purchaseInProgress = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // 验证交易
                switch verification {
                case .verified(let transaction):
                    // 交易有效，解锁 Pro
                    await unlockPro()
                    await transaction.finish()
                    print("SubscriptionManager: 购买成功!")
                    
                case .unverified(_, let error):
                    errorMessage = "购买验证失败"
                    print("SubscriptionManager: 交易验证失败 - \(error)")
                }
                
            case .pending:
                // 等待审批（如家长控制）
                errorMessage = "购买等待审批"
                print("SubscriptionManager: 购买等待审批")
                
            case .userCancelled:
                // 用户取消
                print("SubscriptionManager: 用户取消购买")
                
            @unknown default:
                break
            }
        } catch {
            errorMessage = "购买失败: \(error.localizedDescription)"
            print("SubscriptionManager: 购买失败 - \(error)")
        }
        
        purchaseInProgress = false
    }
    
    // MARK: - 恢复购买
    
    func restorePurchases() async {
        purchaseInProgress = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            
            if isPro {
                print("SubscriptionManager: 恢复购买成功")
            } else {
                errorMessage = "未找到之前的购买记录"
            }
        } catch {
            errorMessage = "恢复购买失败"
            print("SubscriptionManager: 恢复购买失败 - \(error)")
        }
        
        purchaseInProgress = false
    }
    
    // MARK: - 更新购买状态
    
    private func updatePurchasedProducts() async {
        // 检查所有已购买的非消耗型产品
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == Self.proLifetimeProductID {
                    await unlockPro()
                    return
                }
            case .unverified:
                break
            }
        }
    }
    
    // MARK: - 监听交易更新
    
    private func listenForTransactions() {
        Task.detached {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    if transaction.productID == Self.proLifetimeProductID {
                        await MainActor.run {
                            Task {
                                await self.unlockPro()
                            }
                        }
                        await transaction.finish()
                    }
                case .unverified:
                    break
                }
            }
        }
    }
    
    // MARK: - 解锁 Pro
    
    private func unlockPro() async {
        if !isPro {
            isPro = true
            UserDefaults.standard.set(true, forKey: isPurchasedKey)
            
            // 首次解锁赠送配额
            if UserDefaults.standard.object(forKey: creditsKey) == nil {
                UserDefaults.standard.set(initialCredits, forKey: creditsKey)
            }
            print("SubscriptionManager: Pro 已解锁，初始化 \(initialCredits) 次高级识别配额!")
        }
    }
    
    // MARK: - 配额管理
    
    /// 获取当前剩余配额
    var currentCredits: Int {
        return UserDefaults.standard.integer(forKey: creditsKey)
    }
    
    /// 消耗 1 次配额
    func consumeCredit() {
        let current = currentCredits
        if current > 0 {
            UserDefaults.standard.set(current - 1, forKey: creditsKey)
            self.objectWillChange.send()
        }
    }
}
