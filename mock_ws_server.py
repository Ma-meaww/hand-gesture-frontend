import asyncio
import json
import time
import websockets

async def handler(websocket):
    print("Client connected")

    try:
        async for message in websocket:
            print("Received:", message)

            try:
                data = json.loads(message)
                command = data.get("command", "UNKNOWN")
            except Exception:
                command = "INVALID_JSON"

            ack = {
                "type": "ack",
                "status": "success",
                "command": command,
                "message": f"Mock received {command}",
                "latency_ms": 180,
            }

            await websocket.send(json.dumps(ack))
            print("Sent ACK:", ack)

    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")

async def main():
    async with websockets.serve(handler, "0.0.0.0", 8765):
        print("Mock WebSocket Server running on ws://0.0.0.0:8765")
        await asyncio.Future()

asyncio.run(main())