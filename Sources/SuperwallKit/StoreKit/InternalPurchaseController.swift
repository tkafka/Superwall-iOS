//
//  File.swift
//  
//
//  Created by Yusuf Tör on 29/08/2023.
//

import Foundation
import StoreKit

protocol RestoreDelegate: AnyObject {
  func didRestore(result: RestorationResult) async
}

final class InternalPurchaseController: PurchaseController {
  var hasExternalPurchaseController: Bool {
    return swiftPurchaseController != nil || objcPurchaseController != nil
  }
  private var swiftPurchaseController: PurchaseController?
  private var objcPurchaseController: PurchaseControllerObjc?
  private let factory: ProductPurchaserFactory
  lazy var productPurchaser = factory.makeSK1ProductPurchaser()
  weak var delegate: RestoreDelegate?

  init(
    factory: ProductPurchaserFactory,
    swiftPurchaseController: PurchaseController?,
    objcPurchaseController: PurchaseControllerObjc?
  ) {
    self.swiftPurchaseController = swiftPurchaseController
    self.objcPurchaseController = objcPurchaseController
    self.factory = factory
  }
}

// MARK: - Subscription Status
extension InternalPurchaseController {
  func syncSubscriptionStatus(withPurchases purchases: Set<InAppPurchase>) async {
    if hasExternalPurchaseController {
      return
    }
    let activePurchases = purchases.filter { $0.isActive }
    await MainActor.run {
      if activePurchases.isEmpty {
        Superwall.shared.subscriptionStatus = .inactive
      } else {
        Superwall.shared.subscriptionStatus = .active
      }
    }
  }
}

// MARK: - Restoration
extension InternalPurchaseController {
  @MainActor
  func restorePurchases() async -> RestorationResult {
    if let purchaseController = swiftPurchaseController {
      return await purchaseController.restorePurchases()
    } else if let purchaseController = objcPurchaseController {
      return await withCheckedContinuation { continuation in
        purchaseController.restorePurchases { result, error in
          switch result {
          case .restored:
            continuation.resume(returning: .restored)
          case .failed:
            continuation.resume(returning: .failed(error))
          }
        }
      }
    } else {
      let result = await productPurchaser.restorePurchases()
      await delegate?.didRestore(result: result)
      return result
    }
  }
}

// MARK: - Purchasing
extension InternalPurchaseController {
  @MainActor
  func purchase(product: SKProduct) async -> PurchaseResult {
    await productPurchaser.coordinator.beginPurchase(
      of: product.productIdentifier
    )
    if let purchaseController = swiftPurchaseController {
      return await purchaseController.purchase(product: product)
    } else if let purchaseController = objcPurchaseController {
      return await withCheckedContinuation { continuation in
        purchaseController.purchase(product: product) { result, error in
          if let error = error {
            continuation.resume(returning: .failed(error))
          } else {
            switch result {
            case .purchased:
              continuation.resume(returning: .purchased)
            case .restored:
              continuation.resume(returning: .restored)
            case .pending:
              continuation.resume(returning: .pending)
            case .cancelled:
              continuation.resume(returning: .cancelled)
            case .failed:
              break
            }
          }
        }
      }
    } else {
      return await productPurchaser.purchase(product: product)
    }
  }
}
