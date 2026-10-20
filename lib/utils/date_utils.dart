/// Soma [meses] a [data], ajustando o dia se o mês de destino for mais
/// curto (ex: dia 31 de janeiro + 1 mês vira dia 28/29 de fevereiro).
DateTime addMonths(DateTime data, int meses) {
  final totalMeses = data.month - 1 + meses;
  final anoDestino = data.year + (totalMeses ~/ 12);
  final mesDestino = (totalMeses % 12) + 1;
  final ultimoDiaDoMes = DateTime(anoDestino, mesDestino + 1, 0).day;
  final diaDestino = data.day > ultimoDiaDoMes ? ultimoDiaDoMes : data.day;
  return DateTime(anoDestino, mesDestino, diaDestino);
}

/// Garante que [dia] existe no mês/ano informado (ex: dia 31 em abril
/// vira dia 30, já que abril só tem 30 dias).
int clampDiaNoMes(int ano, int mes, int dia) {
  final ultimoDiaDoMes = DateTime(ano, mes + 1, 0).day;
  return dia > ultimoDiaDoMes ? ultimoDiaDoMes : dia;
}

/// Calcula a data de vencimento efetiva de uma compra no cartão,
/// considerando o dia de fechamento da fatura:
/// - Se a compra foi feita até o dia de fechamento, ela entra na fatura
///   que fecha nesse mês.
/// - Se foi feita depois do fechamento, ela "vira o mês": entra na
///   fatura seguinte.
/// O vencimento da fatura pode cair no mesmo mês do fechamento (ex:
/// fecha dia 4, vence dia 10) ou no mês seguinte (ex: fecha dia 25,
/// vence dia 05), dependendo de qual dia é maior.
DateTime calcularVencimentoFatura(
  DateTime dataCompra,
  int diaFechamento,
  int diaVencimento,
) {
  var mesFatura = dataCompra.month;
  var anoFatura = dataCompra.year;

  if (dataCompra.day > diaFechamento) {
    final proximo = addMonths(DateTime(anoFatura, mesFatura, 1), 1);
    mesFatura = proximo.month;
    anoFatura = proximo.year;
  }

  var mesVencimento = mesFatura;
  var anoVencimento = anoFatura;

  // Se o vencimento cai num dia igual ou anterior ao fechamento, o
  // pagamento acontece no mês seguinte ao fechamento da fatura.
  if (diaVencimento <= diaFechamento) {
    final proximo = addMonths(DateTime(anoVencimento, mesVencimento, 1), 1);
    mesVencimento = proximo.month;
    anoVencimento = proximo.year;
  }

  final dia = clampDiaNoMes(anoVencimento, mesVencimento, diaVencimento);
  return DateTime(anoVencimento, mesVencimento, dia);
}
