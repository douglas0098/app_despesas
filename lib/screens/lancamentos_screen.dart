import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/lancamento.dart';
import 'editar_lancamento_screen.dart';

enum CriterioOrdenacao { descricao, valor, tipo, dataPagamento, categoria }

extension on CriterioOrdenacao {
  String get label {
    switch (this) {
      case CriterioOrdenacao.descricao:
        return 'Descrição';
      case CriterioOrdenacao.valor:
        return 'Valor';
      case CriterioOrdenacao.tipo:
        return 'Tipo (Receita/Despesa)';
      case CriterioOrdenacao.dataPagamento:
        return 'Data de vencimento';
      case CriterioOrdenacao.categoria:
        return 'Categoria';
    }
  }
}

class LancamentosScreen extends StatefulWidget {
  final String mesReferencia;
  const LancamentosScreen({super.key, required this.mesReferencia});

  @override
  State<LancamentosScreen> createState() => _LancamentosScreenState();
}

class _LancamentosScreenState extends State<LancamentosScreen> {
  List<Lancamento> _lancamentos = [];

  CriterioOrdenacao _criterio = CriterioOrdenacao.dataPagamento;
  bool _crescente = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista =
        await DBHelper.instance.listarLancamentosDoMes(widget.mesReferencia);
    setState(() {
      _lancamentos = lista;
      _ordenar();
    });
  }

  /// Rótulo de categoria usado tanto na exibição quanto na ordenação:
  /// Cartão (compra vinculada a um cartão), Despesa Fixa / Receita Fixa
  /// (recorrente, sem cartão) ou Outros (lançamento avulso).
  String _categoriaLabel(Lancamento l) {
    if (l.cartaoId != null) return 'Cartão';
    if (l.grupoId != null) {
      return l.tipo == TipoLancamento.receita ? 'Receita Fixa' : 'Despesa Fixa';
    }
    return 'Outros';
  }

  void _ordenar() {
    int comparar(Lancamento a, Lancamento b) {
      switch (_criterio) {
        case CriterioOrdenacao.descricao:
          return a.descricao.toLowerCase().compareTo(b.descricao.toLowerCase());
        case CriterioOrdenacao.valor:
          return a.valor.compareTo(b.valor);
        case CriterioOrdenacao.tipo:
          return a.tipo.name.compareTo(b.tipo.name);
        case CriterioOrdenacao.dataPagamento:
          return a.dataPagamento.compareTo(b.dataPagamento);
        case CriterioOrdenacao.categoria:
          return _categoriaLabel(a).compareTo(_categoriaLabel(b));
      }
    }

    _lancamentos.sort((a, b) => _crescente ? comparar(a, b) : comparar(b, a));
  }

  void _selecionarCriterio(CriterioOrdenacao criterio) {
    setState(() {
      if (_criterio == criterio) {
        _crescente = !_crescente;
      } else {
        _criterio = criterio;
        _crescente = true;
      }
      _ordenar();
    });
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  bool _dataPagamentoDiferente(Lancamento l) {
    return l.tipo == TipoLancamento.despesa &&
        (l.dataPagamento.day != l.data.day ||
            l.dataPagamento.month != l.data.month);
  }

  Future<void> _abrirEdicao(Lancamento l) async {
    final alterado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditarLancamentoScreen(lancamento: l)),
    );
    if (alterado == true) _carregar();
  }

  Future<bool> _confirmarExclusao(Lancamento l) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lançamento'),
        content: Text('Deseja excluir "${l.descricao}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Não')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    return confirmar ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lançamentos do mês'),
        actions: [
          PopupMenuButton<CriterioOrdenacao>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar por',
            onSelected: _selecionarCriterio,
            itemBuilder: (context) => CriterioOrdenacao.values.map((c) {
              final selecionado = c == _criterio;
              return PopupMenuItem(
                value: c,
                child: Row(
                  children: [
                    if (selecionado)
                      Icon(
                        _crescente ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 16,
                      )
                    else
                      const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(
                      c.label,
                      style: TextStyle(
                        fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.sort, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  'Ordenado por ${_criterio.label} '
                  '(${_crescente ? 'crescente' : 'decrescente'})',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Expanded(
            child: _lancamentos.isEmpty
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
                        confirmDismiss: (_) => _confirmarExclusao(l),
                        onDismissed: (_) async {
                          await DBHelper.instance.removerLancamento(l.id!);
                        },
                        child: ListTile(
                          onTap: () => _abrirEdicao(l),
                          leading: Icon(
                            isDespesa ? Icons.arrow_downward : Icons.arrow_upward,
                            color: isDespesa ? Colors.red : Colors.green,
                          ),
                          title: Text(l.descricao),
                          subtitle: Text(
                            '${_categoriaLabel(l)} · '
                            '${l.data.day.toString().padLeft(2, '0')}/${l.data.month.toString().padLeft(2, '0')}/${l.data.year}'
                            '${l.parcelaInfo != null ? ' · parcela ${l.parcelaInfo}' : ''}'
                            '${_dataPagamentoDiferente(l) ? ' · paga dia ${l.dataPagamento.day}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _fmt(l.valor),
                                style: TextStyle(
                                  color: isDespesa ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () => _abrirEdicao(l),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
