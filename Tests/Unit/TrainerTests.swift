import XCTest
@testable import HolySteps

final class TrainerTests: XCTestCase {
    /// Android's rule (TrainerVideoRuleTest): an exercise with no trainer video is not offered, so no bundled workout
    /// step may map to an UNRECORDED_MOVES key, and every step must have a trainer key.
    func testEveryWorkoutStepHasARecordedTrainer() {
        XCTAssertFalse(Coach.routines.isEmpty)
        var missing: [String] = []
        for r in Coach.routines {
            for s in r.steps {
                guard let k = TrainerClips.key(step: s.name, rest: s.rest) else { missing.append("\(r.id): \(s.name)"); continue }
                XCTAssertFalse(TrainerClips.isUnrecorded(k), "\(r.id): \(s.name) → \(k)")
            }
        }
        XCTAssertEqual(missing, [], "Steps with no trainer clip")
    }

    func testStepNamesMapLikeAndroid() {
        XCTAssertEqual(TrainerClips.key(step: "Squat jumps · round 1/3", rest: false), "SQUAT_JUMP")
        XCTAssertEqual(TrainerClips.key(step: "Easy bodyweight squats", rest: false), "SQUAT")
        XCTAssertEqual(TrainerClips.key(step: "Side plank — left · round 1/2", rest: false), "SIDE_PLANK_LEFT")
        XCTAssertEqual(TrainerClips.key(step: "Incline push-ups · round 1/2", rest: false), "INCLINE_PUSH_UP")
        XCTAssertEqual(TrainerClips.key(step: "Reverse lunges · round 2/3", rest: false), "LUNGE_LEFT")
        XCTAssertEqual(TrainerClips.key(step: "Torso twists", rest: false), "TORSO_TWIST")
        XCTAssertEqual(TrainerClips.key(step: "Anything", rest: true), "BELLY_BREATH")
    }

    func testSafeMediaURL() {
        XCTAssertNotNil(SafeMedia.url("https://holysteps.org/holysteps/trainers/man_3d/SQUAT.mp4", allowed: SafeMedia.videoExt))
        XCTAssertNil(SafeMedia.url("http://holysteps.org/a.mp4", allowed: SafeMedia.videoExt))
        XCTAssertNil(SafeMedia.url("https://user@holysteps.org/a.mp4", allowed: SafeMedia.videoExt))
        XCTAssertNil(SafeMedia.url("https://holysteps.org:8443/a.mp4", allowed: SafeMedia.videoExt))
        XCTAssertNil(SafeMedia.url("https://10.0.0.1/a.mp4", allowed: SafeMedia.videoExt))
        XCTAssertNil(SafeMedia.url("https://cam.local/a.mp4", allowed: SafeMedia.videoExt))
        XCTAssertNil(SafeMedia.url("https://holysteps.org/a.exe", allowed: SafeMedia.videoExt))
    }

    func testCatalogParse() {
        let json = #"{"items":[{"routineId":"hiit_power","trainer":"Kojo","title":"HIIT","credit":"","photo":"https://holysteps.org/p.jpg","video":"https://holysteps.org/v.mp4"},{"routineId":"Bad Id","photo":"https://holysteps.org/p.jpg"},{"routineId":"no_media"}]}"#
        let c = TrainerMedia.parse(Data(json.utf8))
        XCTAssertEqual(Array(c.keys), ["hiit_power"])
        XCTAssertEqual(c["hiit_power"]?.trainer, "Kojo")
    }
}
