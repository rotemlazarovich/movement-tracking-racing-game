from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
import os

app = FastAPI()

# A simple list to keep track of connected phones/browsers
class ConnectionManager:
    def __init__(self):
        self.active_connections = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

manager = ConnectionManager()

# 1. THE HOME PAGE (Visiting your URL in a browser)
@app.get("/")
async def get():
    return {
        "status": "Server is Online",
        "instructions": "Connect your Flutter app to /ws",
        "websocket_url": "wss://your-koyeb-app-name.koyeb.app/ws"
    }

# 2. THE WEBSOCKET (Where the phone sends data)
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    # This will show up in Koyeb when your phone connects
    print(f"DEBUG: Phone connected from {websocket.client.host}") 
    
    try:
        while True:
            # Receive the image bytes from Flutter
            data = await websocket.receive_bytes()
            
            # Print the size of every frame received
            # (If this scrolls fast, you know the data is flowing!)
            print(f"DEBUG: Received frame - Size: {len(data)} bytes")
            
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        print("DEBUG: Phone disconnected")

# 3. HEALTH CHECK (Required for Koyeb to keep the app running)
@app.get("/healthz")
async def health():
    return {"status": "ok"}

if __name__ == "__main__":
    import uvicorn
    # Koyeb provides the PORT environment variable automatically
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)