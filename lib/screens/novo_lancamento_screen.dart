import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/cartao.dart';
import '../models/lancamento.dart';
import '../utils/date_utils.dart';
import '../utils/parcelas_utils.dart';

class NovoLancamentoScreen extends StatefulWidget {
  const NovoLancamentoScreen({super.key});

  @override
  State<NovoLancamentoScreen> createState() => _NovoLancamentoScreenState();
}

class _NovoLancamentoScreenState extends State<NovoLancamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();
  final _diaRecorrenciaCtrl = TextEditingController();
  final _parcelasCtrl = TextEditingController(text: '1');
  final _diaPagamentoCtrl = TextEditingController();

  TipoLancamento _tipo = TipoLancamento.despesa;
  DateTime _data = DateTime.now();

  List<Cartao> _cartoes = [];
  Cartao? _cartaoSelecionado;

  bool _ehCompraNoCartao = false;
  bool _recorrente = false;

  @override
  void initState() {
    super.initState();
    _carregarCartoes();
  }

  Future<void> _carregarCartoes() async {
    final cartoes = await DBHelper.instance.listarCartoes();
    setState(() => _cartoes = cartoes);
  }

  Future<void> _selecionarData() async {
    final novaData = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (novaData != null) setState(() => _data = novaData);
  }

  double _parseValor(String texto) {
    return double.parse(texto.replaceAll('.', '').replaceAll(',', '.'));
  }

  /// Calcula a data de pagamento de uma despesa (ou de uma parcela):
  ///  - compra no cartão: o mês é o do vencimento da fatura (respeitando o
  ///    fechamento). Se o usuário informou um dia de pagamento, só o DIA
  ///    muda, dentro do mês da fatura — ou seja, pagar antes do vencimento é
  ///    um adiantamento da fatura, e não uma compra do mês em que foi feita;
  ///  - sem cartão: a própria data da despesa, com o dia de pagamento manual
  ///    se informado.
  DateTime _calcularDataPagamentoDespesa(DateTime dataBase) {
    final cartao = _ehCompraNoCartao ? _cartaoSelecionado : null;
    return dataDePagamentoDaDespesa(
      dataCompra: dataBase,
      diaFechamento: cartao?.diaFechamento,
      diaVencimento: cartao?.diaVencimento,
      diaManual: int.tryParse(_diaPagamentoCtrl.text),
    );
  }

  String _fmtData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Texto de apoio do campo "Dia de pagamento" numa compra no cartão,
  /// mostrando quando a (primeira) parcela será paga.
  String _textoPagamentoCartao() {
    final cartao = _cartaoSelecionado;
    if (cartao == null) return 'Selecione o cartão para ver quando será paga';
    final vencimento = calcularVencimentoFatura(
        _data, cartao.diaFechamento, cartao.diaVencimento);
    final pagamento = _calcularDataPagamentoDespesa(_data);
    if (int.tryParse(_diaPagamentoCtrl.text) == null) {
      return 'Em branco: paga no vencimento da fatura, ${_fmtData(vencimento)}';
    }
    final adiantada = pagamento.isBefore(vencimento);
    return 'Paga em ${_fmtData(pagamento)}'
        '${adiantada ? ' (adiantamento da fatura que vence em ${_fmtData(vencimento)})' : ''}';
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final valor = _parseValor(_valorCtrl.text);
    final descricao = _descricaoCtrl.text.trim();
    final cartaoId = _ehCompraNoCartao ? _cartaoSelecionado?.id : null;

    // --- Caso 1: compra parcelada no cartão ---
    final parcelas = int.tryParse(_parcelasCtrl.text) ?? 1;
    if (_ehCompraNoCartao && _tipo == TipoLancamento.despesa && parcelas > 1) {
      final grupoId = await DBHelper.instance.proximoGrupoId();

      // Divide o valor total em parcelas iguais; a última parcela absorve
      // o resto da divisão para o total bater certinho.
      final valorParcela = (valor / parcelas * 100).floor() / 100;
      final diferenca = valor - (valorParcela * parcelas);

      final lista = <Lancamento>[];
      for (var i = 0; i < parcelas; i++) {
        final valorDaVez = i == parcelas - 1 ? valorParcela + diferenca : valorParcela;
        final dataDaVez = addMonths(_data, i);
        lista.add(Lancamento(
          tipo: _tipo,
          descricao: descricao,
          valor: double.parse(valorDaVez.toStringAsFixed(2)),
          data: dataDaVez,
          dataPagamento: _calcularDataPagamentoDespesa(dataDaVez),
          cartaoId: cartaoId,
          grupoId: grupoId,
          parcelaInfo: '${i + 1}/$parcelas',
        ));
      }
      await DBHelper.instance.inserirLancamentosEmLote(lista);
      if (mounted) Navigator.pop(context);
      return;
    }

    // --- Caso 2: despesa fixa ou receita recorrente (repete todo mês) ---
    if (_recorrente) {
      final diaRecorrencia =
          int.tryParse(_diaRecorrenciaCtrl.text) ?? _data.day;
      final grupoId = await DBHelper.instance.proximoGrupoId();

      // Gera as próximas 24 ocorrências (2 anos) a partir do mês
      // selecionado. Ocorrências além disso podem ser criadas depois do
      // mesmo jeito, repetindo o cadastro.
      const totalOcorrencias = 24;
      final dataBase = DateTime(_data.year, _data.month, diaRecorrencia);

      final lista = <Lancamento>[];
      for (var i = 0; i < totalOcorrencias; i++) {
        final dataDaVez = addMonths(dataBase, i);
        lista.add(Lancamento(
          tipo: _tipo,
          descricao: descricao,
          valor: valor,
          data: dataDaVez,
          dataPagamento: dataDaVez, // já é o dia de vencimento/recebimento
          grupoId: grupoId,
        ));
      }
      await DBHelper.instance.inserirLancamentosEmLote(lista);
      if (mounted) Navigator.pop(context);
      return;
    }

    // --- Caso padrão: lançamento único ---
    final dataPagamento = _tipo == TipoLancamento.receita
        ? _data
        : _calcularDataPagamentoDespesa(_data);

    final lancamento = Lancamento(
      tipo: _tipo,
      descricao: descricao,
      valor: valor,
      data: _data,
      dataPagamento: dataPagamento,
      cartaoId: cartaoId,
    );

    await DBHelper.instance.inserirLancamento(lancamento);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final parcelasAtual = int.tryParse(_parcelasCtrl.text) ?? 1;
    final ehDespesa = _tipo == TipoLancamento.despesa;

    return Scaffold(
      appBar: AppBar(title: const Text('Novo lançamento')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SegmentedButton<TipoLancamento>(
                segments: const [
                  ButtonSegment(
                      value: TipoLancamento.despesa,
                      label: Text('Despesa'),
                      icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(
                      value: TipoLancamento.receita,
                      label: Text('Receita'),
                      icon: Icon(Icons.arrow_upward)),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descricaoCtrl,
                decoration: const InputDecoration(labelText: 'Descrição'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Informe uma descrição' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valorCtrl,
                decoration: InputDecoration(
                  labelText: _ehCompraNoCartao && ehDespesa && parcelasAtual > 1
                      ? 'Valor total (R\$)'
                      : 'Valor (R\$)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe um valor';
                  final normalizado = v.replaceAll('.', '').replaceAll(',', '.');
                  if (double.tryParse(normalizado) == null) return 'Valor inválido';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Data: ${_data.day.toString().padLeft(2, '0')}/${_data.month.toString().padLeft(2, '0')}/${_data.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selecionarData,
              ),

              // ---- Compra no cartão (só despesa) ----
              if (ehDespesa) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Compra no cartão'),
                  value: _ehCompraNoCartao,
                  onChanged: (v) => setState(() {
                    _ehCompraNoCartao = v;
                    if (v) _recorrente = false;
                  }),
                ),
                if (_ehCompraNoCartao) ...[
                  DropdownButtonFormField<Cartao>(
                    initialValue: _cartaoSelecionado,
                    hint: const Text('Selecione o cartão'),
                    items: _cartoes
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.nome)))
                        .toList(),
                    onChanged: (v) => setState(() => _cartaoSelecionado = v),
                  ),
                  if (_cartaoSelecionado != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Fecha dia ${_cartaoSelecionado!.diaFechamento} · vence dia ${_cartaoSelecionado!.diaVencimento}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _parcelasCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Número de parcelas',
                      helperText: 'Ex: 5 para dividir em 5 vezes, uma por mês',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (!_ehCompraNoCartao) return null;
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return 'Informe um número válido';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  if (parcelasAtual > 1 && _valorCtrl.text.isNotEmpty)
                    Builder(builder: (context) {
                      final total = double.tryParse(
                          _valorCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
                      if (total == null) return const SizedBox.shrink();
                      final porParcela = total / parcelasAtual;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$parcelasAtual x de R\$ ${porParcela.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      );
                    }),
                ],
              ],

              // ---- Dia de pagamento manual (só despesa, não recorrente) ----
              if (ehDespesa && !_recorrente) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _diaPagamentoCtrl,
                  decoration: InputDecoration(
                    labelText: 'Dia de pagamento (opcional)',
                    helperText: _ehCompraNoCartao
                        ? _textoPagamentoCartao()
                        : 'Em qual dia essa despesa deve ser descontada',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final dia = int.tryParse(v);
                    if (dia == null || dia < 1 || dia > 31) {
                      return 'Informe um dia entre 1 e 31';
                    }
                    return null;
                  },
                ),
              ],

              // ---- Recorrência (despesa fixa ou receita) ----
              // Não aparece para compra no cartão: nesse caso, use
              // parcelamento em vez de recorrência.
              if (!_ehCompraNoCartao) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ehDespesa
                      ? 'Despesa fixa recorrente'
                      : 'Receita recorrente'),
                  subtitle: const Text('Repete todo mês automaticamente'),
                  value: _recorrente,
                  onChanged: (v) {
                    setState(() {
                      _recorrente = v;
                      if (v && _diaRecorrenciaCtrl.text.isEmpty) {
                        _diaRecorrenciaCtrl.text = _data.day.toString();
                      }
                    });
                  },
                ),
                if (_recorrente)
                  TextFormField(
                    controller: _diaRecorrenciaCtrl,
                    decoration: InputDecoration(
                      labelText: ehDespesa
                          ? 'Dia do vencimento'
                          : 'Dia do mês em que a receita cai',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (!_recorrente) return null;
                      final dia = int.tryParse(v ?? '');
                      if (dia == null || dia < 1 || dia > 31) {
                        return 'Informe um dia entre 1 e 31';
                      }
                      return null;
                    },
                  ),
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _salvar,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Salvar lançamento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
