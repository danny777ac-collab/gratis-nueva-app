import 'package:flutter/material.dart';
import 'package:gratis_nueva/supabase_config.dart';
import 'perfil.dart';
import '../donar.dart';
import '../busqueda_screen.dart';
import 'package:gratis_nueva/features_seguridad.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final String currentUid = supabase.auth.currentUser?.id ?? '';

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MuroPrincipalTabs(currentUid: currentUid),
          const BusquedaScreen(),
          PerfilScreen(usuarioId: currentUid),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: _currentIndex == 1
            ? const Color(0xFFFD322F)
            : const Color.fromARGB(255, 10, 10, 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Muros"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Búsqueda"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
      ),
    );
  }
}

class MuroPrincipalTabs extends StatelessWidget {
  final String currentUid;
  const MuroPrincipalTabs({super.key, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Comunidad Gracia",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color.fromARGB(255, 8, 11, 14),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Sin notificaciones")),
              ),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            indicatorColor: Color.fromARGB(255, 247, 244, 244),
            tabs: [
              Tab(icon: Icon(Icons.card_giftcard), text: "Donaciones"),
              Tab(icon: Icon(Icons.gavel), text: "Necesidades"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _construirMuro(coleccion: 'donaciones', esDorado: true),
            _construirMuro(coleccion: 'necesidades', esDorado: false),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton(
            backgroundColor: const Color(0xFF2C3E50),
            onPressed: () => _mostrarDialogoPublicar(
              context,
              DefaultTabController.of(context).index == 0
                  ? "donaciones"
                  : "necesidades",
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _construirMuro({required String coleccion, required bool esDorado}) {
    return Container(
      color: esDorado ? const Color(0xFFF8F8FF) : const Color(0xFF1A1A1A),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from(coleccion)
            .stream(primaryKey: ['id'])
            .order('fecha', ascending: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: posts.length,
            itemBuilder: (context, i) {
              final data = posts[i];
              final List<dynamic> imgs = data['imagenesUrls'] ?? [];
              final List<dynamic> postulantes = data['postulantes'] ?? [];
              final bool esDuenio = (data['usuarioId'] ?? '') == currentUid;
              final bool yaPostulado = postulantes.contains(currentUid);
              final bool estaLleno = postulantes.length >= 3;

              return Card(
                color: esDorado
                    ? Colors.white
                    : const Color.fromARGB(255, 12, 12, 12),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabecera del post
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PerfilScreen(usuarioId: data['usuarioId']),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage:
                                    (data['autorFoto'] != null &&
                                        data['autorFoto'].isNotEmpty)
                                    ? NetworkImage(data['autorFoto'])
                                    : null,
                                child: data['autorFoto'] == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                data['autorNombre'] ?? 'Usuario',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Imágenes
                      if (imgs.isNotEmpty)
                        SizedBox(
                          height: 250,
                          child: PageView.builder(
                            itemCount: imgs.length,
                            itemBuilder: (context, imgIndex) => ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imgs[imgIndex],
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      // Título
                      Text(
                        data['titulo'] ?? 'Sin título',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: esDorado ? Colors.black : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // --- AQUÍ ESTÁ EL ROW CORREGIDO (BANDERA Y BOTÓN ALINEADOS) ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.flag_outlined,
                              color: Color.fromARGB(255, 150, 13, 13),
                              size: 22,
                            ),
                            onSelected: (value) {
                              SeguridadManager.reportarContenido(
                                context,
                                posts[i]['id'],
                                "Reporte: $value",
                                currentUid,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Reporte enviado: $value"),
                                ),
                              );
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: "Contenido indecente",
                                child: Text("Contenido indecente"),
                              ),
                              const PopupMenuItem(
                                value: "Estafa",
                                child: Text("Estafa"),
                              ),
                              const PopupMenuItem(
                                value: "Otro",
                                child: Text("Otro motivo"),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              backgroundColor: esDuenio
                                  ? Colors.green
                                  : (estaLleno && !yaPostulado
                                        ? Colors.grey
                                        : Colors.blueAccent),
                            ),
                            onPressed: () {
                              if (esDuenio) {
                                _mostrarPostulantesModal(context, postulantes);
                              } else if (yaPostulado) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Ya estás registrado."),
                                  ),
                                );
                              } else if (estaLleno) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Cupos llenos."),
                                  ),
                                );
                              } else {
                                supabase
                                    .from(coleccion)
                                    .update({
                                      'postulantes': [...postulantes, currentUid],
                                    })
                                    .eq('id', posts[i]['id']);
                              }
                            },
                            child: Text(
                              esDuenio
                                  ? "Ver"
                                  : (estaLleno && !yaPostulado
                                        ? "Lleno"
                                        : "Me interesa"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _mostrarPostulantesModal(
    BuildContext context,
    List<dynamic> postulantes,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Lista de Postulantes",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Expanded(
              child: postulantes.isEmpty
                  ? const Center(child: Text("Aún no hay postulaciones."))
                  : ListView.builder(
                      itemCount: postulantes.length,
                      itemBuilder: (context, index) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.person),
                          title: Text("Usuario: ${postulantes[index]}"),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoPublicar(BuildContext context, String tipo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Nueva Publicación"),
        content: const Text("¿Es material o servicio?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => DonarScreen(
                    tipoPublicacion: tipo,
                    categoriaPreseleccionada: 'Cosas',
                  ),
                ),
              );
            },
            child: const Text("Material"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => DonarScreen(
                    tipoPublicacion: tipo,
                    categoriaPreseleccionada: 'Servicios',
                  ),
                ),
              );
            },
            child: const Text("Servicio"),
          ),
        ],
      ),
    );
  }
}
