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
}
