import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SeguridadManager {
  static Future<void> reportarContenido(
    BuildContext context,
    String postId,
    String motivo,
    String usuarioReportadorId,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('reportes').add({
        'postId': postId,
        'motivo': motivo,
        'reportadorId': usuarioReportadorId,
        'fecha': FieldValue.serverTimestamp(),
        'estado': 'pendiente',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Reporte enviado. Gracias por mantener la comunidad segura.",
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}
