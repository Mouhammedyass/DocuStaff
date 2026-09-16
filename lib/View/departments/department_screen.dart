import 'package:flutter/material.dart';
import 'package:managment/data/model/department_model.dart';
import 'package:provider/provider.dart';
import 'package:managment/View%20Model/department_provider.dart';
import 'package:managment/View/employees/employee_screen.dart';

class DepartmentsScreen extends StatefulWidget {
  final DepartmentModel? parentDepartment;

  const DepartmentsScreen({super.key, this.parentDepartment});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<DepartmentProvider>()
            .loadDepartments(parentId: widget.parentDepartment?.id);
      }
    });
  }

  void _showDepartmentDialog(BuildContext context, {DepartmentModel? department}) {
    final controller = TextEditingController(text: department?.name ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(department == null ? 'إضافة قسم جديد' : 'تعديل اسم القسم'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'اسم القسم',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                final provider = context.read<DepartmentProvider>();

                if (department == null) {
                  // إضافة
                  await provider.addDepartment(text, parentId: widget.parentDepartment?.id);
                } else {
                  // تعديل
                  await provider.updateDepartment(
                    DepartmentModel(id: department.id, name: text, parentid: department.parentid),
                    parentId: widget.parentDepartment?.id,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(department == null ? 'إضافة' : 'حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.parentDepartment == null ? 'الأقسام الرئيسية' : widget.parentDepartment!.name;

    // استخدام PopScope يضمن إعادة قراءة البيانات سواء المستخدم رجع بسهم الـ AppBar أو زر الموبايل
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // لما تخرج من الشاشة، بنأكد على الشاشة اللي قبلها تحمل بياناتها
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(titleText),
          centerTitle: true,
        ),
        body: Consumer<DepartmentProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (provider.departments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.parentDepartment == null
                          ? "لا يوجد أقسام رئيسية بعد، اضغط + لإضافة قسم"
                          : "لا يوجد أقسام فرعية هنا",
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (widget.parentDepartment != null) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.people),
                        label: const Text("عرض موظفين هذا القسم"),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => EmployeeScreen(
                                department: widget.parentDepartment!,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: provider.departments.length,
              itemBuilder: (context, index) {
                final dept = provider.departments[index];
                return Card(
                  child: ListTile(
                    title: Text(dept.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showDepartmentDialog(context, department: dept),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            // تم إصلاح النقطة هنا: parentId بـ ?. بدل !
                            await provider.deleteDepartment(dept.id!, parentId: widget.parentDepartment?.id);
                          },
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DepartmentsScreen(parentDepartment: dept),
                        ),
                      );

                      // عند العودة من القسم الفرعي يتم استدعاء البيانات الحالية مجدداً
                      _fetchData();
                    },
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showDepartmentDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}