import XCTest
@testable import Odak

@MainActor
final class FocusTimerTests: XCTestCase {
    private final class Clock {
        var now = Date(timeIntervalSince1970: 1_700_000_000)

        func advance(_ seconds: TimeInterval) {
            now += seconds
        }
    }

    private func makeTimer() -> (FocusTimer, Clock) {
        let clock = Clock()
        return (FocusTimer(now: { clock.now }), clock)
    }

    func testStartRunsForTheRequestedDuration() {
        let (timer, _) = makeTimer()
        timer.start(.focus, minutes: 25)
        XCTAssertEqual(timer.status, .running)
        XCTAssertEqual(timer.remaining, 25 * 60)
    }

    func testTickCountsDownWithoutCompleting() {
        let (timer, clock) = makeTimer()
        timer.start(.focus, minutes: 1)
        clock.advance(20)
        XCTAssertNil(timer.tick())
        XCTAssertEqual(timer.remaining, 40)
    }

    func testCompletionIsReportedOnceEvenAfterSleep() throws {
        let (timer, clock) = makeTimer()
        let start = clock.now
        timer.start(.focus, minutes: 1)
        clock.advance(3600)

        let completion = try XCTUnwrap(timer.tick())
        XCTAssertEqual(completion.phase, .focus)
        XCTAssertEqual(completion.startedAt, start)
        XCTAssertEqual(completion.endedAt, start + 60)
        XCTAssertEqual(timer.status, .idle)
        XCTAssertEqual(timer.completedFocusSessions, 1)
        XCTAssertNil(timer.tick())
    }

    func testPauseFreezesAndResumeExtendsTheEnd() throws {
        let (timer, clock) = makeTimer()
        timer.start(.focus, minutes: 1)
        clock.advance(10)
        timer.pause()
        clock.advance(300)
        XCTAssertNil(timer.tick())
        XCTAssertEqual(timer.remaining, 50)

        timer.resume()
        clock.advance(49)
        XCTAssertNil(timer.tick())
        clock.advance(1)
        let completion = try XCTUnwrap(timer.tick())
        XCTAssertEqual(completion.pausedDuration, 300)
        XCTAssertEqual(completion.activeDuration, 60)
    }

    func testStopReturnsToIdleFocus() {
        let (timer, _) = makeTimer()
        timer.start(.shortBreak, minutes: 5)
        timer.stop()
        XCTAssertEqual(timer.status, .idle)
        XCTAssertEqual(timer.phase, .focus)
        XCTAssertNil(timer.endsAt)
    }

    func testLongBreakEveryFourthSession() {
        let (timer, clock) = makeTimer()
        var breaks: [FocusTimer.Phase] = []
        for _ in 0..<4 {
            timer.start(.focus, minutes: 1)
            clock.advance(60)
            timer.tick()
            breaks.append(timer.nextBreak(longBreakEvery: 4))
        }
        XCTAssertEqual(breaks, [.shortBreak, .shortBreak, .shortBreak, .longBreak])
    }

    func testBreaksDoNotCountAsFocusSessions() {
        let (timer, clock) = makeTimer()
        timer.start(.shortBreak, minutes: 1)
        clock.advance(60)
        XCTAssertEqual(timer.tick()?.phase, .shortBreak)
        XCTAssertEqual(timer.completedFocusSessions, 0)
    }

    func testCountdownFormatting() {
        XCTAssertEqual(Countdown.string(for: 25 * 60), "25:00")
        XCTAssertEqual(Countdown.string(for: 59.2), "01:00")
        XCTAssertEqual(Countdown.string(for: 3725), "1:02:05")
        XCTAssertEqual(Countdown.minutesRemaining(for: 61), 2)
    }
}
