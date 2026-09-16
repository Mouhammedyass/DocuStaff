class DepartmentModel {
  final int? id;
  final String name;
  final int? parentid;

  DepartmentModel({
    this.id,
    required this.name,
    this.parentid,

  });

  Map<String, dynamic> toMap() {
    return{
      'id' : id,
      'name' : name,
      'parent_id' : parentid
    };
  }

  factory DepartmentModel.fromMap(Map<String, dynamic> map) {
    return DepartmentModel(
      id: map['id'],
      name: map['name'],
      parentid: map['parent_id']
    );
  }
}