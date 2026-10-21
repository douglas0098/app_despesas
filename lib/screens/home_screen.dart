import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/lancamento.dart';
import 'lancamentos_screen.dart';
import 'novo_lancamento_screen.dart';
import 'cartoes_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _mesAtual = DateTime.now();
  SaldoDinamico? _saldo;

  String get _mesReferencia =>
      '${_mesAtual.year}-${_mesAtual.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _carregarSaldo();
  }

  // Identifica a carga mais recente: se o usuário trocar de mês (ou voltar
  // de outra tela) enquanto uma carga anterior ainda roda, o resultado
  // antigo é descartado e não sobrescreve o saldo atual.
  int _cargaAtual = 0;

  Future<void> _carregarSaldo() async {
    final minhaCarga = ++_cargaAtual;
    try {
      final saldo =
          await DBHelper.instance.calcularSaldoDinamico(_mesReferencia);
      if (!mounted || minhaCarga != _cargaAtual) return;
      setState(() => _saldo = saldo);
    } catch (e) {
      if (!mounted || minhaCarga != _cargaAtual) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível atualizar o saldo: $e')),
      );
    }
  }

  void _mudarMes(int delta) {
    setState(() {
      _mesAtual = DateTime(_mesAtual.year, _mesAtual.month + delta, 1);
    });
    _carregarSaldo();
  }

  String _nomeMes(DateTime d) {
    const nomes = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    return '${nomes[d.month - 1]} ${d.year}';
  }

  String _fmt(double v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Despesas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.credit_card),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CartoesScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregarSaldo,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _mudarMes(-1),
                ),
                Text(_nomeMes(_mesAtual),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _mudarMes(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_saldo != null) ...[
              Card(
                color: _saldo!.saldoTotal >= 0
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Saldo do mês',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_fmt(_saldo!.saldoTotal),
                          style: const TextStyle(fontSize: 28)),
                      const Divider(),
                      Text('Receitas: ${_fmt(_saldo!.receitaTotal)}'),
                      Text('Despesas: ${_fmt(_saldo!.despesaTotal)}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_saldo!.periodos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Nenhum lançamento neste mês ainda.'),
                )
              else
                Text('Saldo por receita', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 4),
              ..._saldo!.periodos.map((p) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      title: Text(p.titulo,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.subtitulo.isNotEmpty)
                            Text(p.subtitulo,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Saldo restante',
                                  style: TextStyle(color: Colors.grey.shade700)),
                              Text(
                                _fmt(p.saldo),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: p.saldo >= 0 ? Colors.green.shade700 : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Receita ${_fmt(p.receita)} · Despesas ${_fmt(p.despesa)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      children: [
                        if (p.resumoFontes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Nenhuma despesa descontada dessa receita.'),
                            ),
                          )
                        else
                          ...p.resumoFontes.map((f) => ListTile(
                                dense: true,
                                title: Text(f.nome),
                                trailing: Text(
                                  _fmt(f.valor),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              )),
                      ],
                    ),
                  )),
            ] else
              const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.list),
              label: const Text('Ver lançamentos do mês'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        LancamentosScreen(mesReferencia: _mesReferencia),
                  ),
                );
                _carregarSaldo();
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Novo lançamento'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NovoLancamentoScreen()),
          );
          _carregarSaldo();
        },
      ),
    );
  }
}
