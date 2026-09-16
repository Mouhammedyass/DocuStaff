import 'package:flutter/material.dart';
import 'package:managment/data/local/app_database.dart';
import 'package:managment/data/model/department_model.dart';

class DepartmentProvider extends ChangeNotifier {
  final AppDatabase _db = AppDatabase();

  // قائمة الأقسام المحفوظة في الـ Memory للعرض في الـ UI
  List<DepartmentModel> _departments = [];
  List<DepartmentModel> get departments => _departments;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadDepartments({int? parentId}) async {
    _isLoading = true;
    notifyListeners();

    List<Map<String, dynamic>> rawData;
    if (parentId == null) {
      rawData = await _db.readData('departments', where: 'parent_id IS NULL');
    } else {
      rawData = await _db.readData('departments', where: 'parent_id = ?', whereArgs: [parentId]);
    }

    _departments = rawData.map((map) => DepartmentModel.fromMap(map)).toList();

    _isLoading = false;
    notifyListeners();
  }


  Future<void> addDepartment(String name, {int? parentId}) async {
    final newDept = DepartmentModel(name: name, parentid: parentId);
    await _db.insertData('departments', newDept.toMap());

    await loadDepartments(parentId: parentId);
  }

  Future<void> updateDepartment(DepartmentModel department, {int? parentId})async{
    await _db.updateData('departments', department.toMap(), department.id!);
    await loadDepartments(parentId: parentId);
  }

  Future<void> deleteDepartment(int id, {int? parentId}) async {
    await _db.deleteData('departments', id);
    await loadDepartments(parentId: parentId);
  }
}

