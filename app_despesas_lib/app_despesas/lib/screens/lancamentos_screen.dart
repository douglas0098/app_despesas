import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/lancamento.dart';

class LancamentosScreen extends StatefulWidget {
  final String mesReferencia;
  const LancamentosScreen({super.key, required this.mesReferencia});

  @override
  State<LancamentosScreen> createState() => _LancamentosScreenState();
}

class _LancamentosScreenState extends State<LancamentosScreen> {
  List<Lancamento> _lancamentos = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista =
        await DBHelper.instance.listarLancamentosDoMes(widget.mesReferencia);
    setState(() => _lancamentos = lista);
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lançamentos do mês')),
      body: _lancamentos.isEmpty
          ? const Center(child: Text('Nenhum lançamento neste mês ainda.'))
          : ListView.builder(
              itemCount: _lancamentos.length,
              itemBuilder: (context, index) {
                final l = _lancamentos[index];
                final isDespesa = l.tipo == TipoLancamento.despesa;
                return Dismissible(
                  key: ValueKey(l.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await DBHelper.instance.removerLancamento(l.id!);
                  },
                  child: ListTile(
                    leading: Icon(
                      isDespesa ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isDespesa ? Colors.red : Colors.green,
                    ),
                    title: Text(l.descricao),
                    subtitle: Text(
                        '${l.data.day.toString().padLeft(2, '0')}/${l.data.month.toString().padLeft(2, '0')}/${l.data.year}'),
                    trailing: Text(
                      _fmt(l.valor),
                      style: TextStyle(
                        color: isDespesa ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
