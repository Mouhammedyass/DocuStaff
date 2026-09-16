import 'package:flutter/material.dart';
import 'package:managment/View/bottom_navigation_bar/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:managment/View Model/department_provider.dart';
import 'package:managment/View Model/employee_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DepartmentProvider()..loadDepartments()),
        ChangeNotifierProvider(create: (_) => EmployeeProvider()),
      ],
      child: MaterialApp(
        builder: (context, child){
          return Directionality(textDirection: TextDirection.rtl, child: child!);
        },
        debugShowCheckedModeBanner: false,
        title: 'إدارة الموظفين',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}