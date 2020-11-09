import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_upchunk/flutter_upchunk.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UpChunk Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'UpChunk Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // ADD ENDPOINT URL HERE
  final _endPoint = '';

  final picker = ImagePicker();

  int _progress = 0;
  bool _uploadComplete = false;
  String _errorMessage;

  void _getFile() async {
    final pickedFile = await picker.getVideo(source: ImageSource.gallery);

    if (pickedFile == null) return;

    _uploadFile(File(pickedFile.path));
  }

  void _uploadFile(File fileToUpload) {
    _progress = 0;
    _uploadComplete = false;
    _errorMessage = null;

    // Chunk upload
    var uploadOptions = UpChunkOptions()
      ..endPoint = _endPoint
      ..file = fileToUpload
      ..onProgress = ({ @required double progress }) {
        setState(() {
          _progress = progress.ceil();
        });
      }
      ..onError = ({ @required String message, @required int chunk, @required int attempts }) {
        setState(() {
          _errorMessage = 'UpChunk error 💥 🙀:\n'
              ' - Message: $message\n'
              ' - Chunk: $chunk\n'
              ' - Attempts: $attempts';
        });
      }
      ..onSuccess = () {
        setState(() {
          _uploadComplete = true;
        });
      };

    UpChunk.createUpload(uploadOptions);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            if (!_uploadComplete)
              Text(
                'Uploaded: $_progress%',
                style: Theme.of(context).textTheme.headline4,
              ),

            if (_uploadComplete)
              Text(
                'Upload complete! 👋',
                style: Theme.of(context).textTheme.headline4.copyWith(color: Colors.green, fontWeight: FontWeight.bold),
              ),

            if (_errorMessage != null && _errorMessage.isNotEmpty)
              Text(
                '$_errorMessage%',
                style: Theme.of(context).textTheme.headline5.copyWith(color: Colors.red),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getFile,
        tooltip: 'Get File',
        child: Icon(Icons.upload_file),
      ),
    );
  }
}
