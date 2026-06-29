import 'dart:html' as html;

Future<String?> pickAndConvertImage() async {
  try {
    final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
    uploadInput.click();

    await uploadInput.onChange.first;
    if (uploadInput.files == null || uploadInput.files!.isEmpty) return null;

    final file = uploadInput.files![0];
    final reader = html.FileReader();
    reader.readAsDataUrl(file);

    await reader.onLoadEnd.first;
    return reader.result as String?;
  } catch (e) {
    return null;
  }
}
