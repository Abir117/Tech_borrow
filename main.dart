import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:tech_borrow/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // NOTE: If you haven't run 'flutterfire configure' yet, 
  // you might need to provide options here or add the generated firebase_options.dart file.
  await Firebase.initializeApp();
  
  runApp(const TechborrowApp());
}
