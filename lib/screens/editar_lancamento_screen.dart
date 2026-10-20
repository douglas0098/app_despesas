import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/lancamento.dart';
import '../utils/date_utils.dart';

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

  @override
  void initState() {
    super.initState();
    _descricaoCtrl = TextEditingController(text: widget.lancamento.descricao);
    _valorCtrl = TextEditingController(
        text: widget.lancamento.valor.toStringAsFixed(2).replaceAll('.', ','));
    _diaPagamentoCtrl =
        TextEditingController(text: widget.lancamento.dataPagamento.day.toString());
    _data = widget.lancamento.data;
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

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final valor =
        double.parse(_valorCtrl.text.replaceAll('.', '').replaceAll(',', '.'));
    final diaPagamento =
        int.tryParse(_diaPagamentoCtrl.text) ?? widget.lancamento.dataPagamento.day;

    final atualizado = widget.lancamento.copyWith(
      descricao: _descricaoCtrl.text.trim(),
      valor: valor,
      data: _data,
      dataPagamento: widget.lancamento.tipo == TipoLancamento.receita
          ? _data
          : DateTime(_data.year, _data.month,
              clampDiaNoMes(_data.year, _data.month, diaPagamento)),
    );

    await DBHelper.instance.atualizarLancamento(atualizado);
    if (mounted) Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    final l = widget.lancamento;
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
                  child: Chip(label: Text('Parcela ${l.parcelaInfo}')),
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
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe um valor';
                  final normalizado = v.replaceAll('.', '').replaceAll(',', '.');
                  if (double.tryParse(normalizado) == null) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Data: ${_data.day.toString().padLeft(2, '0')}/${_data.month.toString().padLeft(2, '0')}/${_data.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selecionarData,
              ),
              if (l.tipo == TipoLancamento.despesa) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _diaPagamentoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dia de pagamento',
                    helperText: 'Dia usado no cálculo do saldo por receita',
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
                onPressed: _salvar,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Salvar alterações'),
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
