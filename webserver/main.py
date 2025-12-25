from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
import os

app = FastAPI()

# 1. Store connections (for your 3 users)
class ConnectionManager:
    def __init__(self):
        self.active_connections = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

manager = ConnectionManager()

@app.get("/")
async def get():
    # Detect the public URL (Koyeb doesn't give a dedicated IP, it gives a domain)
    # On Koyeb, the 'KOYEB_PUBLIC_DOMAIN' env var usually holds your URL
    public_url = os.environ.get("KOYEB_PUBLIC_DOMAIN", "localhost:8000")
    
    html_content = f"""
    <html>
        <body>
            <h1>WebSocket Server Active</h1>
            <p>On your phone app, connect to: <br>
               <strong>wss://{public_url}/ws</strong></p>
            <div id="status">Waiting for data...</div>
            <script>
                const ws = new WebSocket("wss://{public_url}/ws");
                ws.onmessage = (event) => {{
                    document.getElementById('status').innerText = "Last received: " + event.data;
                }};
            </script>
        </body>
    </html>
    """
    return HTMLResponse(content=html_content)

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            # A. This will receive data from your phone
            # For now, it's just text. Later, this will be your camera bytes.
            data = await websocket.receive_text()
            
            # Optionally broadcast it back to see it on your dashboard
            await websocket.send_text(f"Server received: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)

@app.get("/healthz")
async def health():
    return {{"status": "ok"}}