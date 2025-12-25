from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# Add this to allow your phone to talk to the server
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def home():
    return {"status": "HTTP is working"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("PHONE CONNECTED!")
    try:
        while True:
            data = await websocket.receive_bytes()
            # This is where your image data arrives
    except Exception as e:
        print(f"Disconnected: {e}")