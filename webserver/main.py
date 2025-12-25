from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import os

app = FastAPI()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("Phone connected!")
    try:
        while True:
            # Receive the raw bytes from the Flutter camera
            data = await websocket.receive_bytes()
            
            # Print the size just to confirm it's working
            print(f"Received frame: {len(data)} bytes")
            
            # TODO: Later we can use OpenCV to process 'data' 
            # or broadcast it to your HTML dashboard
    except WebSocketDisconnect:
        print("Phone disconnected")