import Foundation

enum GzipError: Error { case notGzip, corrupt }

extension Data {
    /// Unpacks a .gz file (RFC 1952). Apple's `.zlib` algorithm is raw DEFLATE, so the gzip header and trailer are
    /// stepped over here and only the deflate stream is decompressed.
    func gunzipped() throws -> Data {
        let bytes = [UInt8](self)
        guard bytes.count > 18, bytes[0] == 0x1f, bytes[1] == 0x8b, bytes[2] == 8 else { throw GzipError.notGzip }
        let flags = bytes[3]
        var i = 10
        if flags & 0x04 != 0 {                       // FEXTRA
            guard i + 2 <= bytes.count else { throw GzipError.corrupt }
            i += 2 + Int(bytes[i]) + Int(bytes[i + 1]) << 8
        }
        if flags & 0x08 != 0 { while i < bytes.count && bytes[i] != 0 { i += 1 }; i += 1 }   // FNAME
        if flags & 0x10 != 0 { while i < bytes.count && bytes[i] != 0 { i += 1 }; i += 1 }   // FCOMMENT
        if flags & 0x02 != 0 { i += 2 }                                                     // FHCRC
        guard i < bytes.count - 8 else { throw GzipError.corrupt }
        let deflate = Data(bytes[i..<(bytes.count - 8)])
        do {
            return try (deflate as NSData).decompressed(using: .zlib) as Data
        } catch {
            throw GzipError.corrupt
        }
    }
}

extension Bundle {
    /// A bundled resource read whole, unpacked when it ends in .gz.
    func resourceData(_ name: String) -> Data? {
        guard let url = url(forResource: name, withExtension: nil),
              let raw = try? Data(contentsOf: url) else { return nil }
        return name.hasSuffix(".gz") ? (try? raw.gunzipped()) : raw
    }
}
