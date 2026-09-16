import 'dart:io';
import 'dart:typed_data' as typed_data;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_filex/open_filex.dart';

class PdfManagementScreen extends StatefulWidget {
  const PdfManagementScreen({Key? key}) : super(key: key);

  @override
  State<PdfManagementScreen> createState() => _PdfManagementScreenState();
}

class _PdfManagementScreenState extends State<PdfManagementScreen> {
  List<FileSystemEntity> _pdfFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllPdfs();
  }

  // تحميل كافة ملفات الـ PDF
  Future<void> _loadAllPdfs() async {
    setState(() => _isLoading = true);
    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${appDir.path}/general_pdfs');

    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    final files = pdfDir.listSync().where((file) => file.path.endsWith('.pdf')).toList();

    setState(() {
      _pdfFiles = files;
      _isLoading = false;
    });
  }

  // 1. استيراد ملف PDF من الموبايل وحفظه أوفلاين
  Future<void> _pickAndSavePdf() async {
    List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      final selectedFile = File(files.first.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final pdfDirPath = '${appDir.path}/general_pdfs';

      String customName = files.first.name.replaceAll('.pdf', '');
      final newPath = '$pdfDirPath/${DateTime.now().millisecondsSinceEpoch}_$customName.pdf';

      await selectedFile.copy(newPath);
      await _loadAllPdfs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة ملف اللائحة/القرار بنجاح')),
        );
      }
    }
  }

  // 2. فتح الملف في تطبيق خارجي
  Future<void> _openInExternalApp(String filePath) async {
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح الملف خارجيًا: ${result.message}')),
      );
    }
  }

  // 3. تنزيل/تصدير ملف PDF لحفظه على الجهاز
  Future<void> _exportPdfToDevice(File file, String displayName) async {
    try {
      final bytes = await file.readAsBytes();
      String fileName = '$displayName.pdf';

      final outputFile = await FilePicker.saveFile(
        dialogTitle: 'اختر مكان حفظ ملف الـ PDF',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: typed_data.Uint8List.fromList(bytes),
      );

      if (outputFile != null && mounted) {
        try {
          final targetFile = File(outputFile.path);
          if (!await targetFile.exists()) {
            await targetFile.writeAsBytes(bytes);
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ وتنزيل الملف بنجاح على الجهاز')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تنزيل الملف: $e')),
        );
      }
    }
  }

  // 4. فتح عارض الـ PDF الداخلي
  void _openPdfViewer(String filePath, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => PdfViewerScreen(filePath: filePath, title: title),
      ),
    );
  }

  // 5. حذف الملف
  Future<void> _deletePdf(FileSystemEntity file) async {
    if (await file.exists()) {
      await file.delete();
      _loadAllPdfs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الملف')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة اللوائح والقرارات'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pdfFiles.isEmpty
          ? const Center(
        child: Text(
          'لا توجد لوائح أو قرارات محفوظة حالياً.\nاضغط على الزر أدناه لإضافة ملف جديد.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pdfFiles.length,
        itemBuilder: (context, index) {
          final file = File(_pdfFiles[index].path);
          final rawName = file.path.split('/').last;
          final displayName = rawName.contains('_')
              ? rawName.split('_').sublist(1).join('_').replaceAll('.pdf', '')
              : rawName.replaceAll('.pdf', '');

          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 36),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('اضغط للعرض الداخلي السريع'),
              // قائمة الخيارات (الثلاث نقاط)
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'view') {
                    _openPdfViewer(file.path, displayName);
                  } else if (value == 'external') {
                    _openInExternalApp(file.path);
                  } else if (value == 'download') {
                    _exportPdfToDevice(file, displayName);
                  } else if (value == 'delete') {
                    _deletePdf(file);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.blue),
                        SizedBox(width: 10),
                        Text('عرض داخلي'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'external',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new, color: Colors.indigo),
                        SizedBox(width: 10),
                        Text('فتح في تطبيق خارجي'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'download',
                    child: Row(
                      children: [
                        Icon(Icons.download, color: Colors.green),
                        SizedBox(width: 10),
                        Text('تنزيل على الجهاز'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 10),
                        Text('حذف الملف', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () => _openPdfViewer(file.path, displayName),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndSavePdf,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('إضافة لائحة/قرار'),
      ),
    );
  }
}

// شاشة عارض الـ PDF الداخلي
class PdfViewerScreen extends StatelessWidget {
  final String filePath;
  final String title;

  const PdfViewerScreen({Key? key, required this.filePath, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: PDFView(
        filePath: filePath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
      ),
    );
  }
}