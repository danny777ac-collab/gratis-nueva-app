// ignore_for_file: deprecated_member_use
// ignore_for_file: implementation_imports
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class DonarScreen extends StatefulWidget {
  final String tipoPublicacion; // 'donaciones' o 'necesidades'
  final String categoriaPreseleccionada;

  const DonarScreen({
    super.key,
    required this.tipoPublicacion,
    required this.categoriaPreseleccionada,
  });

  @override
  State<DonarScreen> createState() => _DonarScreenState();
}

class _DonarScreenState extends State<DonarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _ubicacionController = TextEditingController();

  late String _categoriaSeleccionada;
  bool _guardando = false;

  final List<File> _imagenesSeleccionadas = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _categoriaSeleccionada = widget.categoriaPreseleccionada;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen(ImageSource fuente) async {
    if (_imagenesSeleccionadas.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Máximo puedes subir 3 imágenes")),
      );
      return;
    }

    final XFile? imagen = await _picker.pickImage(
      source: fuente,
      imageQuality: 70,
    );
    if (imagen != null) {
      setState(() {
        _imagenesSeleccionadas.add(File(imagen.path));
      });
    }
  }

  void _removerImagen(int index) {
    setState(() {
      _imagenesSeleccionadas.removeAt(index);
    });
  }

  Future<List<String>> _subirImagenes(String postId) async {
    List<String> urls = [];
    for (int i = 0; i < _imagenesSeleccionadas.length; i++) {
      final ref = FirebaseStorage.instance.ref().child(
        'publicaciones/$postId/imagen_$i.jpg',
      );
      await ref.putFile(_imagenesSeleccionadas[i]);
      String url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  void _publicarAporte() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      var userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();
      String nombreUsuario = userDoc.data()?['nombre'] ?? 'Anónimo';
      String telefonoUsuario = userDoc.data()?['telefono'] ?? '';

      final docRef = FirebaseFirestore.instance
          .collection(widget.tipoPublicacion)
          .doc();

      List<String> urlsImagenes = [];
      if (_imagenesSeleccionadas.isNotEmpty) {
        urlsImagenes = await _subirImagenes(docRef.id);
      }

      await docRef.set({
        'id': docRef.id,
        'usuarioId': user.uid,
        'usuarioNombre': nombreUsuario,
        'usuarioTelefono': telefonoUsuario,
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'ubicacion': _ubicacionController.text.trim().isEmpty
            ? 'Santa Cruz, Bolivia'
            : _ubicacionController.text.trim(),
        'categoria': _categoriaSeleccionada,
        'imagenesUrls': urlsImagenes,
        'fecha': FieldValue.serverTimestamp(),
        'expiraEn': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 24)),
        ),
        'postulantes': [],
        'transaccionConfirmadaEmisor': false,
        'transaccionConfirmadaReceptor': false,
        'receptorConfirmadoId': '',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Publicado con éxito por 24 horas!"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error al publicar: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool esDonacion = widget.tipoPublicacion == 'donaciones';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          esDonacion ? "Ofrecer Donación o Servicio" : "Publicar Necesidad",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.orange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _guardando
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esDonacion
                          ? "¿Qué vas a ofrecer?"
                          : "¿Qué estás necesitando?",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _categoriaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: "Categoría",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Cosas',
                          child: Text("Necesito una cosa material"),
                        ),
                        DropdownMenuItem(
                          value: 'Servicios',
                          child: Text("Necesito alguna ayuda o servicio"),
                        ),
                        DropdownMenuItem(
                          value: 'Otros',
                          child: Text("Otras necesidades"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _categoriaSeleccionada = val;
                          });
                        }
                      },
                    ), // <- AQUÍ CIERRA EL DROPDOWN CORRECTAMENTE
                    const SizedBox(
                      height: 25,
                    ), // <- ESTE ES EL SIZEDBOX DE LA LÍNEA 231 QUE DABA ERROR
                    const SizedBox(height: 25),
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        labelText: "Título del anuncio",
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? "Ingresa un título descriptivo"
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descripcionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Detalles adicionales",
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? "Ingresa los detalles"
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _ubicacionController,
                      decoration: const InputDecoration(
                        labelText: "Zona o Ubicación",
                        prefixIcon: Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 25),

                    const Text(
                      "Fotos de la publicación (Máximo 3)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () =>
                              _seleccionarImagen(ImageSource.camera),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade800,
                          ),
                          icon: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Usar Cámara",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _seleccionarImagen(ImageSource.gallery),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                          ),
                          icon: const Icon(
                            Icons.photo_library,
                            color: Colors.white,
                          ),
                          label: const Text(
                            "Galería",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    _imagenesSeleccionadas.isEmpty
                        ? const Text(
                            "No has seleccionado ninguna foto.",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        : SizedBox(
                            height: 90,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _imagenesSeleccionadas.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 10),
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        image: DecorationImage(
                                          image: FileImage(
                                            _imagenesSeleccionadas[index],
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 10,
                                      child: GestureDetector(
                                        onTap: () => _removerImagen(index),
                                        child: const CircleAvatar(
                                          radius: 12,
                                          backgroundColor: Colors.red,
                                          child: Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                    const SizedBox(height: 35),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _publicarAporte,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Publicar Ahora",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
