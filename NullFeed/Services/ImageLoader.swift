import Foundation
#if canImport(UIKit)
import UIKit
#endif

actor ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    func load(from urlString: String) async -> UIImage? {
        if let cached = cache.object(forKey: urlString as NSString) {
            return cached
        }

        if let existing = inFlight[urlString] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            guard let url = URL(string: urlString) else { return nil }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                cache.setObject(image, forKey: urlString as NSString)
                return image
            } catch {
                return nil
            }
        }

        inFlight[urlString] = task
        let result = await task.value
        inFlight.removeValue(forKey: urlString)
        return result
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
