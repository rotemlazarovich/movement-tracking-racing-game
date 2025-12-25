from fastapi import FastAPI, WebSocket, Response
from fastapi.responses import StreamingResponse
import uvicorn
import os

app = FastAPI()

# Global variable to store the latest frame bytes
latest_frame = None

@app.get("/")
def home():
    return {"status": "Video Relay Server is Live"}

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    global latest_frame
    print("PHONE CONNECTED")
    try:
        while True:
            # Receive the raw bytes from the phone
            data = await websocket.receive_bytes()
            latest_frame = data  # Update the global frame
            # We don't print every frame to avoid clogging the logs
    except Exception as e:
        print(f"Disconnected: {e}")

# This is the "Webcam" feed for your browser
def frame_generator():
    global latest_frame
    while True:
        if latest_frame is not None:
            # Format the bytes into a multipart stream for the browser
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + latest_frame + b'\r\n')

@app.get("/video_feed")
async def video_feed():
    return StreamingResponse(frame_generator(), 
                             media_type="multipart/x-mixed-replace; boundary=frame")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)