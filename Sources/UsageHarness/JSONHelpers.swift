import Foundation

enum JSONHelpers {
    static func dictionary(from line: Substring) -> [String: Any]? {
        guard let data = String(line).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return object as? [String: Any]
    }

    static func int(_ dictionary: [String: Any]?, keys: String...) -> Int? {
        guard let dictionary else { return nil }
        var current: Any = dictionary
        for key in keys {
            guard let next = (current as? [String: Any])?[key] else { return nil }
            current = next
        }
        if let number = current as? NSNumber { return number.intValue }
        if let string = current as? String { return Int(string) }
        return nil
    }

    static func tail(of url: URL, maximumBytes: Int = 1_500_000) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        let offset = size > UInt64(maximumBytes) ? size - UInt64(maximumBytes) : 0
        try? handle.seek(toOffset: offset)
        let payload: Data?
        do {
            payload = try handle.readToEnd()
        } catch {
            return nil
        }
        guard let data = payload else { return nil }
        var text = String(decoding: data, as: UTF8.self)
        if offset > 0, let newline = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: newline)...])
        }
        return text
    }
}
