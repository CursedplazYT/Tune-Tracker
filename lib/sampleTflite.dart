import 'dart:async';
import 'dart:developer';
import 'dart:typed_data';

import 'helper/audio_classification_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform =
      MethodChannel('org.tensorflow.audio_classification/audio_record');

  // The YAMNet/classifier model used in this code example accepts data that
  // represent single-channel, or mono, audio clips recorded at 16kHz in 0.975
  // second clips (15600 samples).
  static const _sampleRate = 16000; // 16kHz
  static const _expectAudioLength = 2752; // milliseconds
  final int _requiredInputBuffer =
      (16000 * (_expectAudioLength / 1000)).toInt();
  late AudioClassificationHelper _helper;
  List<MapEntry<String, double>> _classification = List.empty();
  final List<Color> _primaryProgressColorList = [
    const Color(0xFFE91E63),
    const Color(0xFFFF9800)
  ];
  final List<Color> _backgroundProgressColorList = [
    const Color(0x44E91E63),
    const Color(0x44FF9800)
  ];
  var _showError = false;

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

  @override
  initState() {
    _initRecorder();
    super.initState();
  }

  Future<void> _initRecorder() async {
    _helper = AudioClassificationHelper();
    await _helper.initHelper();
    bool success = await _requestPermission();
    if (success) {
      _startRecorder();

      Timer.periodic(const Duration(milliseconds: _expectAudioLength), (timer) {
        // classify here
        _runInference();
      });
    } else {
      // show error here
      setState(() {
        _showError = true;
      });
    }
  }

  Future<void> _runInference() async {
    Float32List inputArray = await _getAudioFloatArray();
    final result =
        await _helper.inference(inputArray.sublist(0, _requiredInputBuffer));
    setState(() {
      _classification = (result.entries.toList()
            ..sort(
              (a, b) => a.value.compareTo(b.value),
            ))
          .reversed
          .toList();
    });
  }

  @override
  void dispose() {
    super.dispose();

    _closeRecorder();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black.withOpacity(0.5),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_showError) {
      return const Center(
        child: Text(
          "Audio recording permission required for audio classification",
          textAlign: TextAlign.center,
        ),
      );
    } else {
      return ListView.separated(
        padding: const EdgeInsets.all(10),
        physics: const BouncingScrollPhysics(),
        shrinkWrap: true,
        itemCount: _classification.length,
        itemBuilder: (context, index) {
          final item = _classification[index];
          return Row(
            children: [
              SizedBox(
                width: 200,
                child: Text(item.key),
              ),
              Flexible(
                  child: LinearProgressIndicator(
                backgroundColor: _backgroundProgressColorList[
                    index % _backgroundProgressColorList.length],
                color: _primaryProgressColorList[
                    index % _primaryProgressColorList.length],
                value: item.value,
                minHeight: 20,
              ))
            ],
          );
        },
        separatorBuilder: (BuildContext context, int index) => const SizedBox(
          height: 10,
        ),
      );
    }
  }
}
