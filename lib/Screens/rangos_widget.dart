// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class RangosWidget extends StatelessWidget {
  final int donaciones; // Nombre actualizado
  final String? nombrePersonalizado;
  final bool esMiPerfil;

  const RangosWidget({
    super.key,
    required this.donaciones, // Nombre actualizado
    required this.nombrePersonalizado,
    required this.esMiPerfil,
  });

  // Calcula el rango basándose en las donaciones
  Map<String, dynamic> _obtenerInfoRango() {
    if (donaciones >= 10000) {
      return {'nivel': 'Mesías', 'estrellas': 5, 'color': Colors.amber};
    } else if (donaciones >= 1000) {
      return {'nivel': 'Filántropo', 'estrellas': 4, 'color': Colors.blue};
    } else if (donaciones >= 100) {
      return {'nivel': 'Padrino', 'estrellas': 3, 'color': Colors.green};
    } else if (donaciones >= 20) {
      return {'nivel': 'Común', 'estrellas': 2, 'color': Colors.grey};
    } else {
      return {'nivel': 'Inicial', 'estrellas': 1, 'color': Colors.brown};
    }
  }

  void _mostrarInfoRangos(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(0.9), // Fondo transparente
        title: const Text("Rangos de Donación"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1-20: Inicial (1★)"),
            Text("20-100: Común (2★)"),
            Text("100-1000: Padrino (3★)"),
            Text("1000-10000: Filántropo (4★)"),
            Text("10000+: Mesías (5★)"),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _obtenerInfoRango();

    // Envolvemos todo en Center para asegurar la posición
    return Center(
      child: GestureDetector(
        onTap: () {
          if (esMiPerfil && donaciones >= 10000) {
            _abrirEditorNombre(context);
          } else {
            _mostrarInfoRangos(context);
          }
        },
        child: Row(
          mainAxisSize: MainAxisSize.min, // Esto mantiene las estrellas juntas
          mainAxisAlignment:
              MainAxisAlignment.center, // Esto centra las estrellas en la fila
          children: List.generate(
            info['estrellas'],
            (index) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 2.0,
              ), // Un poco de espacio entre estrellas
              child: Icon(Icons.star, color: info['color'], size: 30),
            ),
          ),
        ),
      ),
    );
  }

  void _abrirEditorNombre(BuildContext context) {
    // Aquí implementas tu lógica de TextField para elegir:
    // Jesucristo, Buda, Mahoma, Alá u otro.
  }
}
