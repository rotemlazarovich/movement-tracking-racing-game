from fastapi import FastAPI, WebSocket
import uvicorn
import os

app = FastAPI()

@app.get("/")
def home():
    return {"status": "HTTP is working"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("CONNECTION SUCCESSFUL")
    try:
        while True:
            data = await websocket.receive_bytes()
            print(f"Received {len(data)} bytes")
    except Exception as e:
        print(f"Disconnected: {e}")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port, ws="websockets")