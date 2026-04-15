import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'main.dart';
import 'register_screen.dart'; 
import 'dart:developer' as dev;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final controladorEmail = TextEditingController();
  final controladorPass = TextEditingController();
  bool cargando = false;

  @override
  void dispose() {
    controladorEmail.dispose();
    controladorPass.dispose();
    super.dispose();
  }

  // sacamos la llamada a firebase fuera para limpiar un poco
  Future<UserCredential?> loguearUsuario(String email, String password) async {
    try {
      return await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      dev.log('petó el login: $e');
      return null;
    }
  }

  void hacerLogin() async {
    if (formKey.currentState!.validate()) {
      setState(() => cargando = true);

      // llamamos a la funcion de arriba
      final userCreds = await loguearUsuario(
        controladorEmail.text.trim(),
        controladorPass.text.trim(),
      );

      if (!mounted) return;
      setState(() => cargando = false);

      if (userCreds != null) {
        // si bien pues proximo paso
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()), 
        );
      } else {
        // si falla mostramos el mensajito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vaya.. algo falló con esos datos'), 
            backgroundColor: Colors.redAccent
          ),
        );
      }
    }
  }

  // NUEVA FUNCIÓN: Recuperar Contraseña
  Future<void> recuperarPassword() async {
    final email = controladorEmail.text.trim();
    
    // Comprobamos que haya escrito un correo antes de darle al botón
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, escribe tu correo arriba para poder enviarte el enlace.'), 
          backgroundColor: Colors.orange
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Correo enviado! Revisa tu bandeja de entrada (y el spam).'), 
          backgroundColor: Colors.teal
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hemos podido enviar el correo. Revisa que esté bien escrito.'), 
          backgroundColor: Colors.redAccent
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, size: 80, color: Colors.teal),
                ),
                const SizedBox(height: 20),
                const Text(
                  "LendFlow",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00695C),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 50),
                TextFormField(
                  controller: controladorEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Campo obligatorio';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Ese correo no parece válido ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: controladorPass,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Clave',
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Falta la contraseña';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: cargando ? null : hacerLogin,
                    child: cargando 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('ENTRAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                
                // NUEVO BOTÓN: Recuperar contraseña
                TextButton(
                  onPressed: recuperarPassword,
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ),
                
                const SizedBox(height: 10),
                
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text(
                    '¿Nuevo por aquí? Crea una cuenta',
                    style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}