/// Conta fixa recorrente (ex: "Acordo Nubank (dia 17)" na planilha).
/// Ao abrir o app num novo mês, um lançamento pendente pode ser gerado
/// automaticamente a partir de cada boleto ativo.
class Boleto {
  final int? id;
  final String nome;
  final int diaVencimento;
  final double? valorPadrao;
  final bool ativo;

  Boleto({
    this.id,
    required this.nome,
    required this.diaVencimento,
    this.valorPadrao,
    this.ativo = true,
  });

  int get quinzena => diaVencimento <= 14 ? 1 : 2;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'dia_vencimento': diaVencimento,
      'valor_padrao': valorPadrao,
      'ativo': ativo ? 1 : 0,
    };
  }

  factory Boleto.fromMap(Map<String, dynamic> map) {
    return Boleto(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      diaVencimento: map['dia_vencimento'] as int,
      valorPadrao: (map['valor_padrao'] as num?)?.toDouble(),
      ativo: (map['ativo'] as int) == 1,
    );
  }
}
