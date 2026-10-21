import '../models/lancamento.dart';
import 'date_utils.dart';

/// Divide [total] em [quantidade] parcelas, trabalhando em centavos para
/// não acumular erro de ponto flutuante. As parcelas são iguais e a última
/// absorve o resto da divisão, então a soma sempre bate com [total].
/// Mesma regra usada ao cadastrar uma compra parcelada.
List<double> dividirEmParcelas(double total, int quantidade) {
  final totalCentavos = (total * 100).round();
  final base = totalCentavos ~/ quantidade;
  final resto = totalCentavos - base * quantidade;
  return [
    for (var i = 0; i < quantidade; i++)
      (i == quantidade - 1 ? base + resto : base) / 100,
  ];
}

/// Muda só o dia de [dataPagamento], mantendo o mês e o ano dela. Se o dia
/// não existir naquele mês (ex: 31 em novembro), usa o último dia do mês.
DateTime comDiaDePagamento(DateTime dataPagamento, int dia) {
  return DateTime(
    dataPagamento.year,
    dataPagamento.month,
    clampDiaNoMes(dataPagamento.year, dataPagamento.month, dia),
  );
}

/// Calcula a nova data de pagamento de um lançamento quando a data da compra
/// é editada. O mês de pagamento acompanha o deslocamento de meses da compra
/// (compra em outubro paga em novembro, movida para dezembro, passa a ser
/// paga em janeiro); o dia é [dia].
///
/// Importante: o mês NÃO é recalculado a partir da data da compra, senão uma
/// compra no cartão paga no mês seguinte "pularia" para o mês da compra e
/// sumiria da lista e do painel do mês em que ela é paga.
DateTime pagamentoAposMudarData({
  required DateTime dataAnterior,
  required DateTime dataNova,
  required DateTime pagamentoAnterior,
  required int dia,
}) {
  final deslocamento = (dataNova.year * 12 + dataNova.month) -
      (dataAnterior.year * 12 + dataAnterior.month);
  final totalMeses =
      pagamentoAnterior.year * 12 + (pagamentoAnterior.month - 1) + deslocamento;
  final ano = totalMeses ~/ 12;
  final mes = totalMeses % 12 + 1;
  return DateTime(ano, mes, clampDiaNoMes(ano, mes, dia));
}

/// Aplica a todas as [parcelas] de uma compra as alterações informadas
/// (campos nulos ficam como estão):
///  - [novaDescricao]: nova descrição em todas;
///  - [novoValorTotal]: o total é redividido entre as parcelas (a última
///    absorve o resto de centavos);
///  - [novoDiaPagamento]: o dia muda em todas, cada uma mantendo o seu
///    próprio mês de pagamento.
///
/// Espera as parcelas na ordem (1, 2, 3...).
List<Lancamento> aplicarEdicaoNasParcelas(
  List<Lancamento> parcelas, {
  String? novaDescricao,
  double? novoValorTotal,
  int? novoDiaPagamento,
}) {
  final valores = novoValorTotal == null
      ? null
      : dividirEmParcelas(novoValorTotal, parcelas.length);

  return [
    for (var i = 0; i < parcelas.length; i++)
      parcelas[i].copyWith(
        descricao: novaDescricao,
        valor: valores?[i],
        dataPagamento: novoDiaPagamento == null
            ? null
            : comDiaDePagamento(parcelas[i].dataPagamento, novoDiaPagamento),
      ),
  ];
}

int _indiceMes(DateTime d) => d.year * 12 + d.month;

/// Quantos meses o pagamento de uma compra se desloca quando a data da compra
/// muda de [dataAnterior] para [dataNova] (negativo = vai para trás).
///
/// Se for compra no cartão ([diaFechamento] e [diaVencimento] informados),
/// compara o vencimento da fatura antes e depois, então comprar depois do
/// fechamento já joga a compra para a fatura seguinte. Sem cartão, é a
/// diferença de meses entre as duas datas.
int deslocamentoDePagamento({
  required DateTime dataAnterior,
  required DateTime dataNova,
  int? diaFechamento,
  int? diaVencimento,
}) {
  if (diaFechamento != null && diaVencimento != null) {
    final antes =
        calcularVencimentoFatura(dataAnterior, diaFechamento, diaVencimento);
    final depois =
        calcularVencimentoFatura(dataNova, diaFechamento, diaVencimento);
    return _indiceMes(depois) - _indiceMes(antes);
  }
  return _indiceMes(dataNova) - _indiceMes(dataAnterior);
}

/// Desloca [data] em [meses] (pode ser negativo), mantendo o dia e ajustando
/// para o último dia do mês quando ele não existe.
DateTime deslocarMeses(DateTime data, int meses) {
  final totalMeses = data.year * 12 + (data.month - 1) + meses;
  final ano = totalMeses ~/ 12;
  final mes = totalMeses % 12 + 1;
  return DateTime(ano, mes, clampDiaNoMes(ano, mes, data.day));
}

/// Muda a data da compra de uma compra parcelada: a parcela i passa a ter a
/// data da compra + i meses (como no cadastro) e todos os vencimentos se
/// deslocam [deslocamentoMeses] meses, mantendo o dia de cada um.
///
/// Espera as parcelas na ordem (1, 2, 3...).
List<Lancamento> mudarDataDaCompraParcelada(
  List<Lancamento> parcelas,
  DateTime novaDataCompra,
  int deslocamentoMeses,
) {
  return [
    for (var i = 0; i < parcelas.length; i++)
      parcelas[i].copyWith(
        data: addMonths(novaDataCompra, i),
        dataPagamento: deslocarMeses(parcelas[i].dataPagamento, deslocamentoMeses),
      ),
  ];
}

/// Data em que uma despesa é efetivamente paga (e portanto o mês e o painel
/// de saldo em que ela entra).
///
/// Compra no cartão ([diaFechamento] e [diaVencimento] informados): o mês é o
/// do vencimento da fatura, considerando o fechamento. Se [diaManual] foi
/// informado, só o dia muda, DENTRO do mês da fatura. Assim, pagar dia 10 um
/// cartão que vence dia 15 é um adiantamento da fatura, e não uma compra do mês
/// em que ela foi feita.
///
/// Sem cartão: a própria [dataCompra], com [diaManual] se informado.
DateTime dataDePagamentoDaDespesa({
  required DateTime dataCompra,
  int? diaFechamento,
  int? diaVencimento,
  int? diaManual,
}) {
  final DateTime base;
  if (diaFechamento != null && diaVencimento != null) {
    base = calcularVencimentoFatura(dataCompra, diaFechamento, diaVencimento);
  } else {
    base = dataCompra;
  }
  return diaManual == null ? base : comDiaDePagamento(base, diaManual);
}
