from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
import os

app = FastAPI()

# List to keep track of the (up to 3) active users
active_connections = []

@app.get("/")
async def get():
    # This serves your HTML file (see step 2)
    with open("index.html") as f:
        return HTMLResponse(f.read())

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            # Wait for a message from one user
            data = await websocket.receive_text()
            # Send it to EVERYONE currently connected
            for connection in active_connections:
                await connection.send_text(f"User says: {data}")
    except WebSocketDisconnect:
        active_connections.remove(websocket)

if __name__ == "__main__":
    import uvicorn
    # Koyeb provides the PORT environment variable
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)