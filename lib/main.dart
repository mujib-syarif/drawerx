import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app.dart';

void main() {
  // Build rilis tidak memiliki izin INTERNET, jadi font tidak boleh diunduh
  // saat runtime. Tanpa ini google_fonts mencoba jaringan lalu gagal; dengan
  // ini teks langsung memakai font bawaan sistem sebagai fallback.
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const DrawerXApp());
}
