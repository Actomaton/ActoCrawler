@preconcurrency import Foundation
import ActoCrawler

/// Image scraper example using 2 crawlers: `htmlCrawler` and `imageDownloader`.
@main
struct ImageScraperExample
{
    static func main() async
    {
        struct HtmlCrawlerOutput: Sendable
        {
            let nextLinksCount: Int
        }

        struct ImageDownloaderOutput: Sendable
        {
            let savedFileURL: URL
        }

        let imageDownloader = await Crawler<ImageDownloaderOutput, Void>.withNetworkSession(
            config: CrawlerConfig(
                maxTotalRequests: 10,
                domainQueueTable: [
                    ".*": .init(maxConcurrency: 10, delay: 0.1)
                ]
            ),
            crawl: { request, urlSession in
                let fileURL = try await urlSession.downloadImage(url: request.url)
                return (
                    [] /* no next URLs */,
                    ImageDownloaderOutput(savedFileURL: fileURL)
                )
            }
        )

        let htmlCrawler = await Crawler<HtmlCrawlerOutput, Void>.htmlScraper(
            config: CrawlerConfig(
                maxTotalRequests: 10,
//                domainFilteringPolicy: .disallowedDomains(["wiki*"]),
//                domainFilteringPolicy: .allowedDomains(["wiki*"]),
                domainQueueTable: [
                    ".*": .init(maxConcurrency: 10, delay: 0.1)
                ]
            ),
            scrapeHTML: { response in
                let html = response.data
                let links = try html.select("a").map { try $0.attr("href") }
                let nextRequests = links
                    .compactMap(URL.init(string:))
                    .filter { $0.scheme != nil }
                    .map { UserRequest(url: $0) }

                // Send `imageURLs` to `imageDownloader`.
                // NOTE: `imageDownloader` queues are managed separately from `htmlCrawler`.
                let imageURLs = try html.select("img").map { try $0.attr("src") }
                    .compactMap(URL.init)
                    .filter { $0.scheme?.hasPrefix("http") == true }

                for imageURL in imageURLs {
                    let request = UserRequest(url: imageURL)
                    imageDownloader.visit(request: request)
                }

                return (
                    nextRequests,
                    HtmlCrawlerOutput(nextLinksCount: imageURLs.count)
                )
            }
        )

        htmlCrawler.visit(url: URL(string: "https://www.wikipedia.org")!)

        await withThrowingTaskGroup(of: Void.self, returning: Void.self) { group in
            group.addTask {
                for await (req, result) in imageDownloader.outputs {
                    switch result {
                    case let .success(output):
                        print("🖼️ Image Output: ✅ [\(req.order)] [d=\(req.depth)] \(req.url), savedFileURL = \(output.savedFileURL)")
                    case let .failure(error):
                        print("🖼️ Image Output: ❌ [\(req.order)] [d=\(req.depth)] \(req.url), error = \(error)")
                    }
                }

                print("Image Output Done")
            }
            group.addTask {
                for await (req, result) in htmlCrawler.outputs {
                    switch result {
                    case .success:
                        print("🌐 HTML Output: ✅ [\(req.order)] [d=\(req.depth)] \(req.url)")
                    case let .failure(error):
                        print("🌐 HTML Output: ❌ [\(req.order)] [d=\(req.depth)] \(req.url), error = \(error)")
                    }
                }

                print("🌐 HTML Output Done")
            }
        }

        print("Image directory:", savingSubDirectory())
    }
}

// MARK: - Private

extension NetworkSession
{
    fileprivate func downloadImage(url: URL) async throws -> URL
    {
        let (data, _) = try await self.data(for: URLRequest(url: url))

        let filename = url.lastPathComponent
        let dirURL = savingSubDirectory()
        return try saveData(data, dirURL: dirURL, filename: filename)
    }
}

private func saveData(_ data: Data, dirURL: URL, filename: String) throws -> URL {
    let fileURL = dirURL.appendingPathComponent(filename)
    try data.write(to: fileURL)
    return fileURL
}

private func savingSubDirectory() -> URL {
    let dirURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("ActoCrawlerExample")
    try? FileManager.default.createDirectory(
        at: dirURL,
        withIntermediateDirectories: true,
        attributes: nil
    )
    return dirURL
    }
