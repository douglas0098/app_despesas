import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import 'lancamentos_screen.dart';
import 'novo_lancamento_screen.dart';
import 'cartoes_screen.dart';
import 'boletos_screen.dart';
import 'categorias_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _mesAtual = DateTime.now();
  SaldoMensal? _saldo;

  String get _mesReferencia =>
      '${_mesAtual.year}-${_mesAtual.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _carregarSaldo();
  }

  Future<void> _carregarSaldo() async {
    final saldo = await DBHelper.instance.calcularSaldoMensal(_mesReferencia);
    setState(() => _saldo = saldo);
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
          IconButton(
            icon: const Icon(Icons.receipt_long),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BoletosScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CategoriasScreen())),
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
              Row(
                children: [
                  Expanded(
                    child: _CardQuinzena(
                      titulo: 'Quinzena 1 (até dia 14)',
                      valor: _saldo!.saldoQuinzena1,
                      fmt: _fmt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CardQuinzena(
                      titulo: 'Quinzena 2 (dia 15+)',
                      valor: _saldo!.saldoQuinzena2,
                      fmt: _fmt,
                    ),
                  ),
                ],
              ),
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

class _CardQuinzena extends StatelessWidget {
  final String titulo;
  final double valor;
  final String Function(double) fmt;

  const _CardQuinzena({
    required this.titulo,
    required this.valor,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(fmt(valor),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
