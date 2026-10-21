import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/lancamento.dart';
import '../utils/parcelas_utils.dart';

class EditarLancamentoScreen extends StatefulWidget {
  final Lancamento lancamento;
  const EditarLancamentoScreen({super.key, required this.lancamento});

  @override
  State<EditarLancamentoScreen> createState() => _EditarLancamentoScreenState();
}

class _EditarLancamentoScreenState extends State<EditarLancamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descricaoCtrl;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _diaPagamentoCtrl;
  late DateTime _data;

  /// Parcelas da mesma compra (só quando este lançamento é uma parcela).
  /// Enquanto é nulo, o grupo ainda está sendo carregado.
  List<Lancamento>? _parcelas;
  double _totalOriginal = 0;

  bool get _ehParcela =>
      widget.lancamento.grupoId != null && widget.lancamento.parcelaInfo != null;

  @override
  void initState() {
    super.initState();
    _descricaoCtrl = TextEditingController(text: widget.lancamento.descricao);
    _valorCtrl = TextEditingController(text: _fmt(widget.lancamento.valor));
    _diaPagamentoCtrl =
        TextEditingController(text: widget.lancamento.dataPagamento.day.toString());
    _data = widget.lancamento.data;
    if (_ehParcela) _carregarParcelas();
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    _diaPagamentoCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  double? _parseValor(String texto) =>
      double.tryParse(texto.replaceAll('.', '').replaceAll(',', '.'));

  /// Carrega todas as parcelas da compra: o campo de valor passa a mostrar
  /// o valor TOTAL da compra, e a edição vale para todas elas.
  Future<void> _carregarParcelas() async {
    List<Lancamento> parcelas;
    try {
      parcelas = await DBHelper.instance
          .listarLancamentosDoGrupo(widget.lancamento.grupoId!);
    } catch (_) {
      parcelas = [];
    }
    if (parcelas.isEmpty) parcelas = [widget.lancamento];
    if (!mounted) return;

    final total = parcelas.fold(0.0, (s, p) => s + p.valor);
    setState(() {
      _parcelas = parcelas;
      _totalOriginal = double.parse(total.toStringAsFixed(2));
      _valorCtrl.text = _fmt(_totalOriginal);
      // O campo de data de uma compra parcelada é a data da COMPRA (a da
      // primeira parcela), e não a data da parcela que foi aberta.
      _data = parcelas.first.data;
    });
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

  bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final l = widget.lancamento;
    final descricao = _descricaoCtrl.text.trim();
    final valor = _parseValor(_valorCtrl.text)!;
    final diaPagamento = int.tryParse(_diaPagamentoCtrl.text) ?? l.dataPagamento.day;

    if (_ehParcela && _parcelas != null) {
      await _salvarCompraParcelada(descricao, valor, diaPagamento);
    } else {
      // Data de pagamento deste lançamento. O mês de pagamento acompanha o
      // deslocamento da data da compra, mas NÃO é recalculado a partir do
      // mês da compra (isso fazia compras no cartão sumirem do mês em que
      // são pagas).
      final dataPagamento = l.tipo == TipoLancamento.receita
          ? _data
          : pagamentoAposMudarData(
              dataAnterior: l.data,
              dataNova: _data,
              pagamentoAnterior: l.dataPagamento,
              dia: diaPagamento,
            );

      final atualizado = l.copyWith(
        descricao: descricao,
        valor: valor,
        data: _data,
        dataPagamento: dataPagamento,
      );
      await DBHelper.instance.atualizarLancamento(atualizado);
    }

    if (mounted) Navigator.pop(context, true);
  }

  /// Salva a edição de uma compra parcelada, aplicando a TODAS as parcelas:
  ///  - nova data da compra: as parcelas passam a cair nos meses seguintes à
  ///    nova data (e os vencimentos acompanham o mesmo deslocamento);
  ///  - novo valor total: redividido entre as parcelas;
  ///  - novo dia de pagamento e nova descrição.
  /// Só o que o usuário realmente mudou é propagado.
  Future<void> _salvarCompraParcelada(
      String descricao, double valor, int diaPagamento) async {
    final l = widget.lancamento;
    var lista = List<Lancamento>.of(_parcelas!);

    // A "data da compra" é a data da primeira parcela.
    final dataCompraAtual = lista.first.data;
    if (!_mesmoDia(_data, dataCompraAtual)) {
      // Se a compra foi no cartão, o deslocamento considera o fechamento da
      // fatura (comprar depois do fechamento joga para a fatura seguinte).
      int? diaFechamento;
      int? diaVencimento;
      if (l.cartaoId != null) {
        final cartoes = await DBHelper.instance.listarCartoes();
        final indice = cartoes.indexWhere((c) => c.id == l.cartaoId);
        if (indice != -1) {
          diaFechamento = cartoes[indice].diaFechamento;
          diaVencimento = cartoes[indice].diaVencimento;
        }
      }
      final deslocamento = deslocamentoDePagamento(
        dataAnterior: dataCompraAtual,
        dataNova: _data,
        diaFechamento: diaFechamento,
        diaVencimento: diaVencimento,
      );
      lista = mudarDataDaCompraParcelada(lista, _data, deslocamento);
    }

    final descricaoMudou = descricao != l.descricao;
    final totalMudou = (valor - _totalOriginal).abs() > 0.004;
    final diaMudou = diaPagamento != l.dataPagamento.day;

    final resultado = aplicarEdicaoNasParcelas(
      lista,
      novaDescricao: descricaoMudou ? descricao : null,
      novoValorTotal: totalMudou ? valor : null,
      novoDiaPagamento: diaMudou ? diaPagamento : null,
    );
    await DBHelper.instance.atualizarLancamentosEmLote(resultado);
  }

  Future<void> _excluir() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lançamento'),
        content: const Text('Tem certeza que deseja excluir este lançamento?'),
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

    if (confirmar == true && widget.lancamento.id != null) {
      await DBHelper.instance.removerLancamento(widget.lancamento.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _excluirGrupoCompleto() async {
    final grupoId = widget.lancamento.grupoId;
    if (grupoId == null) return;

    final total = await DBHelper.instance.contarLancamentosDoGrupo(grupoId);
    if (!mounted) return;

    final ehParcela = widget.lancamento.parcelaInfo != null;
    final substantivo = ehParcela ? 'parcelas' : 'ocorrências';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir todas as $substantivo'),
        content: Text(
          'Isso vai excluir as $total $substantivo desse lançamento '
          '(passadas e futuras), não só essa. Essa ação não pode ser desfeita. '
          'Deseja continuar?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir tudo ($total)'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await DBHelper.instance.removerGrupoCompleto(grupoId);
      if (mounted) Navigator.pop(context, true);
    }
  }

  /// Texto de apoio do campo de valor de uma compra parcelada, mostrando
  /// como o total digitado ficará dividido.
  String _resumoDivisao() {
    final n = _parcelas?.length ?? 1;
    final total = _parseValor(_valorCtrl.text);
    if (total == null || n < 2) return '';
    final valores = dividirEmParcelas(total, n);
    if (valores.first == valores.last) {
      return '$n parcelas de R\$ ${_fmt(valores.first)}';
    }
    return '${n - 1} parcelas de R\$ ${_fmt(valores.first)} '
        'e a última de R\$ ${_fmt(valores.last)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lancamento;
    final carregandoParcelas = _ehParcela && _parcelas == null;
    final nParcelas = _parcelas?.length ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar lançamento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _excluir,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (l.parcelaInfo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Chip(label: Text('Parcela ${l.parcelaInfo}')),
                      const SizedBox(height: 6),
                      Text(
                        'Descrição, data da compra, valor total e dia de '
                        'pagamento valem para todas as parcelas.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
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
                  labelText:
                      _ehParcela ? 'Valor total da compra (R\$)' : 'Valor (R\$)',
                  helperText:
                      _ehParcela && nParcelas > 1 ? _resumoDivisao() : null,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe um valor';
                  if (_parseValor(v) == null) return 'Valor inválido';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${_ehParcela ? 'Data da compra' : 'Data'}: ${_data.day.toString().padLeft(2, '0')}/${_data.month.toString().padLeft(2, '0')}/${_data.year}'),
                subtitle: _ehParcela
                    ? const Text(
                        'Muda a data e os vencimentos de todas as parcelas')
                    : null,
                trailing: const Icon(Icons.calendar_today),
                onTap: _selecionarData,
              ),
              if (l.tipo == TipoLancamento.despesa) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _diaPagamentoCtrl,
                  decoration: InputDecoration(
                    labelText: 'Dia de pagamento',
                    helperText: _ehParcela
                        ? 'Muda o dia em todas as parcelas, mantendo o mês de cada uma'
                        : 'Dia usado no cálculo do saldo por receita',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
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
                onPressed: carregandoParcelas ? null : _salvar,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(carregandoParcelas
                      ? 'Carregando parcelas...'
                      : 'Salvar alterações'),
                ),
              ),
              if (l.grupoId != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  icon: const Icon(Icons.delete_sweep),
                  label: Text(
                    l.parcelaInfo != null
                        ? 'Excluir todas as parcelas'
                        : 'Excluir todas as ocorrências',
                  ),
                  onPressed: _excluirGrupoCompleto,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
