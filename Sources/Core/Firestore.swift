import Foundation

/// A small Firestore REST client on the account's own ID token (no Firebase SDK). Same collections and the
/// same firestore.rules as Android, so iPhone and Android people share one community.
enum FSValue: Equatable {
    case string(String), int(Int64), double(Double), bool(Bool), null
    case map([String: FSValue]), array([FSValue])

    var json: [String: Any] {
        switch self {
        case .string(let s): ["stringValue": s]
        case .int(let i): ["integerValue": String(i)]
        case .double(let d): ["doubleValue": d]
        case .bool(let b): ["booleanValue": b]
        case .null: ["nullValue": NSNull()]
        case .map(let m): ["mapValue": ["fields": m.mapValues(\.json)]]
        case .array(let a): ["arrayValue": ["values": a.map(\.json)]]
        }
    }

    static func from(_ j: Any?) -> FSValue {
        guard let j = j as? [String: Any] else { return .null }
        if let s = j["stringValue"] as? String { return .string(s) }
        if let s = j["integerValue"] as? String { return .int(Int64(s) ?? 0) }
        if let n = j["integerValue"] as? NSNumber { return .int(n.int64Value) }
        if let d = j["doubleValue"] as? Double { return .double(d) }
        if let b = j["booleanValue"] as? Bool { return .bool(b) }
        if let t = j["timestampValue"] as? String {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let d = f.date(from: t) ?? ISO8601DateFormatter().date(from: t)
            return .int(Int64((d?.timeIntervalSince1970 ?? 0) * 1000))
        }
        if let m = (j["mapValue"] as? [String: Any])?["fields"] as? [String: Any] { return .map(m.mapValues { from($0) }) }
        if j["mapValue"] != nil { return .map([:]) }
        if let a = (j["arrayValue"] as? [String: Any])?["values"] as? [Any] { return .array(a.map { from($0) }) }
        if j["arrayValue"] != nil { return .array([]) }
        return .null
    }

    var string: String { if case .string(let s) = self { return s }; return "" }
    var int: Int64 {
        switch self { case .int(let i): i; case .double(let d): Int64(d); default: 0 }
    }
    var bool: Bool { if case .bool(let b) = self { return b }; return false }
    var array: [FSValue] { if case .array(let a) = self { return a }; return [] }
    var map: [String: FSValue] { if case .map(let m) = self { return m }; return [:] }
}

struct FSDoc: Identifiable {
    let path: String          // e.g. "testimonies/abc"
    let fields: [String: FSValue]
    var id: String { String(path.split(separator: "/").last ?? "") }
    subscript(_ k: String) -> FSValue { fields[k] ?? .null }
}

enum FSWrite {
    /// Create or replace the whole document. `mustNotExist` makes it a create.
    case set(String, [String: FSValue], mustNotExist: Bool = false)
    /// Change only the named fields (the document must exist), with optional counter steps.
    case update(String, [String: FSValue], increments: [String: Int64] = [:])
    case delete(String)
}

enum FSError: Error { case notSignedIn, denied, failed(Int) }

enum Firestore {
    static var base: String? {
        FirebaseConfig.projectId.map { "projects/\($0)/databases/(default)/documents" }
    }
    private static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        return URLSession(configuration: c)
    }()

    static func newId() -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<20).map { _ in chars.randomElement()! })
    }

    private static func call(_ url: String, method: String, body: [String: Any]? = nil) async throws -> Any? {
        guard let tok = await AccountStore.shared.token(), let u = URL(string: url) else { throw FSError.notSignedIn }
        var r = URLRequest(url: u)
        r.httpMethod = method
        r.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await session.data(for: r)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { return nil }
        if code == 403 { throw FSError.denied }
        guard (200..<300).contains(code) else { throw FSError.failed(code) }
        return data.isEmpty ? nil : try JSONSerialization.jsonObject(with: data)
    }

    private static func doc(_ j: [String: Any]) -> FSDoc? {
        guard let name = j["name"] as? String, let b = base, let r = name.range(of: b + "/") else { return nil }
        let fields = (j["fields"] as? [String: Any] ?? [:]).mapValues { FSValue.from($0) }
        return FSDoc(path: String(name[r.upperBound...]), fields: fields)
    }

    static func get(_ path: String) async throws -> FSDoc? {
        guard let b = base else { throw FSError.notSignedIn }
        let j = try await call("https://firestore.googleapis.com/v1/\(b)/\(path)", method: "GET") as? [String: Any]
        return j.flatMap(doc)
    }

    struct Filter { let field: String; let op: String; let value: FSValue }   // op: EQUAL, ARRAY_CONTAINS, GREATER_THAN …

    /// Documents of one collection under `parent` ("" for the top level), filtered and sorted.
    static func query(_ collection: String, parent: String = "", filters: [Filter] = [], orderBy: String? = nil,
                      descending: Bool = true, limit: Int = 100) async throws -> [FSDoc] {
        guard let b = base else { throw FSError.notSignedIn }
        var q: [String: Any] = ["from": [["collectionId": collection]], "limit": limit]
        let f = filters.map { ["fieldFilter": ["field": ["fieldPath": $0.field], "op": $0.op, "value": $0.value.json]] }
        if f.count == 1 { q["where"] = f[0] } else if f.count > 1 { q["where"] = ["compositeFilter": ["op": "AND", "filters": f]] }
        if let orderBy { q["orderBy"] = [["field": ["fieldPath": orderBy], "direction": descending ? "DESCENDING" : "ASCENDING"]] }
        let url = "https://firestore.googleapis.com/v1/\(b)\(parent.isEmpty ? "" : "/" + parent):runQuery"
        let rows = try await call(url, method: "POST", body: ["structuredQuery": q]) as? [[String: Any]] ?? []
        return rows.compactMap { ($0["document"] as? [String: Any]).flatMap(doc) }
    }

    /// Every write lands together or not at all (the rules check them as one).
    static func commit(_ writes: [FSWrite]) async throws {
        guard let b = base else { throw FSError.notSignedIn }
        let w: [[String: Any]] = writes.map { write in
            switch write {
            case .set(let p, let f, let mustNotExist):
                var x: [String: Any] = ["update": ["name": "\(b)/\(p)", "fields": f.mapValues(\.json)]]
                if mustNotExist { x["currentDocument"] = ["exists": false] }
                return x
            case .update(let p, let f, let inc):
                var x: [String: Any] = ["update": ["name": "\(b)/\(p)", "fields": f.mapValues(\.json)],
                                        "updateMask": ["fieldPaths": Array(f.keys)],
                                        "currentDocument": ["exists": true]]
                if !inc.isEmpty {
                    x["updateTransforms"] = inc.map { ["fieldPath": $0.key, "increment": ["integerValue": String($0.value)]] }
                }
                return x
            case .delete(let p):
                return ["delete": "\(b)/\(p)"]
            }
        }
        _ = try await call("https://firestore.googleapis.com/v1/\(b):commit", method: "POST", body: ["writes": w])
    }

    static var nowMs: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
