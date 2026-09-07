import Foundation

enum JSONHelpers {
    static func dictionary(from line: Substring) -> [String: Any]? {
        guard let data = String(line).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return object as? [String: Any]
    }

    static func contents(of url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
}
