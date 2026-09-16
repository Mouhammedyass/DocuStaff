# 📱 DocuStaff (StaffVault) - Employee & Document Management System

A robust, offline-first Flutter application designed for managing workforce profiles, tracking employee records, and seamlessly handling official PDF documents and dynamic Excel report generation.

Built with a focus on optimization, clean state management, and smooth performance on low-spec Android devices.

---

## ✨ Features

- **👤 Employee Profiles Management:** Full CRUD operations (Create, Read, Update, Delete) for staff records.
- **📄 Offline PDF Management:** Store, view internally, open in external applications, and export/download official PDF documents directly on the device.
- **📊 Dynamic Excel Reports:** Generate and export detailed Excel spreadsheets from structured employee and dynamic data.
- **⚡ Lightweight & Optimized:** Specifically optimized for low-end hardware (e.g., 32-bit architecture) with minimal build footprint using `--split-per-abi`.
- **🌐 Arabic & RTL Support:** Fully customized for Arabic language reading patterns and intuitive user interaction.

---

## 🛠️ Tech Stack & Architecture

- **Framework:** Flutter (Dart)
- **State Management:** Provider
- **Local Database:** SQLite (`sqflite`) for structured local persistence
- **File & Document Handling:** 
  - `path_provider` & `file_picker` for native storage operations
  - `flutter_pdfview` & `open_filex` for PDF rendering and external app routing
  - `excel` package for spreadsheet generation

---

## 🚀 Build & Deployment Optimization

To ensure the smallest possible APK binary size for budget Android devices ( targeting `armeabi-v7a` ), the app is compiled using ABI splitting:

```bash
flutter build apk --split-per-abi --release
```
---

## 💻 Developer

Developed with ❤️ by **Mouhammed Yasser**

- **GitHub:** [Mouhammedyass](https://github.com/Mouhammedyass)
- **LinkedIn:** [Mouhammed Yasser](https://www.linkedin.com/in/mouhammed-yasser-1a113a330/)
