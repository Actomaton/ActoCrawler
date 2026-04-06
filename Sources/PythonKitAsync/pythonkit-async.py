import asyncio

# Single shared event loop for all Python async work.
# All calls are serialized by PythonGIL's serial queue, so no concurrent access.
_loop = None

def _get_event_loop():
    global _loop
    if _loop is None:
        _loop = asyncio.new_event_loop()
    return _loop

async def coroutine_wrapper(coroutine, callback):
    val = await coroutine
    callback(val)

def coroutine_to_callback(coroutine, callback):
    if asyncio.iscoroutine(coroutine):
        loop = _get_event_loop()
        loop.run_until_complete(coroutine_wrapper(coroutine, callback))
    else:
        callback(coroutine) # Calls back immediately with non-coroutine object.
