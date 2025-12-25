import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:typed_data';
import 'dart:io'; // Make sure you have this import at the top!

// Global list of cameras
List<CameraDescription> cameras = [];

Future<void> main() async {
  // Add this line BEFORE runApp
  HttpOverrides.global = MyHttpOverrides();

  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
    runApp(const MyApp());
  } catch (e) {
    print("CRITICAL STARTUP ERROR: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  WebSocketChannel? _channel;
  int _currentCameraIndex = 0;
  bool _isStreaming = false;
  bool _isConnecting = false;

  // IMPORTANT: Replace this with your actual Koyeb URL
  final String _serverUrl = 'wss://alright-fredi-rotem-d2630a42.koyeb.app/ws';

  @override
  void initState() {
    super.initState();
    _initCamera(cameras[_currentCameraIndex]);
  }

  Future<void> _initCamera(CameraDescription cameraDescription) async {
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.low, // Keep low for high FPS over mobile data
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print("CAMERA ERROR: $e");
    }
  }

  void _connectWebSocket() {
    print("DEBUG: Connecting to $_serverUrl...");
    setState(() => _isConnecting = true);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_serverUrl));

      // Monitor the connection
      _channel!.stream.listen(
        (data) => print("SERVER SAYS: $data"),
        onError: (err) {
          print("WS ERROR: $err");
          _stopStreaming();
        },
        onDone: () {
          print("WS DISCONNECTED");
          _stopStreaming();
        },
      );
      print("DEBUG: WebSocket channel created successfully.");
    } catch (e) {
      print("WS CONNECTION FAILED: $e");
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _toggleStreaming() {
    if (_isStreaming) {
      _stopStreaming();
    } else {
      _startStreaming();
    }
  }

  void _startStreaming() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    _connectWebSocket();

    _controller!.startImageStream((CameraImage image) {
      if (!_isStreaming) return;

      try {
        // Send the first plane (Y bytes) to the server
        final bytes = image.planes[0].bytes;
        _channel?.sink.add(bytes);
        // Print every 30th frame to avoid log spam
        if (DateTime.now().millisecond % 30 == 0) {
          print("DEBUG: Sending ${bytes.length} bytes...");
        }
      } catch (e) {
        print("STREAMING ERROR: $e");
        _stopStreaming();
      }
    });

    setState(() => _isStreaming = true);
  }

  void _stopStreaming() {
    _controller?.stopImageStream();
    _channel?.sink.close();
    setState(() {
      _isStreaming = false;
      _channel = null;
    });
    print("DEBUG: Streaming Stopped.");
  }

  void _switchCamera() async {
    _stopStreaming();
    _currentCameraIndex = (_currentCameraIndex + 1) % cameras.length;
    await _initCamera(cameras[_currentCameraIndex]);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: CameraPreview(_controller!)),

          // Connection Status Overlay
          if (_isConnecting)
            Container(
              color: Colors.black54,
              child: const Center(child: Text("Connecting...")),
            ),

          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Stream Toggle
                FloatingActionButton(
                  heroTag: "stream",
                  backgroundColor: _isStreaming ? Colors.red : Colors.blue,
                  onPressed: _toggleStreaming,
                  child: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                ),
                // Camera Switch
                FloatingActionButton(
                  heroTag: "switch",
                  onPressed: _switchCamera,
                  child: const Icon(Icons.cameraswitch),
                ),
              ],
            ),
          ),

          // Status Indicator
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isStreaming
                    ? Colors.red.withOpacity(0.7)
                    : Colors.black45,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_isStreaming ? "LIVE" : "OFFLINE"),
            ),
          ),
        ],
      ),
    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
