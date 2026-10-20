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
  final Map<int, List<CompraCartao>> _comprasPorCartao = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await DBHelper.instance.listarCartoes();
    final Map<int, List<CompraCartao>> compras = {};
    for (final c in lista) {
      if (c.id != null) {
        compras[c.id!] = await DBHelper.instance.listarComprasDoCartao(c.id!);
      }
    }
    setState(() {
      _cartoes = lista;
      _comprasPorCartao
        ..clear()
        ..addAll(compras);
    });
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  /// Formulário de nome/fechamento/vencimento, reutilizado para criar e
  /// para editar um cartão existente.
  Future<void> _abrirFormulario({Cartao? cartaoExistente}) async {
    final nomeCtrl = TextEditingController(text: cartaoExistente?.nome ?? '');
    final diaFechCtrl = TextEditingController(
        text: cartaoExistente?.diaFechamento.toString() ?? '');
    final diaVencCtrl = TextEditingController(
        text: cartaoExistente?.diaVencimento.toString() ?? '');

    final salvar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cartaoExistente == null ? 'Novo cartão' : 'Editar cartão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome do cartão'),
            ),
            TextField(
              controller: diaFechCtrl,
              decoration: const InputDecoration(
                labelText: 'Dia de fechamento da fatura',
                helperText: 'Compras após esse dia caem no mês seguinte',
              ),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: diaVencCtrl,
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

    if (salvar != true ||
        nomeCtrl.text.trim().isEmpty ||
        int.tryParse(diaVencCtrl.text) == null ||
        int.tryParse(diaFechCtrl.text) == null) {
      return;
    }

    if (cartaoExistente == null) {
      await DBHelper.instance.inserirCartao(
        Cartao(
          nome: nomeCtrl.text.trim(),
          diaVencimento: int.parse(diaVencCtrl.text),
          diaFechamento: int.parse(diaFechCtrl.text),
        ),
      );
    } else {
      await DBHelper.instance.atualizarCartao(
        Cartao(
          id: cartaoExistente.id,
          nome: nomeCtrl.text.trim(),
          diaVencimento: int.parse(diaVencCtrl.text),
          diaFechamento: int.parse(diaFechCtrl.text),
        ),
      );
    }
    _carregar();
  }

  Future<void> _excluir(Cartao cartao) async {
    final total = await DBHelper.instance.contarLancamentosDoCartao(cartao.id!);

    if (!mounted) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cartão'),
        content: Text(
          total == 0
              ? 'Tem certeza que deseja excluir "${cartao.nome}"?'
              : 'Esse cartão tem $total lançamento(s) vinculado(s). Eles não '
                  'serão apagados, mas deixarão de mostrar o cartão. Deseja '
                  'excluir "${cartao.nome}" mesmo assim?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await DBHelper.instance.removerCartao(cartao.id!);
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
                final compras = _comprasPorCartao[c.id] ?? [];
                final total = compras.fold(0.0, (s, cp) => s + cp.valorTotal);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ExpansionTile(
                    leading: const Icon(Icons.credit_card),
                    title: Row(
                      children: [
                        Expanded(child: Text(c.nome)),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _abrirFormulario(cartaoExistente: c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () => _excluir(c),
                        ),
                      ],
                    ),
                    subtitle: Text(
                        'Fecha dia ${c.diaFechamento} · vence dia ${c.diaVencimento}'),
                    children: [
                      if (compras.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Nenhuma compra vinculada ainda.'),
                          ),
                        )
                      else ...[
                        ...compras.map((compra) => ListTile(
                              dense: true,
                              title: Text(compra.descricao),
                              trailing: Text(
                                compra.numParcelas > 1
                                    ? '${_fmt(compra.valorTotal)} (${compra.numParcelas} Parcelas)'
                                    : _fmt(compra.valorTotal),
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            )),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total no cartão',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                _fmt(total),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirFormulario(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
