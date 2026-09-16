import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' as typed_data;
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:managment/data/model/employee_model.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class ExcelService {
  static Future<File?> pickExcelFile() async {
    List<PlatformFile>? files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (files.isNotEmpty && files.first.path != null) {
      return File(files.first.path!);
    }
    return null;
  }

  static Future<List<String>> getSheetNames(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);
      return decoder.tables.keys.toList();
    } catch (e) {
      print("خطأ أثناء قراءة الشيتات: $e");
      return [];
    }
  }

  static Future<List<EmployeeModel>> parseSheet({
    required File file,
    required String sheetName,
    required int departmentId,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final decoder = SpreadsheetDecoder.decodeBytes(bytes);
      final table = decoder.tables[sheetName];

      if (table == null || table.maxRows <= 1) return [];

      // قراءة جميع أسماء الأعمدة من الصف الأول في الإكسيل
      List<String> headers = [];
      final headerRow = table.rows.first;
      for (var cell in headerRow) {
        final h = cell?.toString().trim() ?? '';
        if (h.isNotEmpty) headers.add(h);
      }

      List<EmployeeModel> employees = [];

      for (int i = 1; i < table.rows.length; i++) {
        final row = table.rows[i];
        if (row.isEmpty) continue;

        Map<String, dynamic> rowMap = {};
        String? primaryName;

        for (int colIndex = 0; colIndex < row.length; colIndex++) {
          if (colIndex >= headers.length) break;

          final headerName = headers[colIndex];
          final cellValue = row[colIndex]?.toString().trim() ?? '';

          if (cellValue.isNotEmpty) {
            rowMap[headerName] = cellValue;

            // تحديد اسم تعريفي أولي للموديل (إن وجد)
            if (primaryName == null) {
              final hClean = headerName.toLowerCase();
              if (hClean.contains('اسم') || hClean.contains('name')) {
                primaryName = cellValue;
              }
            }
          }
        }

        // إذا لم يجد عمود باسم، يأخذ أول قيمة في الصف كاسم تعريفي
        primaryName ??= rowMap.values.isNotEmpty ? rowMap.values.first.toString() : 'غير محدد';

        if (rowMap.isNotEmpty) {
          employees.add(
            EmployeeModel(
              name: primaryName,
              departmentId: departmentId,
              // تخزين كل أعمدة الإكسيل بدون استثناء كـ Map داخل extradata
              extradata: jsonEncode(rowMap),
            ),
          );
        }
      }

      return employees;
    } catch (e) {
      print("خطأ أثناء معالجة الشيت: $e");
      return [];
    }
  }

  static Future<void> exportToExcel(List<EmployeeModel> employees, String departmentName) async {
    if (employees.isEmpty) return;

    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];

    // 1. استخراج العناوين الديناميكية
    final List<String> headers = [];
    for (var emp in employees) {
      if (emp.extradata != null && emp.extradata!.isNotEmpty) {
        try {
          final Map<String, dynamic> map = jsonDecode(emp.extradata!);
          for (var key in map.keys) {
            if (!headers.contains(key)) headers.add(key);
          }
        } catch (_) {}
      }
    }

    if (headers.isEmpty) headers.add('الاسم');

    // 2. كتابة صف العناوين (Headers)
    sheetObject.appendRow(headers.map((h) => TextCellValue(h)).toList());

    // 3. كتابة صفوف الموظفين
    for (var emp in employees) {
      Map<String, dynamic> empData = {};
      if (emp.extradata != null && emp.extradata!.isNotEmpty) {
        try {
          empData = jsonDecode(emp.extradata!);
        } catch (_) {}
      }

      List<CellValue> row = [];
      for (var header in headers) {
        final val = empData[header]?.toString() ?? '-';
        row.add(TextCellValue(val));
      }
      sheetObject.appendRow(row);
    }

    // 4. استخراج بايتس الملف
    final fileBytes = excel.save();
    if (fileBytes == null) return;

    // 5. حفظ الملف باستخدام FilePicker v12
    String fileName = 'تصدير_$departmentName.xlsx';

    final outputFile = await FilePicker.saveFile(
      dialogTitle: 'اختر مكان حفظ ملف الإكسيل',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      bytes: typed_data.Uint8List.fromList(fileBytes),
    );

    // التحقق من نجاح عملية التحديد فقط
    if (outputFile != null) {
      // لو الـ picker مرجع مسار عادي مش SAF وقام الحفظ بكتابته مباشرة
      try {
        final file = File(outputFile.path);
        if (!await file.exists()) {
          await file.writeAsBytes(fileBytes);
        }
      } catch (_) {
        // في حال كان الـ Path عبارة عن URI مخصص للـ SAF، الحزمة تكون قد كتبت الـ bytes بالفعل
      }
    }
  }

}