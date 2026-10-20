import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/cartao.dart';

class CartoesScreen extends StatefulWidget {
  const CartoesScreen({super.key});

  @override
  State<CartoesScreen> createState() => _CartoesScreenState();
}

class _CartoesScreenState extends State<CartoesScreen> {
  List<Cartao> _cartoes = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await DBHelper.instance.listarCartoes();
    setState(() => _cartoes = lista);
  }

  Future<void> _novoCartao() async {
    final nomeCtrl = TextEditingController();
    final diaCtrl = TextEditingController();

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo cartão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome do cartão'),
            ),
            TextField(
              controller: diaCtrl,
              decoration: const InputDecoration(labelText: 'Dia de vencimento'),
              keyboardType: TextInputType.number,
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
      await DBHelper.instance.inserirCartao(
        Cartao(nome: nomeCtrl.text.trim(), diaVencimento: int.parse(diaCtrl.text)),
      );
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cartões')),
      body: _cartoes.isEmpty
          ? const Center(child: Text('Nenhum cartão cadastrado.'))
          : ListView.builder(
              itemCount: _cartoes.length,
              itemBuilder: (context, i) {
                final c = _cartoes[i];
                return ListTile(
                  leading: const Icon(Icons.credit_card),
                  title: Text(c.nome),
                  subtitle: Text('Vencimento: dia ${c.diaVencimento}'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novoCartao,
        child: const Icon(Icons.add),
      ),
    );
  }
}
