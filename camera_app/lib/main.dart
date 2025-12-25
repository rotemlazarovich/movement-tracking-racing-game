import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/io.dart';

void main() async {
  // CRITICAL: This line prevents the "Isolate" crash
  WidgetsFlutterBinding.ensureInitialized();

  // Get cameras before starting the app
  final cameras = await availableCameras();

  runApp(MaterialApp(home: CameraScreen(cameras: cameras)));
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  IOWebSocketChannel? _channel;
  bool _isStreaming = false;

  @override
  void initState() {
    super.initState();
    _initializeFrontCamera();
    _channel = IOWebSocketChannel.connect(
      Uri.parse('wss://alright-fredi-rotem-d2630a42.koyeb.app/ws'),
    );
  }

  Future<void> _initializeFrontCamera() async {
    // Look for the front camera specifically
    final frontCamera = widget.cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  void _toggleStreaming() {
    if (_isStreaming) {
      _controller?.stopImageStream();
      setState(() => _isStreaming = false);
      print("STREAM STOPPED");
    } else {
      setState(() => _isStreaming = true);
      print("STREAM STARTED");

      _controller?.startImageStream((CameraImage image) {
        // ONLY send if the channel is actually open
        if (_channel != null && _isStreaming) {
          try {
            // Grab the bytes
            final bytes = image.planes[0].bytes;

            // SEND DATA
            _channel!.sink.add(bytes);

            // Add this print so you can SEE it working in VS Code
            // If you see this but nothing on Koyeb, the URL is the problem.
            print("Sent frame: ${bytes.length} bytes");
          } catch (e) {
            print("Error sending: $e");
          }
        }
      });
    }
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
      appBar: AppBar(title: const Text("Front Camera Only")),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: FloatingActionButton(
                onPressed: _toggleStreaming,
                child: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
