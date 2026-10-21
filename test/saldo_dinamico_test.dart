import 'package:flutter_test/flutter_test.dart';

import 'package:app_despesas/database/db_helper.dart';
import 'package:app_despesas/models/lancamento.dart';

Lancamento receita(String desc, double valor, int dia) => Lancamento(
      tipo: TipoLancamento.receita,
      descricao: desc,
      valor: valor,
      data: DateTime(2026, 10, dia),
    );

Lancamento despesa(String desc, double valor, int dia, {int? cartaoId}) =>
    Lancamento(
      tipo: TipoLancamento.despesa,
      descricao: desc,
      valor: valor,
      data: DateTime(2026, 10, dia),
      cartaoId: cartaoId,
    );

void main() {
  group('montarSaldoDinamico', () {
    test('primeira receita, sem nenhuma despesa, já aparece no saldo', () {
      final saldo = montarSaldoDinamico([receita('Salário', 3000, 5)]);

      expect(saldo.receitaTotal, 3000);
      expect(saldo.despesaTotal, 0);
      expect(saldo.saldoTotal, 3000);
      expect(saldo.periodos, hasLength(1));
      expect(saldo.periodos.first.titulo, 'Salário');
      expect(saldo.periodos.first.saldo, 3000);
      expect(saldo.periodos.first.despesasDetalhe, isEmpty);
    });

    test('receita com despesa no mesmo painel', () {
      final saldo = montarSaldoDinamico([
        receita('Salário', 3000, 5),
        despesa('Aluguel', 800, 10),
      ]);

      expect(saldo.saldoTotal, 2200);
      expect(saldo.periodos.single.saldo, 2200);
    });

    test('duas receitas, despesa só em uma: o outro painel fica sem despesa', () {
      final saldo = montarSaldoDinamico([
        receita('Salário', 3000, 5),
        receita('Adiantamento', 1000, 20),
        despesa('Luz', 150, 22),
      ]);

      expect(saldo.periodos, hasLength(2));
      expect(saldo.periodos[0].titulo, 'Salário');
      expect(saldo.periodos[0].saldo, 3000);
      expect(saldo.periodos[1].titulo, 'Adiantamento');
      expect(saldo.periodos[1].saldo, 850);
      expect(saldo.saldoTotal, 3850);
    });

    test('sem receita, só despesas: painel único', () {
      final saldo = montarSaldoDinamico([despesa('Luz', 150, 22)]);

      expect(saldo.periodos.single.titulo, 'Sem receita cadastrada neste mês');
      expect(saldo.saldoTotal, -150);
    });

    test('sem lançamentos: nenhum painel', () {
      final saldo = montarSaldoDinamico([]);

      expect(saldo.periodos, isEmpty);
      expect(saldo.saldoTotal, 0);
    });

    test('resumo por fonte soma o mesmo cartão e bate com a despesa do painel',
        () {
      final saldo = montarSaldoDinamico(
        [
          receita('Salário', 3000, 5),
          despesa('Mercado', 100, 10, cartaoId: 1),
          despesa('Farmácia', 50, 11, cartaoId: 1),
          despesa('Aluguel', 800, 12),
        ],
        cartoesPorId: {1: 'Nubank'},
      );

      final painel = saldo.periodos.single;
      final nubank = painel.resumoFontes.firstWhere((f) => f.nome == 'Nubank');
      expect(nubank.valor, 150);
      expect(painel.resumoFontes.fold<double>(0, (s, f) => s + f.valor),
          painel.despesa);
    });

    test('cenário completo: 3 receitas e 5 despesas em painéis diferentes', () {
      final saldo = montarSaldoDinamico([
        receita('Salário', 3000, 30),
        receita('Receita fixa', 500, 20),
        receita('Adiantamento', 1000, 15),
        despesa('Aluguel', 800, 10),
        despesa('Internet', 100, 17),
        despesa('Luz', 150, 25),
        despesa('Nubank', 400, 15),
        despesa('Academia', 90, 31),
      ]);

      expect(saldo.receitaTotal, 4500);
      expect(saldo.periodos.map((p) => p.subtitulo).toList(), [
        'Dia 15 até dia 19',
        'Dia 20 até dia 29',
        'Dia 30 até dia 14',
      ]);
      expect(saldo.periodos.map((p) => p.saldo).toList(), [500, 350, 2110]);
      expect(saldo.saldoTotal, 2960);
    });
  });
}
