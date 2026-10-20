/// Tipo de categoria, espelhando os blocos da planilha original:
/// - despesaFixa: "Despesas Fixas" (Seguro do carro, Muay Thai, Crédito, Internet...)
/// - receita: "Receitas" (Salário, Adiantamento, Hora Extra, Outros)
/// - outras: "Outras despesas" (Acordo Nubank, etc.)
enum TipoCategoria { despesaFixa, receita, outras }

TipoCategoria tipoCategoriaFromString(String value) {
  return TipoCategoria.values.firstWhere((e) => e.name == value);
}

class Categoria {
  final int? id;
  final String nome;
  final TipoCategoria tipo;

  /// Dia de vencimento (1-31), usado para classificar a categoria na
  /// quinzena 1 (dia <= 14) ou quinzena 2 (dia >= 15) no cálculo de saldo.
  /// Nulo para categorias sem vencimento fixo (ex: receitas avulsas).
  final int? diaVencimento;

  Categoria({
    this.id,
    required this.nome,
    required this.tipo,
    this.diaVencimento,
  });

  /// Quinzena de pagamento: 1 = paga com a primeira renda do mês
  /// (ex: Adiantamento, dia 15), 2 = paga com a segunda (ex: Salário, dia 30).
  /// Replica a divisão "Despesas dia 01" / "Despesas dia 15" da planilha.
  int get quinzena {
    if (diaVencimento == null) return 2;
    return diaVencimento! <= 14 ? 1 : 2;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'tipo': tipo.name,
      'dia_vencimento': diaVencimento,
    };
  }

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      tipo: tipoCategoriaFromString(map['tipo'] as String),
      diaVencimento: map['dia_vencimento'] as int?,
    );
  }
}
