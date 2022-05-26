import PythonKit

// NOTE: 
private let pythonKitAsync = Python.import("pythonkit-async")

extension PythonObject
{
    /// Converts `self` as Python's coroutine (`async def`) object into Swift async function.
    /// - Important: `self` must be Python coroutine object to run properly. Otherwise, async-returned value will be `self`.
    @discardableResult
    public func asPyAsync() async -> PythonObject
    {
        let pyObj: PythonObject = await withCheckedContinuation { continuation in
            // NOTE: Uses `pythonkit-async.py`'s `coroutine_to_callback`.
            pythonKitAsync.coroutine_to_callback(self, PythonFunction { (arg: PythonObject) in
                continuation.resume(returning: arg)
                return 0
            })
        }

        // NOTE: Required to run other concurrent coroutines.
        await Task.yield()

        return pyObj
    }
}
