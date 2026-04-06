import PythonKitAsync

/// Serial executor that runs actor jobs on ``PythonGIL``'s serial queue.
///
/// By sharing the same queue as ``PythonGIL``, all Python work — both
/// actor-isolated and ``asPyAsync()`` — runs on the same OS thread,
/// ensuring GIL safety and a consistent ``asyncio`` event loop.
internal final class PythonSerialExecutor: SerialExecutor, @unchecked Sendable
{
    static let shared = PythonSerialExecutor()

    func enqueue(_ job: consuming ExecutorJob)
    {
        let unownedJob = UnownedJob(job)
        PythonGIL.queue.async { [self] in
            PythonGIL.withGIL {
                unownedJob.runSynchronously(on: asUnownedSerialExecutor())
            }
        }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor
    {
        UnownedSerialExecutor(ordinary: self)
    }
}
