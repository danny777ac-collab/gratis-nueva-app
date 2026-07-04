import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gratis_nueva/supabase_config.dart';

class CandidatosScreen extends StatelessWidget {
  final String donacionId;
  final String coleccionOrigen;

  const CandidatosScreen({
    super.key,
    required this.donacionId,
    required this.coleccionOrigen,
  });

  void _abrirWhatsApp(
    BuildContext context,
    String nombre,
    String telefono,
  ) async {
    if (telefono.isEmpty) return;
    String numeroLimpio = telefono.replaceAll(RegExp(r'[^\d+]'), '');
    if (!numeroLimpio.startsWith('+')) {
      numeroLimpio = '+591$numeroLimpio';
    }

    final Uri whatsappUri = Uri.parse(
      "https://wa.me/$numeroLimpio?text=Hola%20$nombre,%20vi%20tu%20postulación%20en%20Gracia...",
    );
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No se pudo abrir WhatsApp")),
      );
    }
  }

  void _iniciarTransaccion(
    BuildContext context,
    String candidatoUid,
    String candidatoNombre,
  ) async {
    await supabase
        .from(coleccionOrigen)
        .update({
          'transaccion_activa': true,
          'receptorId': candidatoUid,
          'receptorNombre': candidatoNombre,
          'confirmado_por_emisor': false,
          'confirmado_por_receptor': false,
        })
        .eq('id', donacionId);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Trámite iniciado con $candidatoNombre. Esperando confirmación mutua.",
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // --- LÓGICA MEJORADA CON HISTORIAL DE INTERCAMBIOS (Opción 1) ---
  void _procesarConfirmacionFinal(
    BuildContext context,
    String emisorId,
    String receptorId,
    Map<String, dynamic> datosPost,
  ) async {
    // 1. Guardar copia en la colección global de historial antes de borrar el post
    await supabase.from('historial').insert({
      'item': datosPost['item'] ?? 'Sin título',
      'descripcion': datosPost['descripcion'] ?? '',
      'categoria': datosPost['categoria'] ?? 'Cosas',
      'tipo': coleccionOrigen, // 'donaciones' o 'necesidades'
      'emisorId': emisorId,
      'emisorNombre': datosPost['donante'] ?? 'Usuario',
      'receptorId': receptorId,
      'receptorNombre': datosPost['receptorNombre'] ?? 'Candidato',
    });

    // 2. Incrementar los contadores en los perfiles de los usuarios
    final emisorSnap = await supabase
        .from('usuarios')
        .select('donaciones_entregadas, donaciones_recibidas')
        .eq('id', emisorId)
        .maybeSingle();
    final receptorSnap = await supabase
        .from('usuarios')
        .select('donaciones_entregadas, donaciones_recibidas')
        .eq('id', receptorId)
        .maybeSingle();

    if (emisorSnap != null && receptorSnap != null) {
      if (coleccionOrigen == 'donaciones') {
        await supabase.from('usuarios').update({
          'donaciones_entregadas':
              (emisorSnap['donaciones_entregadas'] ?? 0) + 1,
        }).eq('id', emisorId);
        await supabase.from('usuarios').update({
          'donaciones_recibidas':
              (receptorSnap['donaciones_recibidas'] ?? 0) + 1,
        }).eq('id', receptorId);
      } else {
        await supabase.from('usuarios').update({
          'donaciones_recibidas':
              (emisorSnap['donaciones_recibidas'] ?? 0) + 1,
        }).eq('id', emisorId);
        await supabase.from('usuarios').update({
          'donaciones_entregadas':
              (receptorSnap['donaciones_entregadas'] ?? 0) + 1,
        }).eq('id', receptorId);
      }
    }

    // 3. Borrar el documento original del muro
    await supabase.from(coleccionOrigen).delete().eq('id', donacionId);

    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("¡Transacción completada e Historial archivado! 🎉"),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String miUid = supabase.auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Entrega"),
        backgroundColor: Colors.orange,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from(coleccionOrigen)
            .stream(primaryKey: ['id'])
            .eq('id', donacionId),
        builder: (context, postSnapshot) {
          if (!postSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (postSnapshot.data!.isEmpty) {
            return const Center(child: Text("La publicación ya no existe."));
          }

          var postData = postSnapshot.data!.first;
          bool transaccionActiva = postData['transaccion_activa'] ?? false;
          String? receptorId = postData['receptorId'];
          String receptorNombre = postData['receptorNombre'] ?? '';
          String duenoId = postData['duenoId'] ?? '';

          bool verificadoEmisor = postData['confirmado_por_emisor'] ?? false;
          bool verificadoReceptor =
              postData['confirmado_por_receptor'] ?? false;

          if (transaccionActiva) {
            bool soyElEmisor = miUid == duenoId;
            bool soyElReceptor = miUid == receptorId;

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.handshake,
                          size: 60,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          "Trato en Proceso 🤝",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Se requiere que ambos usuarios confirmen que se realizó la entrega física.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const Divider(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Icon(
                                  verificadoEmisor
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: verificadoEmisor
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                const Text(
                                  "Dueño del Post",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Icon(
                                  verificadoReceptor
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: verificadoReceptor
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                                Text(
                                  soyElEmisor
                                      ? receptorNombre
                                      : "Tu Confirmación",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        if (soyElEmisor && !verificadoEmisor)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () async {
                              await supabase
                                  .from(coleccionOrigen)
                                  .update({'confirmado_por_emisor': true})
                                  .eq('id', donacionId);
                              if (verificadoReceptor) {
                                if (!context.mounted) return;
                                _procesarConfirmacionFinal(
                                  context,
                                  duenoId,
                                  receptorId!,
                                  postData,
                                );
                              }
                            },
                            child: const Text(
                              "YO CONFIRMO LA ENTREGA",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        if (soyElReceptor && !verificadoReceptor)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            onPressed: () async {
                              await supabase
                                  .from(coleccionOrigen)
                                  .update({'confirmado_por_receptor': true})
                                  .eq('id', donacionId);
                              if (verificadoEmisor) {
                                if (!context.mounted) return;
                                _procesarConfirmacionFinal(
                                  context,
                                  duenoId,
                                  receptorId!,
                                  postData,
                                );
                              }
                            },
                            child: const Text(
                              "YO CONFIRMO QUE RECIBÍ EL ARTÍCULO",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        if ((soyElEmisor && verificadoEmisor) ||
                            (soyElReceptor && verificadoReceptor))
                          const Text(
                            "⏳ Esperando que la otra parte confirme...",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: Colors.orange,
                            ),
                          ),
                        const SizedBox(height: 15),
                        TextButton.icon(
                          onPressed: () async {
                            await supabase
                                .from(coleccionOrigen)
                                .update({
                                  'transaccion_activa': false,
                                  'receptorId': null,
                                  'receptorNombre': null,
                                  'confirmado_por_emisor': false,
                                  'confirmado_por_receptor': false,
                                })
                                .eq('id', donacionId);
                          },
                          icon: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 16,
                          ),
                          label: const Text(
                            "Cancelar trato y liberar muro",
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('postulantes')
                .stream(primaryKey: ['id'])
                .eq('post_id', donacionId)
                .order('fecha', ascending: true),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var candidatos = snapshot.data!;
              if (candidatos.isEmpty) {
                return const Center(
                  child: Text("Aún no se ha postulado nadie."),
                );
              }

              return ListView.builder(
                itemCount: candidatos.length,
                itemBuilder: (context, index) {
                  var c = candidatos[index];
                  String nombre = c['nombre'] ?? 'Interesado';
                  String telefono = c['telefono'] ?? '';
                  String candidatoUid = c['uid'] ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade100,
                        child: Text(
                          "${index + 1}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                      title: Text(
                        nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Teléfono: $telefono"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.message,
                              color: Colors.green,
                            ),
                            onPressed: () =>
                                _abrirWhatsApp(context, nombre, telefono),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                            ),
                            onPressed: () => _iniciarTransaccion(
                              context,
                              candidatoUid,
                              nombre,
                            ),
                            child: const Text(
                              "ENTREGAR",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
