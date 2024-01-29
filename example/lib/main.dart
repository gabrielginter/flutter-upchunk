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
  MyHomePage({ this.title = ''});

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
  String _errorMessage = '';

  void _getFile() async {
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile == null) return;

    _uploadFile(pickedFile);
  }

  void _uploadFile(XFile fileToUpload) {
    _progress = 0;
    _uploadComplete = false;
    _errorMessage = '';

    UpChunk(
      endPoint: _endPoint,
      file: fileToUpload,
      onProgress: (double progress) {
        setState(() {
          _progress = progress.ceil();
        });
      },
      onError: (String message, int chunk, int attempts) {
        setState(() {
          _errorMessage = 'UpChunk error 💥 🙀:\n'
            ' - Message: $message\n'
            ' - Chunk: $chunk\n'
            ' - Attempts: $attempts';
        });
      },
      onSuccess: () {
        setState(() {
        _uploadComplete = true;
        });
      },
    );
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.normal,
                ),
              ),

            if (_uploadComplete)
              Text(
                'Upload complete! 👋',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),

            if (_errorMessage.isNotEmpty)
              Text(
                '$_errorMessage%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.normal,
                  color: Colors.red,
                ),
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
