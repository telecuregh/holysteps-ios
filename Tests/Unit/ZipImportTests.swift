import XCTest
@testable import HolySteps

/// The period import from another tracker's export, including Clue-style password-locked zips.
/// Fixtures: the same measurements.json zipped with `zip -P secret123` (ZipCrypto) and with WinZip AES-256 (pyzipper).
final class ZipImportTests: XCTestCase {
    private let zipCrypto = Data(base64Encoded: "UEsDBBQACQAIAJWtel0dTUE8awAAAM4AAAARABwAbWVhc3VyZW1lbnRzLmpzb25VVAkAA5ruCGua7ghrdXgLAAEEAAAAAAQAAAAAm2KFznT0z17ohW5nElNJ2AeuoJOmhHUfXICmuy/aoWtwfr9l+oiO93xH5Jw8T5+TJES8Y+BGdoYgLkuMFKVLuE8W7edagrUsQXr2S1nxBRjz/CkD8Lt/+rBbjav78WWzvCEQiU0D8sHDe8VQSwcIHU1BPGsAAADOAAAAUEsBAh4DFAAJAAgAla16XR1NQTxrAAAAzgAAABEAGAAAAAAAAQAAAKSBAAAAAG1lYXN1cmVtZW50cy5qc29uVVQFAAOa7ghrdXgLAAEEAAAAAAQAAAAAUEsFBgAAAAABAAEAVwAAAMYAAAAAAA==")!
    private let aes = Data(base64Encoded: "UEsDBBQAAQBjAJWtel0AAAAAfAAAAM4AAAARAAsAbWVhc3VyZW1lbnRzLmpzb24BmQcAAgBBRQMIAPjvV3/KFJ2iCz28Si+arTphhj2eaO/yceu+U0fIOdFixA8ldHazK6akHdovywOLnnuvaB+fN1PSskkZTz990ij5Qq+E8lIXskY5HUhbdM7ZPIgtj4zJGAYuvVdfbfku+CUwTFwcbkYaG/jIM+MDTCKgxUSVF9TF96Ct+DBQSwECFAMUAAEAYwCVrXpdAAAAAHwAAADOAAAAEQALAAAAAAAAAAAApIEAAAAAbWVhc3VyZW1lbnRzLmpzb24BmQcAAgBBRQMIAFBLBQYAAAAAAQABAEoAAAC2AAAAAAA=")!
    private let expected = [PeriodImport.Period(start: "2026-09-01", days: 2), PeriodImport.Period(start: "2026-09-29", days: 1)]

    private func periods(_ zip: Data, _ pw: String?) throws -> [PeriodImport.Period] {
        try ZipReader.entries(zip, password: pw, want: PeriodImport.wanted).flatMap { PeriodImport.read(String(decoding: $0.data, as: UTF8.self)) }
    }

    func testZipCryptoOpensWithPassword() throws { XCTAssertEqual(try periods(zipCrypto, "secret123"), expected) }
    func testAesOpensWithPassword() throws { XCTAssertEqual(try periods(aes, "secret123"), expected) }

    func testLockedZipAsksForPassword() {
        XCTAssertThrowsError(try periods(zipCrypto, nil)) { XCTAssertEqual($0 as? ZipReader.Failure, .needsPassword) }
        XCTAssertThrowsError(try periods(aes, nil)) { XCTAssertEqual($0 as? ZipReader.Failure, .needsPassword) }
    }

    func testWrongPasswordIsRefused() {
        XCTAssertThrowsError(try periods(zipCrypto, "nope")) { XCTAssertEqual($0 as? ZipReader.Failure, .wrongPassword) }
        XCTAssertThrowsError(try periods(aes, "nope")) { XCTAssertEqual($0 as? ZipReader.Failure, .wrongPassword) }
    }

    func testFloStyleJsonAndCsv() {
        let flo = #"{"operationalData":{"cycles":[{"period_start_date":"2026-08-03","period_end_date":"2026-08-07"},{"period_start_date":"2026-08-31"}]}}"#
        XCTAssertEqual(PeriodImport.read(flo).map(\.start), ["2026-08-03", "2026-08-31"])
        XCTAssertEqual(PeriodImport.read(flo).first?.days, 5)
        let csv = "Start date,End date\n2026-07-01,2026-07-05\n2026-07-29,2026-08-02\n"
        XCTAssertEqual(PeriodImport.read(csv), [PeriodImport.Period(start: "2026-07-01", days: 5), PeriodImport.Period(start: "2026-07-29", days: 5)])
    }

    func testPredictionsAreSkipped() {
        let j = #"{"predictions":[{"date":"2026-10-27","type":"period"}],"data":[{"date":"2026-09-01","type":"period"}]}"#
        XCTAssertEqual(PeriodImport.read(j).map(\.start), ["2026-09-01"])
    }
}
