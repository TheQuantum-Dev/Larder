//
//  SpoonacularClient.swift
//  Larder
//
//  Created by Joshua Samuel on 9/26/26.
//

import Foundation

/// The real recipe service: spoonacular's free plan. The key goes in a request
/// header rather than the address, so it never turns up in a URL, and nothing
/// here is ever logged.
nonisolated struct SpoonacularClient: RecipeAPI {
    let apiKey: String
    var session: URLSession = .shared

    static let host = "https://api.spoonacular.com"
    static let requestTimeout: TimeInterval = 8

    func search(_ request: OnlineRequest) async throws -> OnlineSearchOutcome {
        var components = URLComponents(string: Self.host + "/recipes/complexSearch")
        components?.queryItems = OnlineQuery.items(for: request)
        guard let url = components?.url else { throw OnlineError.badResponse }

        let (data, response) = try await send(url)
        guard let decoded = try? JSONDecoder().decode(OnlineSearchResponse.self, from: data) else {
            throw OnlineError.badResponse
        }
        let charged = response.value(forHTTPHeaderField: "X-API-Quota-Request").flatMap(Double.init)
        return OnlineSearchOutcome(recipes: decoded.results, pointsCharged: charged)
    }

    func recipe(id: Int) async throws -> OnlineRecipeDTO {
        var components = URLComponents(string: Self.host + "/recipes/\(id)/information")
        components?.queryItems = [URLQueryItem(name: "includeNutrition", value: "true")]
        guard let url = components?.url else { throw OnlineError.badResponse }
        let (data, _) = try await send(url)
        guard let recipe = try? JSONDecoder().decode(OnlineRecipeDTO.self, from: data) else {
            throw OnlineError.badResponse
        }
        return recipe
    }

    private func send(_ url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = Self.requestTimeout
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw OnlineError.badResponse }
            switch http.statusCode {
            case 200..<300: return (data, http)
            case 401, 403: throw OnlineError.unauthorized
            case 402: throw OnlineError.quotaExceeded
            case 429: throw OnlineError.rateLimited
            default: throw OnlineError.badResponse
            }
        } catch let error as OnlineError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw CancellationError()
            case .notConnectedToInternet, .timedOut, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dataNotAllowed, .dnsLookupFailed:
                throw OnlineError.offline
            default:
                throw OnlineError.badResponse
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw OnlineError.badResponse
        }
    }
}
