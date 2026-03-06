import Foundation

extension JSONDecoder {
    static let nullFeed: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: string) {
                return date
            }
            // Then standard ISO8601
            if let date = ISO8601DateFormatter.standard.date(from: string) {
                return date
            }
            // Fallback: no timezone (assume UTC), e.g. "2026-03-03T21:43:09.794907"
            // Append Z so ISO8601DateFormatter can parse it
            let withZ = string.hasSuffix("Z") ? string : string + "Z"
            if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: withZ) {
                return date
            }
            if let date = ISO8601DateFormatter.standard.date(from: withZ) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }
        return decoder
    }()
}

extension ISO8601DateFormatter {
    nonisolated(unsafe) static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
