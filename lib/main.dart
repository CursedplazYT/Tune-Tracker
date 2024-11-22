import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'helper/audio_classification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const AudioClassificationApp());
}

class AudioClassificationApp extends StatelessWidget {
  const AudioClassificationApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Audio Classification',
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Audio classification'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  bool isRunning = false;
  Duration duration = const Duration();
  late Ticker _ticker;
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool isRecording = false;
  String audioFilePath = '';
  int secondsCounter = 0;
  bool activated = false;
  StreamSubscription<Map<dynamic, dynamic>>? recognitionStream;

  static const platform =
      MethodChannel('org.tensorflow.audio_classification/audio_record');

  // The YAMNet/classifier model used in this code example accepts data that
  // represent single-channel, or mono, audio clips recorded at 16kHz in 2.752
  // second clips (44032 samples).
  static const _sampleRate = 16000; // 16kHz
  static const _expectAudioLength = 2752; // milliseconds
  final int _requiredInputBuffer =
      (16000 * (_expectAudioLength / 1000)).toInt();
  late AudioClassificationHelper _helper;
  List<MapEntry<String, double>> _classification = List.empty();
  Timer? _timer;

  @override
  initState() {
    initTicker();
    _initializeRecorder();
    _initRecorder();
    super.initState();
  }

  void initTicker() {
    _ticker = createTicker((elapsed) {
      if (isRunning) {
        setState(() {
          duration += const Duration(seconds: 1);
        });
        secondsCounter += 1;
        if (secondsCounter >= 1800) {
          _restartRecording();
          secondsCounter = 0;
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
    _timer?.cancel();

    _closeRecorder();
  }

  void _startRecorder() {
    try {
      platform.invokeMethod('startRecord');
    } on PlatformException catch (e) {
      log("Failed to start record: '${e.message}'.");
    }
  }

  Future<bool> _requestPermission() async {
    try {
      return await platform.invokeMethod('requestPermissionAndCreateRecorder', {
        "sampleRate": _sampleRate,
        "requiredInputBuffer": _requiredInputBuffer
      });
    } on Exception catch (e) {
      log("Failed to create recorder: '${e.toString()}'.");
      return false;
    }
  }

  Future<Float32List> _getAudioFloatArray() async {
    var audioFloatArray = Float32List(0);
    try {
      final Float32List result =
          await platform.invokeMethod('getAudioFloatArray');
      audioFloatArray = result;
    } on PlatformException catch (e) {
      log("Failed to get audio array: '${e.message}'.");
    }
    return audioFloatArray;
  }

  Future<void> _closeRecorder() async {
    try {
      await platform.invokeMethod('closeRecorder');
      _helper.closeInterpreter();
    } on PlatformException {
      log("Failed to close recorder.");
    }
  }

  Future<void> _initRecorder() async {
    _helper = AudioClassificationHelper();
    await _helper.initHelper();
    bool success = await _requestPermission();
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio recording permission granted!')),
      );
    } else {
      // show error here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio recording permission denied!')),
      );
    }
  }

  Future<void> _initializeRecorder() async {
    await Permission.microphone.request();
    await _recorder.openAudioSession();
    Directory tempDir = await getTemporaryDirectory();
    audioFilePath = '${tempDir.path}/audio.aac';
  }

  void _startTimer() {
    if (!_ticker.isActive) {
      _ticker.start();
    }

    setState(() {
      isRunning = true;
    });
  }

  void _stopTimer() {
    _ticker.stop();
    setState(() {
      isRunning = false;
    });
  }

  void _resetTimer() {
    setState(() {
      duration = const Duration();
      secondsCounter = 0;
    });
  }

  void _startRecording() {
    _recorder.startRecorder(toFile: audioFilePath);
    _startRecorder();

    _timer = Timer.periodic(const Duration(milliseconds: _expectAudioLength),
        (timer) {
      // classify here
      _runInference();
    });
    setState(() {
      isRecording = true;
    });
  }

  void _stopRecording() {
    _recorder.stopRecorder();
    _timer?.cancel();
    setState(() {
      isRecording = false;
    });
  }

  void _restartRecording() async {
    // _checkAudio(); // processes current recording
    _stopRecording();
    _startRecording();
  }

  void _activateFeature() {
    if (isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }

    activated = !activated;

    // Logic for activating the feature goes here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Feature is ${activated ? 'activated' : 'deactivated'}!')),
    );
  }

