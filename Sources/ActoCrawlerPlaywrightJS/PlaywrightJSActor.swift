import JavaScriptEventLoop
@preconcurrency import JavaScriptKit

/// Playwright actor wrapper that lazily resolves the injected JavaScript module.
internal actor PlaywrightJSActor
{
    private struct State
    {
        let playwright: JSObject
        let preparedObject: JSObject
    }

    private let resolvePlaywright: @Sendable () async throws -> JSObject
    private let prepare: @Sendable (_ playwright: JSObject) async throws -> JSObject
    private var state: State?

    internal init(
        resolvePlaywright: @escaping @Sendable () async throws -> JSObject = resolvePlaywrightModule,
        prepare: @escaping @Sendable (_ playwright: JSObject) async throws -> JSObject
    )
    {
        self.resolvePlaywright = resolvePlaywright
        self.prepare = prepare
    }

    internal func runCrawl<Res: Sendable>(
        _ crawl: @Sendable (
            _ playwright: JSObject,
            _ preparedObject: JSObject
        ) async throws -> Res
    ) async throws -> Res
    {
        let state = try await self.bootstrap()
        return try await crawl(state.playwright, state.preparedObject)
    }

    private func bootstrap() async throws -> State
    {
        if let state = self.state {
            return state
        }

        JavaScriptEventLoop.installGlobalExecutor()

        let playwright = try await self.resolvePlaywright()
        let preparedObject = try await self.prepare(playwright)

        let state = State(playwright: playwright, preparedObject: preparedObject)
        self.state = state
        return state
    }

    internal nonisolated var unownedExecutor: UnownedSerialExecutor
    {
        JavaScriptEventLoop.shared.asUnownedSerialExecutor()
    }
}
