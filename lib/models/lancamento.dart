enum TipoLancamento { despesa, receita }

TipoLancamento tipoLancamentoFromString(String value) {
  return TipoLancamento.values.firstWhere((e) => e.name == value);
}

/// Registro único de despesa ou receita, inserido manualmente pelo usuário.
/// Equivale a uma célula preenchida na planilha (uma compra no cartão,
/// uma despesa fixa do mês, uma receita).
class Lancamento {
  final int? id;
  final TipoLancamento tipo;
  final int? categoriaId;
  final int? cartaoId;
  final int? boletoId;
  final String descricao;
  final double valor;

  /// Data da compra/recebimento em si (o que você digitou na tela).
  final DateTime data;

  /// Data efetiva de dedução/recebimento, usada para decidir em qual
  /// painel de saldo (receita) e em qual mês o lançamento entra. Para
  /// receitas, é sempre igual a [data]. Para despesas, é calculada a
  /// partir do vencimento da categoria/cartão/boleto vinculado — ou
  /// sobrescrita manualmente pelo usuário.
  final DateTime dataPagamento;

  /// Identifica um conjunto de lançamentos gerados juntos: as parcelas de
  /// uma compra no cartão, ou as ocorrências futuras de uma recorrência.
  /// Nulo para lançamentos avulsos.
  final int? grupoId;

  /// Texto de exibição opcional, ex: "2/5" para a 2ª de 5 parcelas.
  final String? parcelaInfo;

  Lancamento({
    this.id,
    required this.tipo,
    this.categoriaId,
    this.cartaoId,
    this.boletoId,
    required this.descricao,
    required this.valor,
    required this.data,
    DateTime? dataPagamento,
    this.grupoId,
    this.parcelaInfo,
  }) : dataPagamento = dataPagamento ?? data;

  /// Ano e mês de referência (ex: "2026-09"), baseado na data de
  /// pagamento — é o mês em que o lançamento efetivamente pesa no saldo.
  String get mesReferencia =>
      '${dataPagamento.year}-${dataPagamento.month.toString().padLeft(2, '0')}';

  Lancamento copyWith({
    int? id,
    TipoLancamento? tipo,
    int? categoriaId,
    int? cartaoId,
    int? boletoId,
    String? descricao,
    double? valor,
    DateTime? data,
    DateTime? dataPagamento,
    int? grupoId,
    String? parcelaInfo,
  }) {
    return Lancamento(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      categoriaId: categoriaId ?? this.categoriaId,
      cartaoId: cartaoId ?? this.cartaoId,
      boletoId: boletoId ?? this.boletoId,
      descricao: descricao ?? this.descricao,
      valor: valor ?? this.valor,
      data: data ?? this.data,
      dataPagamento: dataPagamento ?? this.dataPagamento,
      grupoId: grupoId ?? this.grupoId,
      parcelaInfo: parcelaInfo ?? this.parcelaInfo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo.name,
      'categoria_id': categoriaId,
      'cartao_id': cartaoId,
      'boleto_id': boletoId,
      'descricao': descricao,
      'valor': valor,
      'data': data.toIso8601String(),
      'data_pagamento': dataPagamento.toIso8601String(),
      'grupo_id': grupoId,
      'parcela_info': parcelaInfo,
    };
  }

  factory Lancamento.fromMap(Map<String, dynamic> map) {
    final data = DateTime.parse(map['data'] as String);
    return Lancamento(
      id: map['id'] as int?,
      tipo: tipoLancamentoFromString(map['tipo'] as String),
      categoriaId: map['categoria_id'] as int?,
      cartaoId: map['cartao_id'] as int?,
      boletoId: map['boleto_id'] as int?,
      descricao: map['descricao'] as String,
      valor: (map['valor'] as num).toDouble(),
      data: data,
      // Fallback para lançamentos gravados antes desse campo existir.
      dataPagamento: map['data_pagamento'] != null
          ? DateTime.parse(map['data_pagamento'] as String)
          : data,
      grupoId: map['grupo_id'] as int?,
      parcelaInfo: map['parcela_info'] as String?,
    );
  }
}
