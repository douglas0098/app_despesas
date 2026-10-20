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
  final DateTime data;

  Lancamento({
    this.id,
    required this.tipo,
    this.categoriaId,
    this.cartaoId,
    this.boletoId,
    required this.descricao,
    required this.valor,
    required this.data,
  });

  /// Ano e mês de referência (ex: "2026-09"), usado para agrupar o
  /// dashboard mensal, como as linhas de mês da planilha.
  String get mesReferencia =>
      '${data.year}-${data.month.toString().padLeft(2, '0')}';

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
    };
  }

  factory Lancamento.fromMap(Map<String, dynamic> map) {
    return Lancamento(
      id: map['id'] as int?,
      tipo: tipoLancamentoFromString(map['tipo'] as String),
      categoriaId: map['categoria_id'] as int?,
      cartaoId: map['cartao_id'] as int?,
      boletoId: map['boleto_id'] as int?,
      descricao: map['descricao'] as String,
      valor: (map['valor'] as num).toDouble(),
      data: DateTime.parse(map['data'] as String),
    );
  }
}
