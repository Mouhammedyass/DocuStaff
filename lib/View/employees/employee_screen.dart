import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:managment/View%20Model/employee_provider.dart';
import 'package:managment/data/model/department_model.dart';
import 'package:managment/data/model/employee_model.dart';
import 'package:managment/data/services/excel_service.dart';

class EmployeeScreen extends StatefulWidget {
  final DepartmentModel department;

  const EmployeeScreen({super.key, required this.department});

  @override
  State<EmployeeScreen> createState() => _EmployeeScreenState();
}

class _EmployeeScreenState extends State<EmployeeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';

  // قائمة الأعمدة المختارة للإحصاء (تتحدث ديناميكياً)
  List<String> _selectedStatHeaders = [];
  bool _isSettingsInitialized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context
          .read<EmployeeProvider>()
          .loadEmployeesByDepartment(widget.department.id!);
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // دالة اختيار ملف الإكسيل والشيت المطلوبة
  Future<void> _importExcel() async {
    final file = await ExcelService.pickExcelFile();
    if (file == null) return;

    final sheetNames = await ExcelService.getSheetNames(file);

    if (sheetNames.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الملف لا يحتوي على شيتات')),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختر الشيت المطلوب استيراده'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sheetNames.length,
            itemBuilder: (context, index) {
              final sheetName = sheetNames[index];
              return ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: Text(sheetName),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _processSheetImport(file, sheetName);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // قراءة الشيت المحدد وحفظ الموظفين
  Future<void> _processSheetImport(File file, String sheetName) async {
    final employees = await ExcelService.parseSheet(
      file: file,
      sheetName: sheetName,
      departmentId: widget.department.id!,
    );

    if (employees.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على بيانات في هذا الشيت')),
        );
      }
      return;
    }

    if (!mounted) return;

    await context
        .read<EmployeeProvider>()
        .importEmployees(employees, widget.department.id!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم استيراد ${employees.length} موظف بنجاح!')),
      );
    }
  }

  void _showEmployeeDialog({EmployeeModel? employee}) {
    final provider = context.read<EmployeeProvider>();

    final List<String> availableHeaders = [];
    for (var emp in provider.employees) {
      if (emp.extradata != null && emp.extradata!.isNotEmpty) {
        try {
          final Map<String, dynamic> map = jsonDecode(emp.extradata!);
          for (var key in map.keys) {
            if (!availableHeaders.contains(key)) {
              availableHeaders.add(key);
            }
          }
        } catch (_) {}
      }
    }

    if (availableHeaders.isEmpty) {
      availableHeaders.addAll(['الاسم', 'الرقم القومي', 'تاريخ المعاش']);
    }

    Map<String, dynamic> currentExtra = {};
    if (employee != null && employee.extradata != null && employee.extradata!.isNotEmpty) {
      try {
        currentExtra = jsonDecode(employee.extradata!);
      } catch (_) {}
    }

    final Map<String, TextEditingController> controllers = {};
    for (var header in availableHeaders) {
      String initialVal = currentExtra[header]?.toString() ?? '';

      if (initialVal.isEmpty && employee != null) {
        if (header.contains('اسم') || header.toLowerCase() == 'name') {
          initialVal = employee.name;
        } else if (header.contains('قومي') || header.toLowerCase().contains('id')) {
          initialVal = employee.nationalId ?? '';
        } else if (header.contains('معاش') || header.toLowerCase().contains('date')) {
          initialVal = employee.retirementDate ?? '';
        }
      }

      controllers[header] = TextEditingController(text: initialVal);
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(employee == null ? 'إضافة بيان جديد' : 'تعديل البيانات'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableHeaders.map((header) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextField(
                    controller: controllers[header],
                    decoration: InputDecoration(
                      labelText: header,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final Map<String, dynamic> updatedExtra = {};
                String primaryName = 'غير محدد';

                controllers.forEach((key, controller) {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    updatedExtra[key] = text;
                  }
                });

                for (var entry in updatedExtra.entries) {
                  final kClean = entry.key.toLowerCase();
                  if (kClean.contains('اسم') || kClean == 'name') {
                    primaryName = entry.value.toString();
                    break;
                  }
                }
                if (primaryName == 'غير محدد' && updatedExtra.values.isNotEmpty) {
                  primaryName = updatedExtra.values.first.toString();
                }

                if (employee == null) {
                  final newEmp = EmployeeModel(
                    name: primaryName,
                    departmentId: widget.department.id!,
                    extradata: updatedExtra.isNotEmpty ? jsonEncode(updatedExtra) : null,
                  );
                  await provider.addEmployee(newEmp);
                } else {
                  final updatedEmp = EmployeeModel(
                    id: employee.id,
                    name: primaryName,
                    nationalId: employee.nationalId,
                    retirementDate: employee.retirementDate,
                    departmentId: widget.department.id!,
                    extradata: updatedExtra.isNotEmpty ? jsonEncode(updatedExtra) : null,
                  );
                  await provider.updateEmployee(updatedEmp);
                }

                if (mounted) Navigator.pop(dialogContext);
              },
              child: Text(employee == null ? 'إضافة' : 'حفظ التعديلات'),
            ),
          ],
        );
      },
    );
  }

  void _showAddEmployeeDialog(BuildContext context, int departmentId, List<EmployeeModel> employees) {
    // 1. استخراج كافة أسماء الأعمدة الديناميكية الموجودة حالياً في هذا القسم
    final Set<String> dynamicKeys = {};
    for (var emp in employees) {
      if (emp.extradata != null && emp.extradata!.isNotEmpty) {
        try {
          final Map<String, dynamic> map = jsonDecode(emp.extradata!);
          dynamicKeys.addAll(map.keys);
        } catch (_) {}
      }
    }

    // إذا لم يتوفر أي عنوان بعد، نضع عنوان افتراضي للبدء
    if (dynamicKeys.isEmpty) {
      dynamicKeys.addAll(['الاسم']);
    }

    // إنشاء Controllers لكل عمود ديناميكي قادم من الإكسيل
    final Map<String, TextEditingController> dynamicControllers = {
      for (var key in dynamicKeys) key: TextEditingController()
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إضافة موظف جديد', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: dynamicKeys.map((key) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: TextField(
                    controller: dynamicControllers[key],
                    decoration: InputDecoration(
                      labelText: key,
                      hintText: 'أدخل $key',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final Map<String, dynamic> extraDataMap = {};
                String primaryName = 'بدون اسم';

                dynamicControllers.forEach((key, controller) {
                  final val = controller.text.trim();
                  extraDataMap[key] = val.isEmpty ? '-' : val;

                  // تحديد الاسم الرئيسي تلقائياً من أول حقل يحتوي على كلمة "اسم" أو أول حقل إجمالاً
                  if (val.isNotEmpty) {
                    if (key.contains('اسم') || key.toLowerCase().contains('name')) {
                      primaryName = val;
                    }
                  }
                });

                if (primaryName == 'بدون اسم' && extraDataMap.values.any((v) => v != '-')) {
                  primaryName = extraDataMap.values.firstWhere((v) => v != '-', orElse: () => 'بدون اسم');
                }

                final newEmployee = EmployeeModel(
                  name: primaryName,
                  departmentId: departmentId,
                  extradata: jsonEncode(extraDataMap),
                );

                await Provider.of<EmployeeProvider>(context, listen: false).addEmployee(newEmployee);

                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ الموظف'),
            ),
          ],
        );
      },
    );
  }

  // دالة إظهار نافذة إعدادات الأعمدة المراد عرض إحصائياتها
  void _showStatsSettingsDialog(List<String> allHeaders) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('اختيار أعمدة الإحصائيات'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: allHeaders.length,
                  itemBuilder: (context, index) {
                    final header = allHeaders[index];
                    final isSelected = _selectedStatHeaders.contains(header);
                    return CheckboxListTile(
                      title: Text(header),
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            _selectedStatHeaders.add(header);
                          } else {
                            _selectedStatHeaders.remove(header);
                          }
                        });
                        setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('تم'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // تحليل العمود: هل هو أرقام (إجمالي) أم نصوص (توزيع فئوي)؟
  Widget _buildStatCard(String header, List<EmployeeModel> employees) {
    // 1. لو العمود مش متعلّم عليه في الإعدادات، متطبُعش حاجة
    if (!_selectedStatHeaders.contains(header)) {
      return const SizedBox.shrink();
    }

    bool isNumeric = true;
    double sum = 0;
    Map<String, int> counts = {};
    int totalValidEntries = 0;

    for (var emp in employees) {
      if (emp.extradata != null && emp.extradata!.isNotEmpty) {
        try {
          final map = jsonDecode(emp.extradata!);
          final rawVal = map[header]?.toString().trim() ?? '';
          if (rawVal.isNotEmpty && rawVal != '-') {
            totalValidEntries++;
            final doubleVal = double.tryParse(rawVal);
            if (doubleVal != null && isNumeric) {
              sum += doubleVal;
            } else {
              isNumeric = false;
              counts[rawVal] = (counts[rawVal] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }
    }

    // 2. لو مفيش أي قيمة محرزة للعمود ده في كل الموظفين، متطبُعش كارت فاضي
    if (totalValidEntries == 0) {
      return const SizedBox.shrink();
    }

    if (isNumeric && sum > 0) {
      final valStr = sum % 1 == 0 ? sum.toInt().toString() : sum.toStringAsFixed(2);
      return Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.calculate, color: Colors.blue, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'مجموع $header',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                valStr,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ],
          ),
        ),
      );
    } else if (counts.isNotEmpty) {
      return Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.amber.shade50,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pie_chart, color: Colors.amber, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'توزيع $header',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              ...counts.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '• ${entry.key}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'ابحث في كافة البيانات...',
              border: InputBorder.none,
            ),
          )
              : Text('قسم: ${widget.department.name}'),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              tooltip: _isSearching ? 'إغلاق البحث' : 'بحث',
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.file_upload),
              tooltip: 'استيراد إكسيل',
              onPressed: _importExcel,
            ),
            // قائمة الخيارات الإضافية (Export & Clear)
            PopupMenuButton<String>(
              onSelected: (value) async {
                final provider = Provider.of<EmployeeProvider>(context, listen: false);

                if (value == 'export') {
                  if (provider.employees.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('لا توجد بيانات لتصديرها')),
                    );
                    return;
                  }
                  await ExcelService.exportToExcel(provider.employees, widget.department.name);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تصدير ملف الإكسيل بنجاح!')),
                    );
                  }
                } else if (value == 'clear') {
                  if (provider.employees.isEmpty) return;
                  _showDeleteConfirmation(
                    context: context,
                    title: 'تصفير بيانات القسم',
                    message: 'هل أنت متأكد من مسح جميع الموظفين في قسم "${widget.department.name}"؟ لا يمكن التراجع عن هذا الإجراء.',
                    onConfirm: () async {
                      await provider.clearDepartmentEmployees(widget.department.id!);
                    },
                  );
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download, color: Colors.green),
                      SizedBox(width: 8),
                      Text('تصدير إلى إكسيل'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('تصفير كل البيانات'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.table_rows), text: 'جدول البيانات'),
              Tab(icon: Icon(Icons.dashboard), text: 'الإحصائيات والملخص'),
            ],
          ),
        ),
        // يمكنك إخفاء الزرار إذا لم ترغب به من خلال جعله null
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            final empProvider = Provider.of<EmployeeProvider>(context, listen: false);
            _showAddEmployeeDialog(context, widget.department.id!, empProvider.employees);
          },
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة موظف'),
        ),
        body: Consumer<EmployeeProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.employees.isEmpty) {
              return const Center(child: Text('لا يوجد بيانات في هذا القسم'));
            }

            // 1. التصفية والفلترة حسب كلمة البحث
            final filteredEmployees = provider.employees.where((emp) {
              if (_searchQuery.isEmpty) return true;

              if (emp.name.toLowerCase().contains(_searchQuery)) return true;
              if (emp.nationalId != null && emp.nationalId!.toLowerCase().contains(_searchQuery)) return true;

              if (emp.extradata != null && emp.extradata!.isNotEmpty) {
                try {
                  final Map<String, dynamic> map = jsonDecode(emp.extradata!);
                  for (var entry in map.entries) {
                    if (entry.key.toLowerCase().contains(_searchQuery) ||
                        entry.value.toString().toLowerCase().contains(_searchQuery)) {
                      return true;
                    }
                  }
                } catch (_) {}
              }
              return false;
            }).toList();

            if (filteredEmployees.isEmpty) {
              return const Center(child: Text('لا توجد نتائج تطابق بحثك'));
            }

            // 2. استخراج كافة العناوين المتاحة
            final List<String> excelHeaders = [];
            for (var emp in provider.employees) {
              if (emp.extradata != null && emp.extradata!.isNotEmpty) {
                try {
                  final Map<String, dynamic> map = jsonDecode(emp.extradata!);
                  for (var key in map.keys) {
                    if (!excelHeaders.contains(key)) {
                      excelHeaders.add(key);
                    }
                  }
                } catch (_) {}
              }
            }

            // تفعيل جميع الأعمدة افتراضياً لأول مرة فقط
            if (!_isSettingsInitialized && excelHeaders.isNotEmpty) {
              _selectedStatHeaders = List.from(excelHeaders);
              _isSettingsInitialized = true;
            }

            // 3. بناء عناوين الجدول
            List<DataColumn> columns = [
              const DataColumn(label: Text('م')),
            ];

            for (var header in excelHeaders) {
              columns.add(DataColumn(
                label: Text(
                  header,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ));
            }

            columns.add(const DataColumn(label: Text('الإجراءات')));

            return TabBarView(
              children: [
                // ---------------- التبويب الأول: جدول البيانات ----------------
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    children: [
                    SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: columns,
                      rows: List.generate(filteredEmployees.length, (index) {
                        final emp = filteredEmployees[index];

                        Map<String, dynamic> empData = {};
                        if (emp.extradata != null && emp.extradata!.isNotEmpty) {
                          try {
                            empData = jsonDecode(emp.extradata!);
                          } catch (_) {}
                        }

                        List<DataCell> cells = [
                          DataCell(Text('${index + 1}')),
                        ];

                        for (var header in excelHeaders) {
                          final val = empData[header]?.toString() ?? '-';
                          cells.add(DataCell(Text(val)));
                        }

                        cells.add(
                          DataCell(
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEmployeeDialog(employee: emp),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    _showDeleteConfirmation(
                                      context: context,
                                      title: 'حذف موظف',
                                      message: 'هل أنت تأكد من حذف الموظف "${emp.name}"؟',
                                      onConfirm: () {
                                        provider.deleteEmployee(emp.id!, widget.department.id!);
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );

                        return DataRow(cells: cells);
                      }),
                    ),
                  ),
                  const SizedBox(height: 90),
                  ],
                  ),
                ),

                // ---------------- التبويب الثاني: الإحصائيات والملخص ----------------
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الملخص الإحصائي',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, size: 28),
                            tooltip: 'تحديد أعمدة الإحصائيات',
                            onPressed: () => _showStatsSettingsDialog(excelHeaders),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          children: [
                            // كارت إجمالي العدد (افتراضي وثابت)
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color: Colors.teal.shade50,
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.people, color: Colors.teal, size: 32),
                                        SizedBox(width: 12),
                                        Text(
                                          'إجمالي عدد الموظفين',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${filteredEmployees.length}',
                                      style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // كروت الإحصائيات المخصصة للأعمدة المختارة
                            ..._selectedStatHeaders.map((header) {
                              return _buildStatCard(header, filteredEmployees);
                            }).toList(),

                            // مسافة سفلية تضمن عدم تغطية زر FloatingActionButton على آخر كارت
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
