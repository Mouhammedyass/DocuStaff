class EmployeeModel {
  final int? id;
  final String name;
  final String? nationalId;
  final String? retirementDate;
  final int departmentId;
  final String? extradata;

  EmployeeModel({
    this.id,
    required this.name,
    this.nationalId,
    this.retirementDate,
    required this.departmentId,
    this.extradata,
  });

  Map<String, dynamic> toMap() {
    return{
      'id' : id,
      'name' : name,
      'national_id' : nationalId,
      'retirement_date' : retirementDate,
      'department_id' : departmentId,
      'extra_data' : extradata
    };
  }

  factory EmployeeModel.fromMap(Map<String, dynamic> map) {
    return EmployeeModel(
        id: map['id'],
        name: map['name'] ?? '',
        nationalId: map['national_id'] ?? '',
        retirementDate: map['retirement_date'] ?? '',
        departmentId: map['department_id'] as int,
        extradata: map['extra_data'] ?? ''
    );
  }
}