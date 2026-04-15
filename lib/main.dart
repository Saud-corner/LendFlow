import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math; 
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'add_asset_screen.dart';
import 'login_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

class DeviceModel {
  final String id;
  final String name;
  final String category;
  final bool isAvailable;
  final String prestadoA;
  final DateTime? fechaPrestamo; 
  final String? saludEquip; 
  final List<String> fotos;

  DeviceModel({
    required this.id, required this.name, required this.category,
    required this.isAvailable, required this.prestadoA,
    this.fechaPrestamo, this.saludEquip, required this.fotos,
  });

  factory DeviceModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? tempDate;
    
    if (data['fechaPrestamo'] != null) {
      tempDate = (data['fechaPrestamo'] as Timestamp).toDate();
    }

    return DeviceModel(
      id: doc.id,
      name: data['name'] ?? 'Sin nombre',
      category: data['category'] ?? 'Otro',
      isAvailable: data['isAvailable'] ?? true,
      prestadoA: data['prestadoA'] ?? '',
      fechaPrestamo: tempDate,
      saludEquip: data['saludEquip'],
      fotos: List<String>.from(data['fotos'] ?? []),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    developer.log('Error initializing Firebase: $e');
  }
  runApp(const LendFlowApp());
}

class LendFlowApp extends StatelessWidget {
  const LendFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentTheme, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LendFlow',
          themeMode: currentTheme,
          theme: ThemeData(
            useMaterial3: true, colorSchemeSeed: Colors.teal, brightness: Brightness.light,
            appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
          ),
          darkTheme: ThemeData(
            useMaterial3: true, colorSchemeSeed: Colors.teal, brightness: Brightness.dark,
            appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
          ),
          home: const AuthGate(), 
        );
      }
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Colors.teal, body: Center(child: CircularProgressIndicator(color: Colors.white)));
        }
        if (snapshot.hasData) return const MainScreen();
        return const LoginScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; 
  String _searchQuery = ""; 
  String _selectedCategory = "Todas"; 
  final List<String> _sessionLogs = [];

  final List<Map<String, String>> _mockRequests = [
    {'quien': 'Prof. Martínez', 'que': 'Proyector Aula 3', 'estado': 'pendiente'},
    {'quien': 'Laura (3ºA)', 'que': 'Portátil Asus', 'estado': 'pendiente'},
    {'quien': 'Dpto. Ciencias', 'que': 'Kit Arduino Mega', 'estado': 'pendiente'},
    {'quien': 'Javier (Profesor)', 'que': 'iPad Pro', 'estado': 'pendiente'},
    {'quien': 'Carlos (Bedel)', 'que': 'Altavoz Bluetooth', 'estado': 'pendiente'},
    {'quien': 'Ana (Secretaría)', 'que': 'Móvil de pruebas', 'estado': 'pendiente'},
  ];

  void _addLogEntry(String action) {
    final timestamp = "${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    setState(() {
      _sessionLogs.insert(0, "[$timestamp] $action");
    });
  }

  Future<String?> _showLoanDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Préstamo'),
        content: TextField(
          controller: controller, autofocus: true, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nombre del solicitante'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              if (controller.text.trim().length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre no válido'), backgroundColor: Colors.orange));
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showReturnDialog(BuildContext context) {
    return showDialog<String>(
      context: context, barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Auditoría de Devolución'),
        content: const Text('Indique el estado actual del equipo:'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.thumb_up, color: Colors.white, size: 18), label: const Text('Óptimo', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context, 'Óptimo'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            icon: const Icon(Icons.warning_amber, color: Colors.white, size: 18), label: const Text('Rasguños', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context, 'Con rasguños'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.broken_image, color: Colors.white, size: 18), label: const Text('Dañado', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context, 'Dañado'),
          ),
        ],
      ),
    );
  }

  void _showQuickView(DeviceModel device, BuildContext context) {
    HapticFeedback.heavyImpact(); 
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(25),
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vista Rápida', style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold)),
                      Text(device.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Icon(Icons.qr_code_scanner, size: 50, color: Colors.blueGrey), 
                ],
              ),
              const Divider(height: 30),
              Row(
                children: [
                  const Icon(Icons.label_outline, size: 18, color: Colors.grey), const SizedBox(width: 8),
                  Text(device.category, style: const TextStyle(fontSize: 16)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(device.isAvailable ? Icons.check_circle : Icons.error, size: 18, color: device.isAvailable ? Colors.green : Colors.orange), 
                  const SizedBox(width: 8),
                  Text(device.isAvailable ? 'En almacén' : 'Prestado a: ${device.prestadoA}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: device.isAvailable ? Colors.green : Colors.orange)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(docId: device.id)));
                  },
                  child: const Text('Abrir Ficha Completa', style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('assets').snapshots(),
      builder: (context, snapshot) {
        
        // --- PROTECCIÓN EXTRA A NIVEL DE APLICACIÓN ---
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Error al conectar con la base de datos', style: TextStyle(color: Colors.red))),
          );
        }
        // ----------------------------------------------

        int outOfStockCount = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            if ((doc.data() as Map)['isAvailable'] == false) outOfStockCount++;
          }
        }

        final int activeRequests = _mockRequests.where((p) => p['estado'] == 'pendiente').length;

        return Scaffold(
          backgroundColor: isDarkMode ? Colors.grey[900] : const Color(0xFFF4F6F8), 
          appBar: AppBar(title: const Text('LendFlow', style: TextStyle(fontWeight: FontWeight.bold))),
          drawer: _buildDrawer(),
          
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _buildDashboard(snapshot),
              _buildInventory(snapshot),
              _buildLoans(snapshot),
              _buildInbox(), 
            ],
          ),
          
          bottomNavigationBar: NavigationBar(
            height: 65,
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Panel'),
              const NavigationDestination(icon: Icon(Icons.list_alt), label: 'Inventario'),
              NavigationDestination(
                icon: Badge(label: Text(outOfStockCount.toString()), isLabelVisible: outOfStockCount > 0, child: const Icon(Icons.timer_outlined)), 
                label: 'Préstamos'
              ),
              NavigationDestination(
                icon: Badge(label: Text(activeRequests.toString()), isLabelVisible: activeRequests > 0, child: const Icon(Icons.inbox_outlined)), 
                label: 'Bandeja'
              ),
            ],
          ),
          
          floatingActionButton: _currentIndex == 1 ? FloatingActionButton(
            backgroundColor: Colors.teal,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddScreenAsset())),
            child: const Icon(Icons.add, color: Colors.white),
          ) : null,
        );
      }
    );
  }

  Widget _buildDashboard(AsyncSnapshot<QuerySnapshot> snapshot) {
    return Column(
      children: [
        _buildStatsHeader(snapshot), 
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 5),
          child: Text('Registro de Actividad', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        Expanded(
          child: _sessionLogs.isEmpty 
            ? const Center(child: Text('Sin movimientos recientes.', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: _sessionLogs.length,
                itemBuilder: (ctx, i) {
                  return Card(
                    elevation: 0, margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.info_outline, color: Colors.teal, size: 18),
                      title: Text(_sessionLogs[i], style: const TextStyle(fontSize: 13)),
                    ),
                  );
                },
            )
        )
      ],
    );
  }

  Widget _buildInventory(AsyncSnapshot<QuerySnapshot> snapshot) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Buscar equipos...', prefixIcon: const Icon(Icons.search),
              filled: true, fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 15, bottom: 10),
          child: Row(
            children: ['Todas', 'Portátiles', 'Móviles', 'Tablets', 'Cámaras', 'Audio', 'Electrónica'].map((category) {
              final bool isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedCategory = category),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(child: _buildAssetList(snapshot: snapshot, showOnlyLoans: false)), 
      ],
    );
  }

  Widget _buildLoans(AsyncSnapshot<QuerySnapshot> snapshot) {
    return Column(
      children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.amber.withOpacity(0.1),
          child: const Text('Equipos actualmente fuera de las instalaciones.', style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ),
        Expanded(child: _buildAssetList(snapshot: snapshot, showOnlyLoans: true)), 
      ],
    );
  }

  Widget _buildInbox() {
    final List<Map<String, String>> pendingRequests = _mockRequests.where((p) => p['estado'] == 'pendiente').toList();

    if (pendingRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.done_all, size: 70, color: Colors.green),
            SizedBox(height: 15),
            Text('Bandeja vacía', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('No hay peticiones pendientes.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: pendingRequests.length,
      itemBuilder: (context, i) {
        final request = pendingRequests[i];
        return Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.person, color: Colors.white)),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request['quien']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Solicita: ${request['que']}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        icon: const Icon(Icons.close), label: const Text('Denegar'),
                        onPressed: () {
                          setState(() => request['estado'] = 'rechazado');
                          _addLogEntry('Petición denegada: ${request['quien']}');
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        icon: const Icon(Icons.check), label: const Text('Aprobar'),
                        onPressed: () {
                          setState(() => request['estado'] = 'aprobado');
                          _addLogEntry('Petición aprobada: ${request['quien']}');
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aprobado. Proceda al inventario para asignar el equipo.'), backgroundColor: Colors.green));
                        },
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsHeader(AsyncSnapshot<QuerySnapshot> snapshot) {
    
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(30.0),
        child: CircularProgressIndicator(color: Colors.teal),
      );
    }
    

    if (!snapshot.hasData) return const SizedBox();
    final docs = snapshot.data!.docs;
    if (docs.isEmpty) return const SizedBox(); 

    int inStock = 0;
    for (var doc in docs) {
      if ((doc.data() as Map)['isAvailable'] == true) inStock++;
    }
    int onLoan = docs.length - inStock;

    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110, height: 110,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800), 
              curve: Curves.decelerate,
              builder: (context, value, child) {
                return CustomPaint(
                  painter: DonutChartPainter(
                    available: inStock * value, loaned: onLoan * value, total: docs.length
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${docs.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                        const Text('Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }
            )
          ),
          const SizedBox(width: 25),
          Expanded(
            child: Column(
              children: [
                _buildLegendRow('En Almacén', inStock, Colors.teal),
                const SizedBox(height: 12),
                _buildLegendRow('Prestados', onLoan, Colors.deepOrange),
              ],
            )
          )
        ],
      ),
    );
  }

  Widget _buildLegendRow(String title, int value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const Spacer(),
        Text(value.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'usuario@lendflow.com';
    final userName = user?.displayName ?? userEmail.split('@')[0];

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.teal),
            accountName: Text(
              userName.toUpperCase(), 
              style: const TextStyle(fontWeight: FontWeight.bold)
            ),
            accountEmail: Text(userEmail),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white, 
              child: Icon(Icons.person, color: Colors.teal)
            ),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, child) {
              return SwitchListTile(
                title: const Text('Tema Oscuro'), secondary: const Icon(Icons.brightness_4),
                value: mode == ThemeMode.dark,
                onChanged: (val) => themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light,
              );
            }
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut(); 
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAssetList({required AsyncSnapshot<QuerySnapshot> snapshot, required bool showOnlyLoans}) {
   
    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError) return const Center(child: Text('Error al cargar datos.'));
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay registros.'));
    

    List<DeviceModel> filteredList = snapshot.data!.docs
        .map((doc) => DeviceModel.fromDoc(doc))
        .where((device) => device.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (_selectedCategory != "Todas") {
      filteredList = filteredList.where((device) => device.category == _selectedCategory).toList();
    }

    if (showOnlyLoans) {
      filteredList = filteredList.where((device) => !device.isAvailable).toList();
    }

    if (filteredList.isEmpty) return const Center(child: Text('No se encontraron resultados.'));

    return ListView.builder(
      itemCount: filteredList.length,
      itemBuilder: (ctx, i) {
        final device = filteredList[i];
        return Dismissible(
          key: Key(device.id), direction: DismissDirection.endToStart,
          background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
          onDismissed: (_) {
            FirebaseFirestore.instance.collection('assets').doc(device.id).delete();
            _addLogEntry('Eliminado: ${device.name}');
          },
          child: _buildAssetCard(device),
        );
      },
    );
  }

  Widget _buildAssetCard(DeviceModel device) {
    String subtitleText = device.category;
    Color subtitleColor = Colors.grey;

    if (!device.isAvailable) {
      int daysLoaned = DateTime.now().difference(device.fechaPrestamo!).inDays;
      String timeStr = daysLoaned == 0 ? "(hoy)" : "(hace $daysLoaned d)";
      subtitleText = 'Con: ${device.prestadoA} $timeStr';
      subtitleColor = daysLoaned > 7 ? Colors.redAccent : Colors.deepOrange; 
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(docId: device.id))),
        onLongPress: () => _showQuickView(device, context), 
        
        leading: Hero(
          tag: 'asset_image_${device.id}',
          child: CircleAvatar(
            backgroundColor: device.isAvailable ? Colors.teal.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
            child: Icon(_getCategoryIcon(device.category), color: device.isAvailable ? Colors.teal : Colors.orange),
          ),
        ),
        title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitleText, style: TextStyle(color: subtitleColor, fontSize: 13)),
        trailing: Switch(
          value: device.isAvailable, activeColor: Colors.teal,
          onChanged: (val) async {
            if (val) {
              String? status = await _showReturnDialog(context);
              if (status != null) {
                FirebaseFirestore.instance.collection('assets').doc(device.id).update({
                  'isAvailable': true, 'prestadoA': FieldValue.delete(), 
                  'fechaPrestamo': FieldValue.delete(), 'saludEquip': status
                });
                _addLogEntry('Recuperado: ${device.name} ($status)'); 
              }
            } else {
              String? person = await _showLoanDialog(context);
              if (person != null && person.isNotEmpty) {
                FirebaseFirestore.instance.collection('assets').doc(device.id).update({
                  'isAvailable': false, 'prestadoA': person,
                  'fechaPrestamo': FieldValue.serverTimestamp(), 'saludEquip': FieldValue.delete()
                });
                _addLogEntry('Salida: ${device.name} a $person'); 
              }
            }
          },
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    if (category == 'Portátiles') return Icons.laptop;
    if (category == 'Móviles') return Icons.smartphone;
    if (category == 'Tablets') return Icons.tablet_mac;
    if (category == 'Cámaras') return Icons.camera_alt;
    if (category == 'Audio') return Icons.headphones;
    if (category == 'Electrónica') return Icons.memory;
    return Icons.devices_other;
  }
}

