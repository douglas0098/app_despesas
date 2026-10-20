/// Representa um cartão de crédito (ex: "Cartão Mãe", "Cartão Pai" na planilha).
/// Cadastrável livremente pelo usuário, sem limite de quantidade.
class Cartao {
  final int? id;
  final String nome;
  final int diaVencimento;

  Cartao({
    this.id,
    required this.nome,
    required this.diaVencimento,
  });

  /// Mesma lógica de quinzena usada nas categorias: compras no cartão
  /// entram no grupo "dia 01" (quinzena 1) por padrão na planilha original,
  /// pois os dois cartões vencem no dia 10.
  int get quinzena => diaVencimento <= 14 ? 1 : 2;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'dia_vencimento': diaVencimento,
    };
  }

  factory Cartao.fromMap(Map<String, dynamic> map) {
    return Cartao(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      diaVencimento: map['dia_vencimento'] as int,
    );
  }
}
