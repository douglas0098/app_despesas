import 'package:flutter/material.dart';
import '../database/db_helper.dart';
import '../models/categoria.dart';
import '../models/cartao.dart';
import '../models/boleto.dart';
import '../models/lancamento.dart';

class NovoLancamentoScreen extends StatefulWidget {
  const NovoLancamentoScreen({super.key});

  @override
  State<NovoLancamentoScreen> createState() => _NovoLancamentoScreenState();
}

class _NovoLancamentoScreenState extends State<NovoLancamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoCtrl = TextEditingController();
  final _valorCtrl = TextEditingController();

  TipoLancamento _tipo = TipoLancamento.despesa;
  DateTime _data = DateTime.now();

  List<Categoria> _categorias = [];
  List<Cartao> _cartoes = [];
  List<Boleto> _boletos = [];

  Categoria? _categoriaSelecionada;
  Cartao? _cartaoSelecionado;
  Boleto? _boletoSelecionado;

  // 'categoria', 'cartao' ou 'boleto'
  String _origem = 'categoria';

  @override
  void initState() {
    super.initState();
    _carregarListas();
  }

  Future<void> _carregarListas() async {
    final categorias = await DBHelper.instance.listarCategorias();
    final cartoes = await DBHelper.instance.listarCartoes();
    final boletos = await DBHelper.instance.listarBoletos();
    setState(() {
      _categorias = categorias;
      _cartoes = cartoes;
      _boletos = boletos;
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

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final valor =
        double.parse(_valorCtrl.text.replaceAll('.', '').replaceAll(',', '.'));

    final lancamento = Lancamento(
      tipo: _tipo,
      descricao: _descricaoCtrl.text.trim(),
      valor: valor,
      data: _data,
      categoriaId: _origem == 'categoria' ? _categoriaSelecionada?.id : null,
      cartaoId: _origem == 'cartao' ? _cartaoSelecionado?.id : null,
      boletoId: _origem == 'boleto' ? _boletoSelecionado?.id : null,
    );

    await DBHelper.instance.inserirLancamento(lancamento);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 12),
              const Text('Vincular a:', style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<String>(
                title: const Text('Categoria'),
                value: 'categoria',
                groupValue: _origem,
                onChanged: (v) => setState(() => _origem = v!),
              ),
              if (_origem == 'categoria')
                DropdownButtonFormField<Categoria>(
                  initialValue: _categoriaSelecionada,
                  hint: const Text('Selecione a categoria'),
                  items: _categorias
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.nome)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoriaSelecionada = v),
                ),
              RadioListTile<String>(
                title: const Text('Cartão'),
                value: 'cartao',
                groupValue: _origem,
                onChanged: (v) => setState(() => _origem = v!),
              ),
              if (_origem == 'cartao')
                DropdownButtonFormField<Cartao>(
                  initialValue: _cartaoSelecionado,
                  hint: const Text('Selecione o cartão'),
                  items: _cartoes
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.nome)))
                      .toList(),
                  onChanged: (v) => setState(() => _cartaoSelecionado = v),
                ),
              RadioListTile<String>(
                title: const Text('Boleto/Conta fixa'),
                value: 'boleto',
                groupValue: _origem,
                onChanged: (v) => setState(() => _origem = v!),
              ),
              if (_origem == 'boleto')
                DropdownButtonFormField<Boleto>(
                  initialValue: _boletoSelecionado,
                  hint: const Text('Selecione o boleto'),
                  items: _boletos
                      .map((b) => DropdownMenuItem(value: b, child: Text(b.nome)))
                      .toList(),
                  onChanged: (v) => setState(() => _boletoSelecionado = v),
                ),
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
