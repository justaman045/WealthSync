// Stub for google_mlkit_text_recognition on web
class InputImage {
  InputImage.fromFile(dynamic file);
}

class TextRecognizer {
  TextRecognizer({dynamic script});
  Future<RecognizedText> processImage(dynamic input) async =>
      throw UnsupportedError('Receipt scanning not available on web');
  void close() {}
}

class RecognizedText {
  String get text => '';
  List<dynamic> get blocks => [];
}

class TextRecognitionScript {
  static final latin = TextRecognitionScript._();
  TextRecognitionScript._();
}
