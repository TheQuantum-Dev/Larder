//
//  OpenFoodFactsClient.swift
//  Larder
//
//  Created by Joshua Samuel on 9/22/26.
//

import Foundation

/// A packaged product's name, looked up from Open Food Facts by barcode.
/// Only the barcode number is ever sent; nothing about the person or their
/// pantry goes with it.
nonisolated struct BarcodeProduct: Codable, Sendable {
    let barcode: String
    let name: String

    /// Matches the product to the catalog when we can ("Organic Whole Milk"
    /// finds "milk"); otherwise it keeps its own name, the same fallback a
    /// photo scan uses for something it doesn't recognize.
    var resolvedItem: ResolvedItem {
        IngredientCatalog.find(inText: name).first ?? ResolvedItem(customName: name)
    }
}

/// Looks packaged products up by barcode. Results are cached on disk, both
/// so re-scanning the same item is instant and so a demo still works offline
/// the second time.
enum OpenFoodFactsClient {
    enum LookupError: Error { case notFound, network }

    private static let cacheURL = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("barcode-cache.json")

    static func lookup(barcode: String) async -> Result<BarcodeProduct, LookupError> {
        if let cached = readCache()[barcode] { return .success(cached) }

        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json"
                            + "?fields=product_name,product_name_en") else { return .failure(.network) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return .failure(.network) }
        guard let response = try? JSONDecoder().decode(OFFResponse.self, from: data),
              let name = response.product?.name, !name.isEmpty else { return .failure(.notFound) }

        let product = BarcodeProduct(barcode: barcode, name: name)
        writeCache(adding: product)
        return .success(product)
    }

    private struct OFFResponse: Decodable {
        let product: OFFProduct?
    }

    private struct OFFProduct: Decodable {
        let productName: String?
        let productNameEn: String?
        var name: String? { productNameEn?.isEmpty == false ? productNameEn : productName }

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case productNameEn = "product_name_en"
        }
    }

    // MARK: - Cache

    private static func readCache() -> [String: BarcodeProduct] {
        guard let data = try? Data(contentsOf: cacheURL),
              let products = try? JSONDecoder().decode([BarcodeProduct].self, from: data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: products.map { ($0.barcode, $0) })
    }

    private static func writeCache(adding product: BarcodeProduct) {
        var all = readCache()
        all[product.barcode] = product
        guard let data = try? JSONEncoder().encode(Array(all.values)) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
