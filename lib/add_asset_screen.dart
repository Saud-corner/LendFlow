import 'package:flutter/material.dart';
import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';

class AddScreenAsset extends StatefulWidget {
  const AddScreenAsset({super.key});

  @override
  State<AddScreenAsset> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddScreenAsset> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreCtrl = TextEditingController();

  String _categoria = 'Laptops';
  bool _disponible = true;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Registrar Nuevo Activo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const CircleAvatar(
                radius: 40,
                backgroundColor: Color(0xFFE0F2F1),
                child: Icon(Icons.inventory_2, size: 40, color: Colors.teal),
              ),
              const SizedBox(height: 30),

              TextFormField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre / Modelo del equipo',
                  prefixIcon: const Icon(Icons.devices),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El nombre no puede estar vacío';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _categoria,
                decoration: InputDecoration(
                  labelText: 'Familia del equipo',
                  prefixIcon: const Icon(Icons.category),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
                items: ['Laptops', 'Tablets', 'Photography', 'Audio']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _categoria = v!),
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SwitchListTile(
                  title: const Text('Stock disponible', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Marcar si entra directo al almacén'),
                  value: _disponible,
                  activeColor: Colors.teal,
                  onChanged: (v) => setState(() => _disponible = v),
                ),
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
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    try {
                      await FirebaseFirestore.instance.collection('assets').add({
                        'name': _nombreCtrl.text.trim(),
                        'category': _categoria,
                        'isAvailable': _disponible,
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      dev.log('Asset guardado', name: 'AddAsset');

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Activo guardado con éxito'),
                            backgroundColor: Colors.teal,
                          ),
                        );
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      dev.log('Error: $e', name: 'AddAsset');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'GUARDAR EN INVENTARIO',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}