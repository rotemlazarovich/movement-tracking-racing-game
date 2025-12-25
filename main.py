from fastapi import FastAPI, WebSocket
import uvicorn
import os
import numpy as np
import cv2

app = FastAPI()

@app.get("/")
def home():
    return {"status": "Server is receiving data"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("PHONE CONNECTED")
    try:
        while True:
            # 1. Receive raw bytes from Flutter
            data = await websocket.receive_bytes()
            
            # 2. Convert bytes to a format OpenCV understands
            # Note: Since we are sending image.planes[0].bytes (Y-plane), 
            # this will show up as a Grayscale image.
            nparr = np.frombuffer(data, np.uint8)
            
            # 3. Log the receipt
            print(f"Received frame! Size: {len(data)} bytes")

            # NOTE: On a cloud server like Koyeb, you cannot "pop up" a window (cv2.imshow).
            # Instead, we will save the last received frame as a file to prove it works.
            # cv2.imwrite("latest_frame.jpg", nparr)
            
    except Exception as e:
        print(f"Disconnected: {e}")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port, ws="websockets")