class DetailScreen extends StatefulWidget {
  final String docId;
  const DetailScreen({super.key, required this.docId});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isUploading = false;

  Future<void> _takePhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 50); 
    if (file == null) return;
    setState(() => _isUploading = true);
    try {
      final ref = FirebaseStorage.instance.ref('fotos/${widget.docId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('assets').doc(widget.docId).update({'fotos': FieldValue.arrayUnion([url])});
    } catch (e) {
      developer.log('Upload error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ficha Técnica")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('assets').doc(widget.docId).snapshots(),
        builder: (context, snapshot) {
          
          // --- proteccion pantalla ---
          if (snapshot.hasError) return const Center(child: Text('Error al cargar la ficha.'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: Text('El equipo ya no existe.'));
          // --------------------------------------------

          final device = DeviceModel.fromDoc(snapshot.data!);

          Widget healthAlert = const SizedBox();
          if (device.saludEquip != null) {
            healthAlert = Container(
              margin: const EdgeInsets.only(top: 15), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [const Icon(Icons.health_and_safety_outlined, color: Colors.teal), const SizedBox(width: 10), Text("Estado: ${device.saludEquip}", style: const TextStyle(fontWeight: FontWeight.bold))]),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Hero(
                    tag: 'asset_image_${device.id}',
                    child: CircleAvatar(
                      radius: 45, backgroundColor: Colors.teal.withOpacity(0.1),
                      child: const Icon(Icons.inventory_2_outlined, size: 40, color: Colors.teal),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Center(child: Text(device.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                const SizedBox(height: 20),
                Text("Categoría: ${device.category}", style: const TextStyle(color: Colors.grey)),
                healthAlert,
                const SizedBox(height: 30),
                const Text("DOCUMENTACIÓN GRÁFICA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Divider(),
                if (_isUploading) const LinearProgressIndicator(),
                const SizedBox(height: 10),
                device.fotos.isEmpty 
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Sin documentación adjunta", style: TextStyle(color: Colors.grey))))
                : GridView.builder(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), 
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
                    itemCount: device.fotos.length,
                    itemBuilder: (ctx, i) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10), 
                            child: Image.network(device.fotos[i], fit: BoxFit.cover)
                          ),
                          Positioned(
                            bottom: 0, left: 0, right: 0, 
                            child: Container(
                              color: Colors.black.withOpacity(0.7), 
                              padding: const EdgeInsets.symmetric(vertical: 4), 
                              child: Text('Foto #${i + 1}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                            )
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: _takePhoto, backgroundColor: Colors.teal, child: const Icon(Icons.camera_alt, color: Colors.white)),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final double available, loaned;
  final int total;
  DonutChartPainter({required this.available, required this.loaned, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) return;
    Paint brush = Paint()..style = PaintingStyle.stroke..strokeWidth = 14..strokeCap = StrokeCap.round;
    Offset center = Offset(size.width / 2, size.height / 2);
    double radius = size.width / 2;

    brush.color = Colors.grey.withOpacity(0.1);
    canvas.drawCircle(center, radius, brush);

    double arcAvailable = (available / total) * 2 * math.pi;
    brush.color = Colors.teal;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, arcAvailable, false, brush);

    double arcLoaned = (loaned / total) * 2 * math.pi;
    brush.color = Colors.deepOrange;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), (-math.pi / 2) + arcAvailable, arcLoaned, false, brush);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}