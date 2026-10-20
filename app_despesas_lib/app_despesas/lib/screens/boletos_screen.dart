import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/boleto.dart';

class BoletosScreen extends StatefulWidget {
  const BoletosScreen({super.key});

  @override
  State<BoletosScreen> createState() => _BoletosScreenState();
}

class _BoletosScreenState extends State<BoletosScreen> {
  List<Boleto> _boletos = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await DBHelper.instance.listarBoletos(apenasAtivos: false);
    setState(() => _boletos = lista);
  }

  Future<void> _novoBoleto() async {
    final nomeCtrl = TextEditingController();
    final diaCtrl = TextEditingController();
    final valorCtrl = TextEditingController();

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo boleto / conta fixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome (ex: Internet)'),
            ),
            TextField(
              controller: diaCtrl,
              decoration: const InputDecoration(labelText: 'Dia de vencimento'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: valorCtrl,
              decoration: const InputDecoration(
                  labelText: 'Valor padrão (opcional)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar')),
        ],
      ),
    );

    if (salvar == true &&
        nomeCtrl.text.trim().isNotEmpty &&
        int.tryParse(diaCtrl.text) != null) {
      final valor = valorCtrl.text.trim().isEmpty
          ? null
          : double.tryParse(valorCtrl.text.replaceAll(',', '.'));
      await DBHelper.instance.inserirBoleto(
        Boleto(
          nome: nomeCtrl.text.trim(),
          diaVencimento: int.parse(diaCtrl.text),
          valorPadrao: valor,
        ),
      );
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boletos / Contas fixas')),
      body: _boletos.isEmpty
          ? const Center(child: Text('Nenhum boleto cadastrado.'))
          : ListView.builder(
              itemCount: _boletos.length,
              itemBuilder: (context, i) {
                final b = _boletos[i];
                return ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(b.nome),
                  subtitle: Text(
                    'Vencimento: dia ${b.diaVencimento}'
                    '${b.valorPadrao != null ? ' · R\$ ${b.valorPadrao!.toStringAsFixed(2)}' : ''}',
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novoBoleto,
        child: const Icon(Icons.add),
      ),
    );
  }
}
