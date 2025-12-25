import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SifreSifirlamaEkrani extends StatefulWidget {
  const SifreSifirlamaEkrani({super.key});

  @override
  State<SifreSifirlamaEkrani> createState() => _SifreSifirlamaEkraniState();
}

class _SifreSifirlamaEkraniState extends State<SifreSifirlamaEkrani> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _feedbackMessage = '';

  Future<void> _sifirlamaLinkiGonder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _feedbackMessage = '';
    });

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: _emailController.text.trim());
      setState(() {
        _feedbackMessage =
            "Şifre sıfırlama linki e-posta adresinize gönderildi. Lütfen gelen kutunuzu kontrol edin.";
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        setState(() {
          _feedbackMessage = "Bu e-posta adresi ile kayıtlı bir kullanıcı bulunamadı.";
        });
      } else {
         setState(() {
          _feedbackMessage = "Bir hata oluştu. Lütfen tekrar deneyin.";
        });
      }
    } catch (e) {
      setState(() {
         _feedbackMessage = "Beklenmedik bir hata oluştu. Lütfen tekrar deneyin.";
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Şifremi Unuttum"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Şifrenizi sıfırlamak için kayıtlı e-posta adresinizi girin.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "E-posta",
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return "Lütfen geçerli bir e-posta adresi girin.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _sifirlamaLinkiGonder,
                        child: const Text("Sıfırlama Linki Gönder", style: TextStyle(fontSize: 16)),
                      ),
                const SizedBox(height: 20),
                if (_feedbackMessage.isNotEmpty)
                  Text(
                    _feedbackMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _feedbackMessage.contains("bulunamadı") ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