  Future<void> _runInference() async {
    Float32List inputArray = await _getAudioFloatArray();
    final result =
        await _helper.inference(inputArray.sublist(0, _requiredInputBuffer));

    _classification = (result.entries.toList()
          ..sort(
            (a, b) => a.value.compareTo(b.value),
          ))
        .reversed
        .toList();
    _checkAudio();
  }

  void _checkAudio() async {
    String recognizedLabel = _classification[0].key;
    double confidence = _classification[0].value;
    print('Recognized: $recognizedLabel, Confidence: $confidence');

    // Check if the recognized label indicates music and the confidence is high enough
    if (recognizedLabel == 'Piano Sound' && confidence > 0.4) {
      _startTimer(); // Start the timer if music is detected
    } else if (confidence > 0.4) { //Background noise detected
      _stopTimer(); // Stop the timer if it's background noise
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[5000], // Lighter shade of black
        title: Row(
          children: const [
            Icon(Icons.music_note, color: Colors.white),
            SizedBox(width: 10),
            Text("Tune Tracker"),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Spacer(flex: 2),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250, // Increased size for larger circle
                  height: 250, // Increased size for larger circle
                  child: CircularProgressIndicator(
                    value: (duration.inSeconds % 3600) / 3600.0,
                    strokeWidth: 8,
                    color: Colors.blue,
                    backgroundColor: Colors.grey,
                  ),
                ),
                Text(
                  '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 48, color: Colors.white),
                ),
              ],
            ),
            const Spacer(flex: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isRunning ? _stopTimer : _startTimer,
                  child: Text(isRunning ? 'Stop' : 'Start',
                      style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Dark blue color
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _resetTimer,
                  child: const Text('Reset',
                      style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey, // Grey color for reset button
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _activateFeature,
                  child: Text(isRecording ? 'Deactivate' : 'Activate',
                      style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600], // Dark blue color
                    padding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 16),
                  ),
                ),
              ],
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }

// @override
// Widget build(BuildContext context) {
//   return Scaffold(
//     backgroundColor: Colors.white,
//     appBar: AppBar(
//       title: Text(widget.title),
//       backgroundColor: Colors.black.withOpacity(0.5),
//     ),
//     body: _buildBody(),
//   );
// }
//
// Widget _buildBody() {
//   if (_showError) {
//     return const Center(
//       child: Text(
//         "Audio recording permission required for audio classification",
//         textAlign: TextAlign.center,
//       ),
//     );
//   } else {
//     return ListView.separated(
//       padding: const EdgeInsets.all(10),
//       physics: const BouncingScrollPhysics(),
//       shrinkWrap: true,
//       itemCount: _classification.length,
//       itemBuilder: (context, index) {
//         final item = _classification[index];
//         return Row(
//           children: [
//             SizedBox(
//               width: 200,
//               child: Text(item.key),
//             ),
//             Flexible(
//                 child: LinearProgressIndicator(
//               backgroundColor: _backgroundProgressColorList[
//                   index % _backgroundProgressColorList.length],
//               color: _primaryProgressColorList[
//                   index % _primaryProgressColorList.length],
//               value: item.value,
//               minHeight: 20,
//             ))
//           ],
//         );
//       },
//       separatorBuilder: (BuildContext context, int index) => const SizedBox(
//         height: 10,
//       ),
//     );
//   }
// }
}
