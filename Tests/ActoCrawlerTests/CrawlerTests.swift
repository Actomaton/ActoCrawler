import XCTest
import Foundation
@testable import ActoCrawler

final class CrawlerTests: XCTestCase
{
    func testVisitEmitsSuccessEvent() async throws
    {
        struct Output: Equatable, Sendable
        {
            let url: String
        }

        let crawler = Crawler<Output, Void>(
            config: CrawlerConfig(
                maxTotalRequests: 1,
                domainQueueTable: [
                    ".*": .init(maxConcurrency: 1, delay: 0)
                ]
            ),
            dependency: (),
            crawl: { request, _ in
                ([], Output(url: request.url.absoluteString))
            }
        )

        crawler.visit(url: URL(string: "https://example.com")!)

        var seenWillCrawl = false
        var seenOutput: Output?

        for await event in crawler.events {
            switch event {
            case let .willCrawl(request):
                seenWillCrawl = (request.url.absoluteString == "https://example.com")

            case let .didCrawl(_, result):
                switch result {
                case let .success(output):
                    seenOutput = output
                case let .failure(error):
                    XCTFail("unexpected failure: \(error)")
                }
            }
        }

        XCTAssertTrue(seenWillCrawl)
        XCTAssertEqual(seenOutput, Output(url: "https://example.com"))
    }
}
