// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'crear_grupo_screen.dart';
import 'historial_modal.dart';
import '../agradecimientos_modal.dart';
import 'rangos_widget.dart';

class PerfilScreen extends StatefulWidget {
  final String? usuarioId;
  const PerfilScreen({super.key, this.usuarioId});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final TextEditingController _bioController = TextEditingController();

  bool privacidad = true;
  bool _isUploading = false;
  File? _imageFile;

  Color colorRojoPerfil = const Color(0xFFFD322F);

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _cambiarPrivacidad(bool val) async {
    setState(() {
      privacidad = val;
    });
    if (currentUid.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUid)
          .update({'privacidad': val});
    }
  }

  Future<void> _guardarBio(String nuevaBio) async {
    if (currentUid.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUid)
          .update({'descripcion_bio': nuevaBio});
    }
  }

  Future<void> _seleccionarYSubirFoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile == null) return;

    setState(() {
      _imageFile = File(pickedFile.path);
      _isUploading = true;
    });

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('perfiles')
          .child('$currentUid.jpg');

      await ref.putFile(_imageFile!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(currentUid)
          .update({'fotoPerfilUrl': url});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Si widget.usuarioId viene nulo o vacío, usamos obligatoriamente el currentUid autenticado
    final String uidAConsultar =
        (widget.usuarioId == null || widget.usuarioId!.trim().isEmpty)
        ? currentUid
        : widget.usuarioId!;

    if (uidAConsultar.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool esMiPerfil = uidAConsultar == currentUid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uidAConsultar)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Error al cargar los datos del perfil")),
          );
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        String nombre = userData['nombre'] ?? 'Usuario';
        String email = userData['email'] ?? 'Sin correo';
        String bio = userData['descripcion_bio'] ?? 'Sin descripción todavía.';
        String? fotoUrl = userData['fotoPerfilUrl'];
        int entregadas = userData['s_entregadas'] ?? 0;
        int recibidas = userData['s_recibidas'] ?? 0;
        bool reputacion = userData['s_reputacion'] ?? true;
        String? nombreMesiasPersonalizado =
            userData['nombre_mesias_personalizado'];

        if (userData.containsKey('privacidad')) {
          privacidad = userData['privacidad'] ?? true;
        }

        _bioController.text = bio;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: Text(esMiPerfil ? "Mi Perfil" : "Perfil de $nombre"),
            backgroundColor: colorRojoPerfil,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            actions: [
              if (esMiPerfil) ...[
                Row(
                  children: [
                    Icon(
                      privacidad ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                      color: Colors.white70,
                    ),
                    Switch(
                      value: privacidad,
                      activeThumbColor: Colors
                          .white, // Volvemos a activeColor para evitar problemas de linter en tu versión de SDK
                      activeTrackColor: Colors.red.shade300,
                      onChanged: (bool val) async {
                        await _cambiarPrivacidad(val);
                      },
                    ), // <-- Este paréntesis y coma cierran el Switch limpiamente dentro del Row
                  ],
                ),
              ],
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.white,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!) as ImageProvider
                            : (fotoUrl != null && fotoUrl.isNotEmpty
                                  ? NetworkImage(fotoUrl) as ImageProvider
                                  : null),
                        child:
                            (_imageFile == null &&
                                (fotoUrl == null || fotoUrl.isEmpty))
                            ? const Icon(
                                Icons.person,
                                size: 65,
                                color: Colors.grey,
                              )
                            : null,
                      ),
                      if (_isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (esMiPerfil)
                        Positioned(
                          bottom: 0,
                          right: 4,
                          child: GestureDetector(
                            onTap: _seleccionarYSubirFoto,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorRojoPerfil,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: ListTile(
                    leading: const Icon(
                      Icons.group_add,
                      color: Colors.blueAccent,
                    ),
                    title: const Text("Crear mi ONG o Grupo de Ayuda"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CrearGrupoScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 10),

                // Llamada al componente de rangos
                // Busca estas líneas en perfil.dart y cámbialas por esto:
                RangosWidget(
                  donaciones:
                      entregadas, // Cambiamos 'entregadas' por 'donaciones'
                  nombrePersonalizado: nombreMesiasPersonalizado,
                  esMiPerfil: esMiPerfil,
                  // 'currentUid' ya no es necesario pasarlo a RangosWidget
                  // según la estructura que definimos arriba, así que puedes borrar esa línea.
                ),

                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatCard(
                      "Entregados",
                      entregadas,
                      Icons.card_giftcard,
                      Colors.green,
                    ),
                    _buildStatCard(
                      "Recibidos",
                      recibidas,
                      Icons.call_received,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      "Reputación",
                      reputacion ? "Buena" : "Baja",
                      reputacion ? Icons.thumb_up : Icons.thumb_down,
                      reputacion ? Colors.orange : Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Biografía",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (esMiPerfil) ...[
                          TextField(
                            controller: _bioController,
                            maxLines: 3,
                            maxLength: 150,
                            decoration: InputDecoration(
                              hintText: "Escribe algo sobre ti...",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.all(10),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final scaffoldMessenger = ScaffoldMessenger.of(
                                  context,
                                ); // Guardamos la referencia aquí

                                await _guardarBio(_bioController.text.trim());

                                if (mounted) {
                                  scaffoldMessenger.showSnackBar(
                                    const SnackBar(
                                      content: Text('Biografía guardada'),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorRojoPerfil,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.save, size: 16),
                              label: const Text("Actualizar"),
                            ),
                          ),
                        ] else ...[
                          Text(
                            bio,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        HistorialModal.mostrar(context, uidAConsultar),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.history),
                    label: const Text(
                      "Ver Historial de Intercambios",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        AgradecimientosModal.mostrar(context, uidAConsultar),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorRojoPerfil, width: 1.5),
                      foregroundColor: colorRojoPerfil,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.favorite),
                    label: const Text(
                      "Ver Agradecimientos",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    dynamic value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class IdenticonPlaceholder extends StatelessWidget {
  const IdenticonPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.person, size: 65, color: Colors.grey);
  }
}
