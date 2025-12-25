import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:typed_data';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: CameraScreen());
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  int _currentCameraIndex = 0;
  Future<void>? _initializeControllerFuture;
  bool _isStreaming = false;

  // REPLACE THIS with your actual Koyeb URL
  final _channel = WebSocketChannel.connect(
    Uri.parse('wss://alright-fredi-rotem-d2630a42.koyeb.app/ws'),
  );

  @override
  void initState() {
    super.initState();
    _setupCamera(cameras[_currentCameraIndex]);
  }

  Future<void> _setupCamera(CameraDescription cameraDescription) async {
    // 1. Dispose previous controller if it exists
    if (_controller != null) {
      await _controller!.dispose();
    }

    // 2. Create new controller (ResolutionPreset.medium is safer for web streaming)
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    // 3. Initialize and refresh UI
    _initializeControllerFuture = _controller!.initialize();
    await _initializeControllerFuture;

    if (mounted) setState(() {});
  }

  void _switchCamera() async {
    // If we are currently streaming, stop it before switching
    if (_isStreaming) {
      _toggleStreaming();
    }

    _currentCameraIndex = (_currentCameraIndex + 1) % cameras.length;
    await _setupCamera(cameras[_currentCameraIndex]);
  }

  void _toggleStreaming() {
    setState(() {
      _isStreaming = !_isStreaming;
    });

    if (_isStreaming) {
      // Start the live feed to the server
      _controller!.startImageStream((CameraImage image) {
        if (!_isStreaming) return;

        // Sending the first plane (Y/Luminance) as a basic test of connectivity
        // This is the fastest way to stream without heavy conversion logic
        Uint8List bytes = image.planes[0].bytes;
        _channel.sink.add(bytes);
      });
    } else {
      _controller!.stopImageStream();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _channel.sink.close(); // Important: Close the socket when the app closes
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Display the camera feed
                Center(child: CameraPreview(_controller!)),

                // Stream Toggle Button (Bottom Left)
                Positioned(
                  bottom: 30,
                  left: 30,
                  child: FloatingActionButton(
                    backgroundColor: _isStreaming ? Colors.red : Colors.blue,
                    onPressed: _toggleStreaming,
                    child: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                  ),
                ),

                // Switch Camera Button (Bottom Right)
                Positioned(
                  bottom: 30,
                  right: 30,
                  child: FloatingActionButton(
                    onPressed: _switchCamera,
                    child: const Icon(Icons.cameraswitch),
                  ),
                ),
              ],
            ),
    );
  }
}
