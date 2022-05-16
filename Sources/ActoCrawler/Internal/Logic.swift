@preconcurrency import Foundation
import Actomaton
import ActomatonDebugging

// MARK: - Action

enum Action<Output, URLInfo>: Sendable
    where Output: Sendable, URLInfo: Sendable
{
    case visit([UserRequest<URLInfo>])
    case _visit(Request<URLInfo>)
    case _didVisit(Request<URLInfo>, nextRequests: [UserRequest<URLInfo>], output: Output)
    case _didFailVisit(Request<URLInfo>, CrawlError)
}

// MARK: - State

struct State: Sendable
{
    var waitingURLs: Set<URL> = []

    /// Total count of "waiting" + "visited" + "failed" URLs.
    var totalVisitCount: UInt64 = 0
}

// MARK: - Reducer

func reducer<Output, URLInfo>() -> Reducer<Action<Output, URLInfo>, State, Environment<Output, URLInfo>>
    where Output: Sendable, URLInfo: Sendable
{
    typealias Eff = Effect<Action<Output, URLInfo>>

    return Reducer { action, state, env in
        /// Common logic to update `state`, output to channel & dispatch next visits.
        func didFinish(
            request: Request<URLInfo>?,
            nextRequests: [UserRequest<URLInfo>],
            outputResult: Result<Output, CrawlError>?
        ) -> Eff
        {
            // Remove from `waitingURLs`.
            if let request = request {
                state.waitingURLs.remove(request.url)
            }

            // Limit `nextRequests` by checking `config.maxTotalRequests`.
            let totalVisitCount = state.totalVisitCount
            let remainingVisitCount = max(env.config.maxTotalRequests - totalVisitCount, 0)
            let nextRequests = nextRequests.prefix(Int(clamping: remainingVisitCount))

            // Insert next "waiting"s.
            for nextRequest in nextRequests {
                state.waitingURLs.insert(nextRequest.url)
            }

            let isFinished = state.waitingURLs.isEmpty && nextRequests.isEmpty

            /// AsyncChannel effect.
            let sendToChannel = Eff.fireAndForget {
                // NOTE: `outputResult = nil` is passed only on initial crawl.
                if let request = request, let outputResult = outputResult {
                    await env.events.send(.didCrawl(request, outputResult))
                }
                if isFinished {
                    env.events.finish()
                }
            }

            let depth = request?.depth ?? 0

            /// nextCrawls effect.
            let nextCrawls = nextRequests.isEmpty || depth >= env.config.maxDepths
                ? .empty
                : Eff.combine( // Visit next with incrementing `depth`.
                    nextRequests.enumerated()
                        .map { i, userReq in
                            let request = Request<URLInfo>(
                                url: userReq.url,
                                urlInfo: userReq.urlInfo,
                                order: totalVisitCount + UInt64(i),
                                depth: depth + 1
                            )
                            return .nextAction(._visit(request))
                        }
                )

            state.totalVisitCount += UInt64(nextRequests.count)

            return sendToChannel + nextCrawls
        }

        // Reducer pattern-matching.
        switch action {
        case let .visit(requests):
            // NOTE:
            // This is a fake `didFinish` to reuse calculation of `state.waitingURLs` etc by only sending `nextRequests`.
            return didFinish(
                request: nil,
                nextRequests: requests,
                outputResult: nil
            )

        case let ._visit(request):
            let host = request.url.host ?? ""

            let isAllowed = env.config.domainFilteringPolicy.isDomainAllowed(for: host)
            guard isAllowed else {
                return .nextAction(
                    ._didFailVisit(request, CrawlError.domainNotAllowed(host))
                )
            }

            let queue = env.config.domainQueueTable.buildQueue(url: request.url)

            return Effect(queue: queue) {
                // Check if `queue` has already force-cancelled this effect.
                // This is important when using `EffectQueue` with delay.
                try Task.checkCancellation()

                await env.events.send(.willCrawl(request))

                do {
                    let (nextRequests, output) = try await env.crawl(request)
                    return ._didVisit(request, nextRequests: nextRequests, output: output)
                }
                catch {
                    return ._didFailVisit(request, CrawlError.crawlFailed(error))
                }
            }

        case let ._didVisit(request, nextRequests, output):
            return didFinish(
                request: request,
                nextRequests: nextRequests,
                outputResult: .success(output)
            )

        case let ._didFailVisit(request, error):
            return didFinish(
                request: request,
                nextRequests: [],
                outputResult: .failure(error)
            )
        }
    }
}
