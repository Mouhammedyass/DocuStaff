import 'package:flutter/material.dart';
import 'package:managment/View/bottom_navigation_bar/pdf_screen.dart';
import 'package:managment/View/departments/department_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // قائمة الصفحات الرئيسية
  final List<Widget> _screens = const [
    DepartmentsScreen(),     // التبويب 0: يفتح فوراً شاشة الأقسام
    PdfManagementScreen(),   // التبويب 1: اللوائح والقرارات العامة
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.corporate_fare),
            label: 'الأقسام',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.picture_as_pdf),
            label: 'اللوائح والقرارات',
          ),
        ],
      ),
    );
  }
}