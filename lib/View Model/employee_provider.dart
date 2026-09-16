import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:managment/data/local/app_database.dart';
import 'package:managment/data/model/employee_model.dart';

class EmployeeProvider extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();

  List<EmployeeModel> _employees = [];
  List<EmployeeModel> get employees => _employees;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadEmployeesByDepartment(int departmentId) async {
    _isLoading = true;
    notifyListeners();

    List<Map<String, dynamic>> rawData = await _db.readData(
      'employees',
      where: 'department_id = ?',
      whereArgs: [departmentId],
    );

    _employees = rawData.map((map) => EmployeeModel.fromMap(map)).toList();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addEmployee(EmployeeModel employee) async {
    await _db.insertData('employees', employee.toMap());
    await loadEmployeesByDepartment(employee.departmentId);
  }

  Future<void> updateEmployee(EmployeeModel employee) async {
    await _db.updateData('employees', employee.toMap(), employee.id!);
    await loadEmployeesByDepartment(employee.departmentId);
  }

  Future<void> deleteEmployee(int id, int departmentId) async {
    await _db.deleteData('employees', id);
    await loadEmployeesByDepartment(departmentId);
  }
  Future<void> clearDepartmentEmployees(int departmentId) async {
    _isLoading = true;
    notifyListeners();

    // عمل نسخة من الموظفين الموجودين حالياً لمسحهم واحد تلو الآخر
    final employeesToDelete = List<EmployeeModel>.from(_employees);
    for (var emp in employeesToDelete) {
      if (emp.id != null) {
        await _db.deleteData('employees', emp.id!);
      }
    }

    await loadEmployeesByDepartment(departmentId);
  }

  // دالة الاستيراد الذكية: تمنع التكرار وتدمج البيانات الجديدة مع القديمة
  Future<void> importEmployees(List<EmployeeModel> newEmployees, int departmentId) async {
    _isLoading = true;
    notifyListeners();

    // 1. قراءة كافة الموظفين الحاليين في هذا القسم من قاعدة البيانات
    List<Map<String, dynamic>> rawCurrent = await _db.readData(
      'employees',
      where: 'department_id = ?',
      whereArgs: [departmentId],
    );
    List<EmployeeModel> currentEmployees =
    rawCurrent.map((map) => EmployeeModel.fromMap(map)).toList();

    for (var newEmp in newEmployees) {
      // 2. البحث عن الموظف في القائمة الحالية (بواسطة الاسم أو الرقم القومي)
      final existingIndex = currentEmployees.indexWhere((emp) {
        bool sameName = emp.name.trim().toLowerCase() == newEmp.name.trim().toLowerCase();

        bool sameNationalId = (emp.nationalId != null &&
            newEmp.nationalId != null &&
            emp.nationalId!.isNotEmpty &&
            emp.nationalId == newEmp.nationalId);

        return sameNationalId || sameName;
      });

      if (existingIndex != -1) {
        // ------ الموظف موجود بالفعل: دمج البيانات وتحديث الصف ------
        final existingEmp = currentEmployees[existingIndex];

        Map<String, dynamic> oldData = {};
        Map<String, dynamic> newData = {};

        if (existingEmp.extradata != null && existingEmp.extradata!.isNotEmpty) {
          try {
            oldData = jsonDecode(existingEmp.extradata!);
          } catch (_) {}
        }

        if (newEmp.extradata != null && newEmp.extradata!.isNotEmpty) {
          try {
            newData = jsonDecode(newEmp.extradata!);
          } catch (_) {}
        }

        // دمج الـ JSON (البيانات الجديدة تضيف أو تحدّث المفاتيح الموجودة دون مسح القديم)
        final mergedData = {...oldData, ...newData};

        final updatedEmployee = EmployeeModel(
          id: existingEmp.id,
          name: existingEmp.name,
          nationalId: existingEmp.nationalId ?? newEmp.nationalId,
          retirementDate: existingEmp.retirementDate ?? newEmp.retirementDate,
          departmentId: departmentId,
          extradata: jsonEncode(mergedData),
        );

        await _db.updateData('employees', updatedEmployee.toMap(), existingEmp.id!);
      } else {
        // ------ الموظف جديد: إضافة صف جديد ------
        await _db.insertData('employees', newEmp.toMap());
      }

    }


    // 3. إعادة تحميل القائمة وتحديث الشاشة
    await loadEmployeesByDepartment(departmentId);
  }
}