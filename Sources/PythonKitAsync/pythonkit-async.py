import asyncio

async def coroutine_wrapper(coroutine, callback):
    val = await coroutine
    callback(val)

def coroutine_to_callback(coroutine, callback):
    if asyncio.iscoroutine(coroutine):
        loop = asyncio.get_event_loop()
        loop.run_until_complete(coroutine_wrapper(coroutine, callback))
    else:
        callback(coroutine) # Calls back immediately with non-coroutine object.
