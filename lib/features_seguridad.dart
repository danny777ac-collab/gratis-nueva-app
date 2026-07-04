import 'package:flutter/material.dart';
import 'package:gratis_nueva/supabase_config.dart';

class SeguridadManager {
  static Future<void> reportarContenido(
    BuildContext context,
    String postId,
    String motivo,
    String usuarioReportadorId,
  ) async {
    try {
      await supabase.from('reportes').insert({
        'postId': postId,
        'motivo': motivo,
        'reportadorId': usuarioReportadorId,
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
