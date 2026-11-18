import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RedlineApp());
}

class RedlineApp extends StatelessWidget {
  const RedlineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REDLINE Camera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101214),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD64A3B),
          surface: Color(0xFF202428),
        ),
        useMaterial3: true,
      ),
      home: const CameraHome(),
    );
  }
}

class CameraHome extends StatefulWidget {
  const CameraHome({super.key});

  @override
  State<CameraHome> createState() => _CameraHomeState();
}

class _CameraHomeState extends State<CameraHome> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraDescription? _selectedCamera; // survives backgrounding and failed switches
  bool _inForeground = true;
  bool _initialising = true;
  bool _capturing = false;
  String _status = 'INITIALISING CAMERA';
  String _mode = 'AUTO';
  String? _lastCapture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialiseCamera();
  }

  String _lensLabel(CameraDescription camera) {
    switch (camera.lensDirection) {
      case CameraLensDirection.front:
        return 'FRONT';
      case CameraLensDirection.back:
        return 'BACK';
      case CameraLensDirection.external:
        return 'EXTERNAL';
    }
  }

  /// Single place where controllers are built, so every camera uses the
  /// same resolution and JPEG output (the saved file is always named .jpg).
  Future<CameraController> _createController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    return controller;
  }

  /// Opens [camera]. Throws on failure; callers decide how to report it.
  Future<void> _startCamera(CameraDescription camera) async {
    if (mounted) setState(() => _initialising = true);
    final controller = await _createController(camera);

    // The app may have been closed or backgrounded while we were opening.
    if (!mounted || !_inForeground) {
      await controller.dispose();
      if (mounted) setState(() => _initialising = false);
      return;
    }

    setState(() {
      _controller = controller;
      _selectedCamera = camera;
      _initialising = false;
      _status = 'AUTO EXPOSURE · AUTO WHITE BALANCE';
    });
  }

  Future<void> _initialiseCamera() async {
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera is available on this device.');
      }

      final camera = _selectedCamera ??
          _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras.first,
          );
      await _startCamera(camera);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initialising = false;
        _status = 'CAMERA ERROR: ${error.description ?? error.code}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialising = false;
        _status = 'UNABLE TO START CAMERA: $error';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) return;

    setState(() => _capturing = true);
    try {
      final image = await controller.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final redlineDir = Directory('${directory.path}/REDLINE');
      await redlineDir.create(recursive: true);

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final destination = '${redlineDir.path}/REDLINE_$timestamp.jpg';
      await File(image.path).copy(destination);

      if (!mounted) return;
      setState(() {
        _lastCapture = destination;
        _status = 'CAPTURE SAVED · ORIGINAL JPEG';
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() => _status = 'CAPTURE FAILED: ${error.description ?? error.code}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'SAVE FAILED: $error');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _switchCamera() async {
    final current = _controller;
    if (_cameras.length < 2 || _capturing || _initialising || current == null) return;

    final previous = current.description;
    final next = _cameras.firstWhere(
      (c) => c.lensDirection != previous.lensDirection,
      orElse: () {
        final i = _cameras.indexWhere((c) => c.name == previous.name);
        return _cameras[(i + 1) % _cameras.length];
      },
    );

    // Drop the reference before disposing so the preview never renders,
    // and capture never uses, a disposed controller.
    setState(() {
      _controller = null;
      _initialising = true;
      _status = 'SWITCHING CAMERA';
    });
    await current.dispose();

    try {
      await _startCamera(next);
    } catch (error) {
      // Fall back to the lens that was working.
      try {
        await _startCamera(previous);
        if (mounted) {
          setState(() => _status = 'LENS SWITCH FAILED · KEPT ${_lensLabel(previous)} CAMERA');
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _controller = null;
          _initialising = false;
          _status = 'LENS SWITCH FAILED: $error';
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _inForeground = false;
      final controller = _controller;
      if (controller == null) return;
      setState(() => _controller = null);
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _inForeground = true;
      // Previously this returned early because _controller was null,
      // so the camera never came back. Reopen the last-used lens.
      if (_controller == null && !_initialising) _initialiseCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFF08090A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _initialising
                    ? const Center(child: CircularProgressIndicator())
                    : controller != null && controller.value.isInitialized
                        ? CameraPreview(controller)
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_status, textAlign: TextAlign.center),
                            ),
                          ),
              ),
            ),
            _statusPanel(),
            _controls(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: Row(
          children: [
            const Icon(Icons.camera_alt_outlined, color: Color(0xFFD64A3B)),
            const SizedBox(width: 9),
            const Text(
              'REDLINE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2.4),
            ),
            const Spacer(),
            Text(_mode, style: const TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            const Icon(Icons.auto_awesome, color: Color(0xFFD64A3B), size: 18),
          ],
        ),
      );

  Widget _statusPanel() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_status, style: const TextStyle(fontSize: 10, letterSpacing: 1.1, color: Colors.white70)),
            const SizedBox(height: 5),
            Row(
              children: [
                Text(_mode, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Text(
                  'LENS: ${_selectedCamera == null ? '-' : _lensLabel(_selectedCamera!)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(width: 12),
                const Text('FORMAT: JPEG', style: TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            if (_mode == 'PRO')
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('Manual controls are not built yet (milestone M2).',
                    style: TextStyle(color: Colors.white54, fontSize: 10)),
              ),
            if (_lastCapture != null)
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('Last capture saved in REDLINE app storage.',
                    style: TextStyle(color: Color(0xFF9DB9A4), fontSize: 10)),
              ),
          ],
        ),
      );

  Widget _controls() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _switchCamera,
              icon: const Icon(Icons.flip_camera_ios_outlined),
              iconSize: 27,
              tooltip: 'Switch camera',
            ),
            GestureDetector(
              onTap: _capturing ? null : _capture,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD64A3B),
                    ),
                    child: _capturing
                        ? const Padding(
                            padding: EdgeInsets.all(18),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _mode = _mode == 'AUTO' ? 'PRO' : 'AUTO'),
              icon: const Icon(Icons.tune),
              iconSize: 27,
              tooltip: 'Toggle camera mode',
            ),
          ],
        ),
      );
}
