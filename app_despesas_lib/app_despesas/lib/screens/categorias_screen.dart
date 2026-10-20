import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/categoria.dart';

class CategoriasScreen extends StatefulWidget {
  const CategoriasScreen({super.key});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  List<Categoria> _categorias = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await DBHelper.instance.listarCategorias();
    setState(() => _categorias = lista);
  }

  Future<void> _novaCategoria() async {
    final nomeCtrl = TextEditingController();
    final diaCtrl = TextEditingController();
    TipoCategoria tipo = TipoCategoria.despesaFixa;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova categoria'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              DropdownButtonFormField<TipoCategoria>(
                initialValue: tipo,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(
                      value: TipoCategoria.despesaFixa, child: Text('Despesa fixa')),
                  DropdownMenuItem(
                      value: TipoCategoria.receita, child: Text('Receita')),
                  DropdownMenuItem(
                      value: TipoCategoria.outras, child: Text('Outras despesas')),
                ],
                onChanged: (v) => setDialogState(() => tipo = v!),
              ),
              TextField(
                controller: diaCtrl,
                decoration: const InputDecoration(
                    labelText: 'Dia de vencimento (opcional)'),
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
      ),
    );

    if (salvar == true && nomeCtrl.text.trim().isNotEmpty) {
      await DBHelper.instance.inserirCategoria(
        Categoria(
          nome: nomeCtrl.text.trim(),
          tipo: tipo,
          diaVencimento: int.tryParse(diaCtrl.text),
        ),
      );
      _carregar();
    }
  }

  String _tipoLabel(TipoCategoria t) {
    switch (t) {
      case TipoCategoria.despesaFixa:
        return 'Despesa fixa';
      case TipoCategoria.receita:
        return 'Receita';
      case TipoCategoria.outras:
        return 'Outras despesas';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      body: _categorias.isEmpty
          ? const Center(child: Text('Nenhuma categoria cadastrada.'))
          : ListView.builder(
              itemCount: _categorias.length,
              itemBuilder: (context, i) {
                final c = _categorias[i];
                return ListTile(
                  leading: const Icon(Icons.category),
                  title: Text(c.nome),
                  subtitle: Text(
                    '${_tipoLabel(c.tipo)}'
                    '${c.diaVencimento != null ? ' · vencimento dia ${c.diaVencimento}' : ''}',
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _novaCategoria,
        child: const Icon(Icons.add),
      ),
    );
  }
}
