import Foundation
import Actomaton

/// Crawler `EffectQueue` to run on Actomaton.
/// - Note: This hashable identity is distinguishable per `domain`.
struct CrawlQueue: EffectQueueProtocol
{
    private let domain: Domain?
    private let maxConcurrency: Int
    let effectQueueDelay: EffectQueueDelay

    private init(
        domain: Domain?,
        maxConcurrency: Int,
        delay: EffectQueueDelay
    )
    {
        self.domain = domain
        self.maxConcurrency = maxConcurrency
        self.effectQueueDelay = delay
    }

    init(
        domain: Domain,
        maxConcurrency: Int,
        delay: EffectQueueDelay
    )
    {
        self.domain = domain
        self.maxConcurrency = maxConcurrency
        self.effectQueueDelay = delay
    }

    static var `default`: CrawlQueue
    {
        CrawlQueue(domain: nil, maxConcurrency: .max, delay: .constant(0))
    }

    var effectQueuePolicy: EffectQueuePolicy
    {
        .runOldest(maxCount: self.maxConcurrency, .suspendNew)
    }

    func hash(into hasher: inout Hasher)
    {
        hasher.combine(self.domain)
    }
}
