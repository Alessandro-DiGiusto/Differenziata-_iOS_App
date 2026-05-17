//
//  DatabaseService.swift
//  Acireale Differenziata
//
//  Servizio di rete per comunicare con api.php.
//  Tutte le chiamate sono su MainActor (@MainActor) per semplicità.
//

import Foundation

// MARK: - Errori

enum DatabaseError: LocalizedError {
    case network(Error)
    case server(String)
    case decoding(Error)
    case comuneNonTrovato

    var errorDescription: String? {
        switch self {
        case .network(let error):
            return "Errore di rete: \(error.localizedDescription)"
        case .server(let message):
            return "Errore server: \(message)"
        case .decoding(let error):
            return "Errore dati: \(error.localizedDescription)"
        case .comuneNonTrovato:
            return "Comune non trovato nel database."
        }
    }
}

// MARK: - API Response generici

private struct APIResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
    let message: String?
}

private struct ComuneSuggestion: Decodable {
    let nome: String
    let provincia: String
    let lat: Double?
    let lon: Double?
}

private struct ComuneVicino: Decodable {
    let nome: String
    let provincia: String
    let lat: Double?
    let lon: Double?
}

private struct ProfiloResponse: Decodable {
    let comune_nome: String
    let profile_json: MunicipalityProfile
    let updated_at: String?
}

// MARK: - DatabaseService

@MainActor
enum DatabaseService {

    // ── URL Helper ──────────────────────────────────────────────
    private static var baseURL: URL {
        guard let url = URL(string: APIConfig.apiBaseURL) else {
            fatalError("[DatabaseService] apiBaseURL non valido: \(APIConfig.apiBaseURL)")
        }
        return url
    }

    private static func get(_ path: String) -> URL {
        baseURL.appendingPathComponent(path)
    }

    private static var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource  = APIConfig.timeout
        return URLSession(configuration: config)
    }

    // ── 1. Lista comioni con profilo ─────────────────────────
    /// Restituisce i nomi di tutti i comuni che hanno un profilo salvato nel DB.
    static func profili() async throws -> [String] {
        var components = URLComponents(url: get("api.php"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "action", value: "profili")]

        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(APIResponse<[String]>.self, from: data)

        guard response.success, let nomi = response.data else {
            throw DatabaseError.server(response.error ?? "Errore sconosciuto")
        }

        return nomi
    }

    // ── 2. Dettaglio profilo di un comune ─────────────────────
    /// Restituisce il profilo completo di un comune (se presente nel DB).
    static func profilo(comune: String) async throws -> MunicipalityProfile {
        var components = URLComponents(url: get("api.php"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "profilo"),
            URLQueryItem(name: "comune", value: comune),
        ]

        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(APIResponse<ProfiloResponse>.self, from: data)

        guard response.success, let profilo = response.data else {
            if let err = response.error, err.contains("non trovato") {
                throw DatabaseError.comuneNonTrovato
            }
            throw DatabaseError.server(response.error ?? "Errore sconosciuto")
        }

        return profilo.profile_json
    }

    // ── 3. Salva profilo ─────────────────────────────────────
    /// Crea o aggiorna il profilo di un comune sul DB remoto.
    static func salva(profilo: MunicipalityProfile) async throws {
        var components = URLComponents(url: get("api.php"), resolvingAgainstBaseURL: true)!
        components.queryItems = [URLQueryItem(name: "action", value: "salva")]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "comune_nome": profilo.municipalityName,
            "profile_json": profilo.dictionary,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, _) = try await session.data(for: request)
        let response = try JSONDecoder().decode(APIResponse<[String: String]>.self, from: data)

        guard response.success else {
            throw DatabaseError.server(response.error ?? "Errore salvataggio")
        }
    }

    // ── 4. Cerca comuni (Nominatim) ──────────────────────────
    /// Cerca comuni italiani per autocomplete.
    /// Usa Nominatim (OpenStreetMap) — gratuito, nessuna API key.
    static func cercaComuni(query: String) async throws -> [(nome: String, provincia: String)] {
        var components = URLComponents(url: get("api.php"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "comuni"),
            URLQueryItem(name: "q", value: query),
        ]

        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(APIResponse<[ComuneSuggestion]>.self, from: data)

        guard response.success, let risultati = response.data else {
            return []
        }

        return risultati.map { ($0.nome, $0.provincia) }
    }

    // ── 5. Comune da coordinate GPS ──────────────────────────
    /// Trova il comune corrispondente a coordinate GPS.
    /// Usa il reverse geocoding di Nominatim.
    static func comuneDaCoordinate(lat: Double, lon: Double) async throws -> (nome: String, provincia: String) {
        var components = URLComponents(url: get("api.php"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "comune_vicino"),
            URLQueryItem(name: "lat", value: "\(lat)"),
            URLQueryItem(name: "lon", value: "\(lon)"),
        ]

        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(APIResponse<ComuneVicino>.self, from: data)

        guard response.success, let comune = response.data else {
            throw DatabaseError.server(response.error ?? "Geolocalizzazione fallita")
        }

        return (comune.nome, comune.provincia)
    }
}

// MARK: - Helper: MunicipalityProfile → Dictionary

private extension MunicipalityProfile {
    var dictionary: [String: Any] {
        [
            "municipalityName": municipalityName,
            "collectionDays": collectionDays.map { day in
                [
                    "weekday": day.weekday,
                    "materialIDs": day.materialIDs,
                    "includesSupplementaryDiapers": day.includesSupplementaryDiapers,
                ] as [String: Any]
            },
        ]
    }
}
