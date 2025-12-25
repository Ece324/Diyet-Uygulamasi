import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../kullanici/home_screen.dart';
import 'register_screen.dart';
import 'sifre_sifirlama_ekrani.dart';
import '../diyetisyen/diyetisyen_ana_sayfa.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;

Future<void> _login() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isLoading = true;
  });

  try {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: emailController.text.trim(),
      password: passwordController.text.trim(),
    );

    if (credential.user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      // DEBUG: Kullanıcı verilerini kontrol et
      debugPrint('Kullanıcı ID: ${credential.user!.uid}');
      debugPrint('Kullanıcı verisi: ${userDoc.data()}');

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final userRole = userData['rol'] ?? 'danışan';
        final userName = userData['adSoyad'] ?? credential.user!.email!;

        debugPrint('Kullanıcı Rolü: $userRole');
        debugPrint('Kullanıcı Adı: $userName');

        if (mounted) {
          // Rol kontrolü ile doğru ekrana yönlendirme
          if (userRole == 'diyetisyen') {
            debugPrint('Diyetisyen paneline yönlendiriliyor...');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DiyetisyenAnaSayfa(
                  diyetisyenId: credential.user!.uid,
                  diyetisyenAdi: userName,
                ),
              ),
            );
          } else {
            debugPrint('Danışan paneline yönlendiriliyor...');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  userId: credential.user!.uid,
                  userName: userName,
                  role: userRole,
                ),
              ),
            );
          }
        }
      } else {
        debugPrint('Kullanıcı verisi Firestore\'da bulunamadı!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kullanıcı verisi bulunamadı. Lütfen tekrar kayıt olun.")),
          );
        }
      }
    }
  } on FirebaseAuthException catch (e) {
    String message = "Hatalı e-posta veya şifre.";
    if (e.code == 'user-not-found') {
      message = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
    } else if (e.code == 'wrong-password') {
      message = 'Hatalı şifre girdiniz.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  } catch (e) {
    debugPrint('Giriş hatası: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Beklenmedik bir hata oluştu: $e")),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Hoş Geldiniz",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Devam etmek için giriş yapın",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: "E-posta", prefixIcon: Icon(Icons.email_outlined)),
                    validator: (value) => value!.isEmpty ? "E-posta boş olamaz" : null,
                    textInputAction: TextInputAction.next, // Enter'a basınca şifreye geç
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Şifre", prefixIcon: Icon(Icons.lock_outline)),
                    validator: (value) => value!.length < 6 ? "Şifre en az 6 karakter olmalı" : null,
                    textInputAction: TextInputAction.done, // Klavye Enter tuşu 'Bitti' (veya Gönder) olur
                    onFieldSubmitted: (_) => _login(), // Enter'a basınca _login'i çağır
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const SifreSifirlamaEkrani(),
                          ),
                        );
                      },
                      child: const Text("Şifremi Unuttum?"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _login,
                          child: const Text("Giriş Yap"),
                        ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Hesabınız yok mu?"),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text("Hemen Kaydolun"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
