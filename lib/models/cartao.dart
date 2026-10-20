/// Representa um cartão de crédito (ex: "Cartão Mãe", "Cartão Pai" na planilha).
/// Cadastrável livremente pelo usuário, sem limite de quantidade.
class Cartao {
  final int? id;
  final String nome;
  final int diaVencimento;

  /// Dia em que a fatura fecha. Compras feitas depois desse dia caem
  /// automaticamente na fatura do mês seguinte.
  final int diaFechamento;

  Cartao({
    this.id,
    required this.nome,
    required this.diaVencimento,
    required this.diaFechamento,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'dia_vencimento': diaVencimento,
      'dia_fechamento': diaFechamento,
    };
  }

  factory Cartao.fromMap(Map<String, dynamic> map) {
    return Cartao(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      diaVencimento: map['dia_vencimento'] as int,
      // Cartões cadastrados antes desse campo existir recebem o próprio
      // dia de vencimento como fechamento (equivale a nunca "virar o mês").
      diaFechamento: (map['dia_fechamento'] as int?) ?? (map['dia_vencimento'] as int),
    );
  }
}
