import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final birthDateController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen cinsiyet seçiniz.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (credential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(credential.user!.uid)
            .set({
          'adSoyad': nameController.text.trim(),
          'email': emailController.text.trim(),
          'dogumTarihi': birthDateController.text.trim(),
          'cinsiyet': _selectedGender,
          'rol': 'danışan', // Varsayılan rol
          'createdAt': Timestamp.now(),
        });
      }

      if (mounted) {
        Navigator.pop(context); // Giriş ekranına dön
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kayıt başarılı, giriş yapabilirsiniz.")),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Bir hata oluştu.";
      if (e.code == 'weak-password') {
        message = 'Şifre çok zayıf.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Bu e-posta adresi zaten kullanılıyor.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Beklenmedik bir hata oluştu: ${e.toString()}")),
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hesap Oluştur"), backgroundColor: Colors.green),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Ad Soyad"),
                  validator: (value) =>
                      value!.isEmpty ? "Ad Soyad boş olamaz" : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "E-posta"),
                  validator: (value) =>
                      !value!.contains('@') ? "Geçerli bir e-posta girin" : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Şifre"),
                  validator: (value) =>
                      value!.length < 6 ? "Şifre en az 6 karakter olmalı" : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: birthDateController,
                  decoration: const InputDecoration(labelText: "Doğum Tarihi (GG/AA/YYYY)"),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(labelText: "Cinsiyet"),
                  items: ['Kadın', 'Erkek']
                      .map((label) => DropdownMenuItem(
                            child: Text(label),
                            value: label,
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _register,
                        child:
                            const Text("Kayıt Ol", style: TextStyle(fontSize: 18)),
                      )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

