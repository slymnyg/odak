import XCTest
@testable import Odak

final class DomainParserTests: XCTestCase {
    func testStripsSchemePathQueryAndFragment() {
        XCTAssertEqual(DomainParser.normalize("https://www.youtube.com/watch?v=abc#t=1"), "youtube.com")
    }

    func testStripsUserInfoAndPort() {
        XCTAssertEqual(DomainParser.normalize("http://user:pass@news.example.org:8080/path"), "news.example.org")
    }

    func testStripsWildcardAndMirrorPrefixes() {
        XCTAssertEqual(DomainParser.normalize("*.reddit.com"), "reddit.com")
        XCTAssertEqual(DomainParser.normalize("m.facebook.com"), "facebook.com")
        XCTAssertEqual(DomainParser.normalize("mobile.twitter.com"), "twitter.com")
    }

    func testKeepsPrefixWhenItIsTheRegistrableName() {
        XCTAssertEqual(DomainParser.normalize("mobile.de"), "mobile.de")
        XCTAssertEqual(DomainParser.normalize("m.tv"), "m.tv")
    }

    func testLowercasesAndDropsTrailingDot() {
        XCTAssertEqual(DomainParser.normalize("YouTube.COM."), "youtube.com")
    }

    func testRejectsInvalidHosts() {
        XCTAssertNil(DomainParser.normalize("localhost"))
        XCTAssertNil(DomainParser.normalize("192.168.1.1"))
        XCTAssertNil(DomainParser.normalize("-bad.com"))
        XCTAssertNil(DomainParser.normalize("bad-.com"))
        XCTAssertNil(DomainParser.normalize("exa_mple.com"))
        XCTAssertNil(DomainParser.normalize("a..b.com"))
        XCTAssertNil(DomainParser.normalize("bad;rm.com"))
        XCTAssertNil(DomainParser.normalize("ünicode.com"))
        XCTAssertNil(DomainParser.normalize(String(repeating: "a", count: 64) + ".com"))
    }

    func testParsesMixedSeparatorsAndDedupes() {
        let text = """
        youtube.com, https://www.youtube.com/feed
        x.com;twitter.com   reddit.com
        not a domain
        """
        XCTAssertEqual(DomainParser.parse(text), ["youtube.com", "x.com", "twitter.com", "reddit.com"])
    }

    func testExpandsMirrors() {
        XCTAssertEqual(
            DomainParser.expand(["x.com"]),
            ["x.com", "www.x.com", "m.x.com", "mobile.x.com"]
        )
    }

    func testExpansionSkipsHostsThatWouldBeTooLong() {
        let label = String(repeating: "a", count: 60)
        let long = [label, label, label, label, "com"].joined(separator: ".")
        XCTAssertTrue(DomainParser.isValid(long))
        XCTAssertEqual(DomainParser.expand([long]), [long, "www." + long, "m." + long])
    }

    func testBlockedDomainCoversSubdomainsOnly() {
        let domains = ["youtube.com", "x.com"]
        XCTAssertEqual(DomainParser.blockedDomain(forURL: "https://www.youtube.com/watch?v=1", in: domains), "youtube.com")
        XCTAssertEqual(DomainParser.blockedDomain(forURL: "https://music.youtube.com/", in: domains), "youtube.com")
        XCTAssertEqual(DomainParser.blockedDomain(forURL: "HTTP://X.COM./home", in: domains), "x.com")
        XCTAssertNil(DomainParser.blockedDomain(forURL: "https://notyoutube.com/", in: domains))
        XCTAssertNil(DomainParser.blockedDomain(forURL: "https://netflix.com/?next=x.com", in: domains))
        XCTAssertNil(DomainParser.blockedDomain(forURL: "https://example.com/youtube.com", in: domains))
        XCTAssertNil(DomainParser.blockedDomain(forURL: "file:///Applications/Odak.app/blocked.html#youtube.com", in: domains))
        XCTAssertNil(DomainParser.blockedDomain(forURL: "chrome://newtab/", in: domains))
    }

    func testBlockedPageCarriesTheDomain() throws {
        let page = try XCTUnwrap(BrowserBlocker.blockedPage(for: "youtube.com"))
        XCTAssertTrue(page.hasPrefix("file://"))
        XCTAssertTrue(page.hasSuffix("blocked.html#youtube.com"))
        XCTAssertNil(DomainParser.blockedDomain(forURL: page, in: ["youtube.com"]))
    }

    func testBlockedPageContextSortsAndMarksTasks() {
        let now = Date(timeIntervalSince1970: 1_794_300_000)
        func task(_ title: String, _ from: TimeInterval, _ to: TimeInterval, _ lane: TaskLane) -> PlannedTask {
            PlannedTask(title: title, note: "", start: now.addingTimeInterval(from), end: now.addingTimeInterval(to), lane: lane)
        }
        let context = BlockedPage.context(
            intention: "  Ship the dial \n",
            tasks: [task("Later", 3600, 7200, .meeting), task("Earlier", -7200, -3600, .personal), task("Current", -600, 1800, .focus)],
            now: now
        )
        XCTAssertEqual(context.intention, "Ship the dial")
        XCTAssertEqual(context.tasks.map(\.title), ["Earlier", "Current", "Later"])
        XCTAssertEqual(context.tasks.map(\.state), [.done, .now, .next])
        XCTAssertEqual(context.tasks.map(\.lane), ["personal", "focus", "meeting"])
    }

    func testBlockedPageHTMLCannotBreakOutOfItsScript() {
        let context = BlockedPage.Context(
            intention: "</script><img src=x onerror=alert(1)>",
            tasks: [.init(title: "a & b", time: "09:00", lane: "focus", state: .next)]
        )
        let html = BlockedPage.html(template: "<script>var data = \(BlockedPage.placeholder);</script>", context: context)
        XCTAssertFalse(html.contains("</script><img"))
        XCTAssertFalse(html.contains(BlockedPage.placeholder))
        XCTAssertTrue(html.contains("\\u003c\\/script\\u003e") || html.contains("\\u003c/script\\u003e"))
        XCTAssertTrue(html.hasSuffix(";</script>"))
    }

    func testBundledBlockedPageHasThePlaceholder() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "blocked", withExtension: "html"))
        XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains(BlockedPage.placeholder))
    }
}
