import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialModal {
  static void mostrar(BuildContext context, String uidUsuario) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                "Historial de Intercambios 📋✨",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              const Text(
                "Lista de aportes completados exitosamente en la comunidad.",
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const Divider(height: 25),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('historial')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    var logs = snapshot.data!.docs.where((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      return data['emisorId'] == uidUsuario ||
                          data['receptorId'] == uidUsuario;
                    }).toList();

                    if (logs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No hay intercambios registrados aún.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        var data = logs[index].data() as Map<String, dynamic>;
                        String titulo =
                            data['tituloActividad'] ?? 'Intercambio';
                        String fecha = data['fecha'] ?? '';
                        bool esEmisor = data['emisorId'] == uidUsuario;

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: Icon(
                              esEmisor
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: esEmisor ? Colors.red : Colors.green,
                            ),
                            title: Text(titulo),
                            subtitle: Text(fecha),
                            trailing: Text(
                              esEmisor ? "Aportado" : "Recibido",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: esEmisor ? Colors.red : Colors.green,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
