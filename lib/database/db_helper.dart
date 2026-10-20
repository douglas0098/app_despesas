import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/categoria.dart';
import '../models/cartao.dart';
import '../models/boleto.dart';
import '../models/lancamento.dart';

class DBHelper {
  DBHelper._internal();
  static final DBHelper instance = DBHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_despesas.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: _createTables,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Adiciona suporte a parcelamento de cartão e recorrência
      // em bancos criados antes dessa funcionalidade existir.
      await db.execute('ALTER TABLE lancamentos ADD COLUMN grupo_id INTEGER');
      await db.execute('ALTER TABLE lancamentos ADD COLUMN parcela_info TEXT');
    }
    if (oldVersion < 3) {
      // Adiciona data de pagamento (usada nos painéis de saldo dinâmico)
      // e o dia de fechamento da fatura do cartão.
      await db.execute(
          'ALTER TABLE lancamentos ADD COLUMN data_pagamento TEXT');
      await db.execute('UPDATE lancamentos SET data_pagamento = data '
          'WHERE data_pagamento IS NULL');
      await db.execute(
          'ALTER TABLE cartoes ADD COLUMN dia_fechamento INTEGER');
      // Cartões já cadastrados recebem fechamento = vencimento como
      // padrão seguro (nunca "vira o mês" até o usuário ajustar).
      await db.execute('UPDATE cartoes SET dia_fechamento = dia_vencimento '
          'WHERE dia_fechamento IS NULL');
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        tipo TEXT NOT NULL,
        dia_vencimento INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE cartoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        dia_vencimento INTEGER NOT NULL,
        dia_fechamento INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE boletos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        dia_vencimento INTEGER NOT NULL,
        valor_padrao REAL,
        ativo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE lancamentos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        categoria_id INTEGER,
        cartao_id INTEGER,
        boleto_id INTEGER,
        descricao TEXT NOT NULL,
        valor REAL NOT NULL,
        data TEXT NOT NULL,
        data_pagamento TEXT NOT NULL,
        grupo_id INTEGER,
        parcela_info TEXT,
        FOREIGN KEY (categoria_id) REFERENCES categorias (id),
        FOREIGN KEY (cartao_id) REFERENCES cartoes (id),
        FOREIGN KEY (boleto_id) REFERENCES boletos (id)
      )
    ''');
  }

  // ---------------- Categorias ----------------

  Future<int> inserirCategoria(Categoria c) async {
    final db = await database;
    return db.insert('categorias', c.toMap()..remove('id'));
  }

  Future<List<Categoria>> listarCategorias({TipoCategoria? tipo}) async {
    final db = await database;
    final maps = tipo == null
        ? await db.query('categorias', orderBy: 'nome')
        : await db.query('categorias',
            where: 'tipo = ?', whereArgs: [tipo.name], orderBy: 'nome');
    return maps.map((m) => Categoria.fromMap(m)).toList();
  }

  // ---------------- Cartões ----------------

  Future<int> inserirCartao(Cartao c) async {
    final db = await database;
    return db.insert('cartoes', c.toMap()..remove('id'));
  }

  Future<List<Cartao>> listarCartoes() async {
    final db = await database;
    final maps = await db.query('cartoes', orderBy: 'nome');
    return maps.map((m) => Cartao.fromMap(m)).toList();
  }

  Future<int> atualizarCartao(Cartao c) async {
    final db = await database;
    return db.update(
      'cartoes',
      c.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> removerCartao(int id) async {
    final db = await database;
    return db.delete('cartoes', where: 'id = ?', whereArgs: [id]);
  }

  /// Quantos lançamentos estão vinculados a esse cartão — usado para
  /// avisar o usuário antes de excluir.
  Future<int> contarLancamentosDoCartao(int cartaoId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM lancamentos WHERE cartao_id = ?',
      [cartaoId],
    );
    return result.first['total'] as int;
  }

  /// Compras vinculadas a um cartão, agrupadas: parcelas do mesmo grupo
  /// viram uma única "compra" com o valor total somado e a contagem de
  /// parcelas. Compras não parceladas aparecem avulsas.
  Future<List<CompraCartao>> listarComprasDoCartao(int cartaoId) async {
    final db = await database;
    final maps = await db.query(
      'lancamentos',
      where: 'cartao_id = ? AND tipo = ?',
      whereArgs: [cartaoId, TipoLancamento.despesa.name],
    );
    final lancamentos = maps.map((m) => Lancamento.fromMap(m)).toList();

    final Map<int, List<Lancamento>> porGrupo = {};
    final List<Lancamento> avulsos = [];
    for (final l in lancamentos) {
      if (l.grupoId != null) {
        porGrupo.putIfAbsent(l.grupoId!, () => []).add(l);
      } else {
        avulsos.add(l);
      }
    }

    final compras = <CompraCartao>[];
    porGrupo.forEach((grupoId, itens) {
      final total = itens.fold(0.0, (s, i) => s + i.valor);
      final dataMaisAntiga =
          itens.map((i) => i.data).reduce((a, b) => a.isBefore(b) ? a : b);
      compras.add(CompraCartao(
        descricao: itens.first.descricao,
        valorTotal: total,
        numParcelas: itens.length,
        dataReferencia: dataMaisAntiga,
      ));
    });
    for (final a in avulsos) {
      compras.add(CompraCartao(
        descricao: a.descricao,
        valorTotal: a.valor,
        numParcelas: 1,
        dataReferencia: a.data,
      ));
    }

    compras.sort((a, b) => b.dataReferencia.compareTo(a.dataReferencia));
    return compras;
  }

  /// Todas as compras vinculadas a um cartão (qualquer mês), da mais
  /// recente para a mais antiga — usado para exibir o extrato do cartão.
  Future<List<Lancamento>> listarLancamentosDoCartao(int cartaoId) async {
    final db = await database;
    final maps = await db.query(
      'lancamentos',
      where: 'cartao_id = ?',
      whereArgs: [cartaoId],
      orderBy: 'data DESC',
    );
    return maps.map((m) => Lancamento.fromMap(m)).toList();
  }

  // ---------------- Boletos ----------------

  Future<int> inserirBoleto(Boleto b) async {
    final db = await database;
    return db.insert('boletos', b.toMap()..remove('id'));
  }

  Future<List<Boleto>> listarBoletos({bool apenasAtivos = true}) async {
    final db = await database;
    final maps = apenasAtivos
        ? await db.query('boletos', where: 'ativo = 1', orderBy: 'dia_vencimento')
        : await db.query('boletos', orderBy: 'dia_vencimento');
    return maps.map((m) => Boleto.fromMap(m)).toList();
  }

  // ---------------- Lançamentos ----------------

  Future<int> inserirLancamento(Lancamento l) async {
    final db = await database;
    return db.insert('lancamentos', l.toMap()..remove('id'));
  }

  /// Insere vários lançamentos de uma vez (parcelas de cartão ou
  /// ocorrências de uma recorrência), numa única transação.
  Future<void> inserirLancamentosEmLote(List<Lancamento> lista) async {
    final db = await database;
    final batch = db.batch();
    for (final l in lista) {
      batch.insert('lancamentos', l.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<int> atualizarLancamento(Lancamento l) async {
    final db = await database;
    return db.update(
      'lancamentos',
      l.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [l.id],
    );
  }

  Future<int> removerLancamento(int id) async {
    final db = await database;
    return db.delete('lancamentos', where: 'id = ?', whereArgs: [id]);
  }

  /// Remove todos os lançamentos futuros (a partir de [aPartirDe],
  /// inclusive) de um mesmo grupo — útil para cancelar as parcelas ou
  /// ocorrências de recorrência ainda não vencidas.
  Future<int> removerLancamentosDoGrupoAPartirDe(
      int grupoId, DateTime aPartirDe) async {
    final db = await database;
    return db.delete(
      'lancamentos',
      where: 'grupo_id = ? AND data >= ?',
      whereArgs: [grupoId, aPartirDe.toIso8601String()],
    );
  }

  /// Remove TODOS os lançamentos de um grupo (todas as parcelas de uma
  /// compra parcelada, ou todas as ocorrências de uma recorrência),
  /// passadas e futuras.
  Future<int> removerGrupoCompleto(int grupoId) async {
    final db = await database;
    return db.delete(
      'lancamentos',
      where: 'grupo_id = ?',
      whereArgs: [grupoId],
    );
  }

  /// Quantos lançamentos existem num grupo — usado para avisar o usuário
  /// antes de excluir tudo de uma vez.
  Future<int> contarLancamentosDoGrupo(int grupoId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM lancamentos WHERE grupo_id = ?',
      [grupoId],
    );
    return result.first['total'] as int;
  }

  /// Próximo grupo_id disponível, usado para vincular parcelas/recorrências
  /// recém-criadas antes de terem um id de lançamento próprio.
  Future<int> proximoGrupoId() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COALESCE(MAX(grupo_id), 0) + 1 AS proximo FROM lancamentos');
    return result.first['proximo'] as int;
  }

  /// Lançamentos cujo mês de pagamento (não o mês da compra em si) é
  /// [mesReferencia]. É isso que faz uma compra parcelada feita depois do
  /// fechamento do cartão "cair" no mês seguinte no app.
  Future<List<Lancamento>> listarLancamentosDoMes(String mesReferencia) async {
    final db = await database;
    final maps = await db.query(
      'lancamentos',
      where: "substr(data_pagamento, 1, 7) = ?",
      whereArgs: [mesReferencia],
      orderBy: 'data_pagamento DESC',
    );
    return maps.map((m) => Lancamento.fromMap(m)).toList();
  }

  /// Calcula o saldo do mês em painéis dinâmicos: um painel para cada
  /// receita cadastrada naquele mês, cobrindo do dia dessa receita até o
  /// dia anterior à próxima. Cada despesa é descontada do painel cujo
  /// intervalo de dias contém o dia da sua data de pagamento.
  Future<SaldoDinamico> calcularSaldoDinamico(String mesReferencia) async {
    final lancamentos = await listarLancamentosDoMes(mesReferencia);

    final receitas = lancamentos.where((l) => l.tipo == TipoLancamento.receita).toList();
    final despesas = lancamentos.where((l) => l.tipo == TipoLancamento.despesa).toList();

    final despesaTotal = despesas.fold(0.0, (s, l) => s + l.valor);
    final receitaTotal = receitas.fold(0.0, (s, l) => s + l.valor);

    // Mapas de apoio para transformar cartao_id/boleto_id/categoria_id em
    // um nome de exibição, usados para agrupar as despesas por fonte
    // (cada cartão separado, despesas fixas somadas, etc.) no resumo
    // da tela inicial.
    final cartoes = await listarCartoes();
    final boletos = await listarBoletos(apenasAtivos: false);
    final categorias = await listarCategorias();
    final cartoesPorId = {for (final c in cartoes) c.id: c.nome};
    final boletosPorId = {for (final b in boletos) b.id: b.nome};
    final categoriasPorId = {for (final c in categorias) c.id: c};

    if (receitas.isEmpty) {
      return SaldoDinamico(
        periodos: despesaTotal == 0
            ? []
            : [
                PeriodoSaldo(
                  titulo: 'Sem receita cadastrada neste mês',
                  receita: 0,
                  despesa: despesaTotal,
                  despesasDetalhe: despesas,
                ).comResumoFontes(cartoesPorId, boletosPorId, categoriasPorId)
              ],
        receitaTotal: 0,
        despesaTotal: despesaTotal,
      );
    }

    // Agrupa receitas por dia (duas receitas no mesmo dia viram um painel só).
    final Map<int, double> receitaPorDia = {};
    final Map<int, List<String>> descricoesPorDia = {};
    for (final r in receitas) {
      final dia = r.dataPagamento.day;
      receitaPorDia[dia] = (receitaPorDia[dia] ?? 0) + r.valor;
      descricoesPorDia.putIfAbsent(dia, () => []).add(r.descricao);
    }

    final dias = receitaPorDia.keys.toList()..sort();

    // Constrói os intervalos [inicio, fim] de cada painel, com o último
    // "dando a volta" no mês (cobre até o fim do mês e o começo, antes
    // da primeira receita).
    final periodos = <PeriodoSaldo>[];
    for (var i = 0; i < dias.length; i++) {
      final inicio = dias[i];
      final fim = i + 1 < dias.length ? dias[i + 1] - 1 : dias[0] - 1;
      periodos.add(PeriodoSaldo(
        titulo: descricoesPorDia[inicio]!.toSet().join(' + '),
        diaInicio: inicio,
        diaFim: fim,
        receita: receitaPorDia[inicio]!,
        despesa: 0,
      ));
    }

    bool diaNoPeriodo(int dia, int inicio, int fim) {
      if (fim >= inicio) {
        return dia >= inicio && dia <= fim;
      }
      // período dá a volta no mês (ex: início dia 30, fim dia 14)
      return dia >= inicio || dia <= fim;
    }

    for (final d in despesas) {
      final diaPagamento = d.dataPagamento.day;
      final indice = periodos.indexWhere(
          (p) => diaNoPeriodo(diaPagamento, p.diaInicio!, p.diaFim!));
      final alvo = indice == -1 ? periodos.length - 1 : indice;
      periodos[alvo] = periodos[alvo].copyWith(
        despesa: periodos[alvo].despesa + d.valor,
        despesasDetalhe: [...periodos[alvo].despesasDetalhe, d],
      );
    }

    for (final p in periodos) {
      p.despesasDetalhe.sort(
          (a, b) => a.descricao.toLowerCase().compareTo(b.descricao.toLowerCase()));
    }

    final periodosComResumo = periodos
        .map((p) => p.comResumoFontes(cartoesPorId, boletosPorId, categoriasPorId))
        .toList();

    return SaldoDinamico(
      periodos: periodosComResumo,
      receitaTotal: receitaTotal,
      despesaTotal: despesaTotal,
    );
  }
}

class CompraCartao {
  final String descricao;
  final double valorTotal;
  final int numParcelas;
  final DateTime dataReferencia;

  CompraCartao({
    required this.descricao,
    required this.valorTotal,
    required this.numParcelas,
    required this.dataReferencia,
  });
}

class PeriodoSaldo {
  final String titulo;
  final int? diaInicio;
  final int? diaFim;
  final double receita;
  final double despesa;

  /// Cada despesa que compõe o total desse painel (usada internamente
  /// para calcular o [resumoFontes]).
  final List<Lancamento> despesasDetalhe;

  /// Despesas desse painel agrupadas por fonte (cada cartão separado,
  /// cada boleto separado, "Despesas fixas" e "Outras despesas" somadas),
  /// para o dropdown de resumo na tela inicial.
  final List<ResumoFonte> resumoFontes;

  PeriodoSaldo({
    required this.titulo,
    this.diaInicio,
    this.diaFim,
    required this.receita,
    required this.despesa,
    List<Lancamento>? despesasDetalhe,
    List<ResumoFonte>? resumoFontes,
  })  : despesasDetalhe = despesasDetalhe ?? const [],
        resumoFontes = resumoFontes ?? const [];

  double get saldo => receita - despesa;

  String get subtitulo {
    if (diaInicio == null || diaFim == null) return '';
    return 'Dia $diaInicio até dia $diaFim';
  }

  PeriodoSaldo copyWith({
    double? receita,
    double? despesa,
    List<Lancamento>? despesasDetalhe,
    List<ResumoFonte>? resumoFontes,
  }) {
    return PeriodoSaldo(
      titulo: titulo,
      diaInicio: diaInicio,
      diaFim: diaFim,
      receita: receita ?? this.receita,
      despesa: despesa ?? this.despesa,
      despesasDetalhe: despesasDetalhe ?? this.despesasDetalhe,
      resumoFontes: resumoFontes ?? this.resumoFontes,
    );
  }

  /// Nome de exibição da fonte de uma despesa: nome do cartão, nome do
  /// boleto, ou o rótulo do tipo de categoria (despesas fixas e outras
  /// despesas são somadas num único total cada).
  static String _nomeFonte(
    Lancamento l,
    Map<int?, String> cartoesPorId,
    Map<int?, String> boletosPorId,
    Map<int?, Categoria> categoriasPorId,
  ) {
    if (l.cartaoId != null) {
      return cartoesPorId[l.cartaoId] ?? 'Cartão';
    }
    if (l.boletoId != null) {
      return boletosPorId[l.boletoId] ?? 'Boleto';
    }
    final categoria = categoriasPorId[l.categoriaId];
    if (categoria != null) {
      switch (categoria.tipo) {
        case TipoCategoria.despesaFixa:
          return 'Despesas fixas';
        case TipoCategoria.outras:
          return 'Outras despesas';
        case TipoCategoria.receita:
          return categoria.nome;
      }
    }
    return 'Outros';
  }

  /// Retorna uma cópia deste painel com [resumoFontes] calculado a partir
  /// de [despesasDetalhe], somando os valores por fonte.
  PeriodoSaldo comResumoFontes(
    Map<int?, String> cartoesPorId,
    Map<int?, String> boletosPorId,
    Map<int?, Categoria> categoriasPorId,
  ) {
    final Map<String, double> totalPorFonte = {};
    for (final l in despesasDetalhe) {
      final nome = _nomeFonte(l, cartoesPorId, boletosPorId, categoriasPorId);
      totalPorFonte[nome] = (totalPorFonte[nome] ?? 0) + l.valor;
    }
    final resumo = totalPorFonte.entries
        .map((e) => ResumoFonte(nome: e.key, valor: e.value))
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
    return copyWith(resumoFontes: resumo);
  }
}

/// Total de despesas de um painel de saldo agrupado por fonte: nome de um
/// cartão, de um boleto, ou "Despesas fixas" / "Outras despesas".
class ResumoFonte {
  final String nome;
  final double valor;

  ResumoFonte({required this.nome, required this.valor});
}

class SaldoDinamico {
  final List<PeriodoSaldo> periodos;
  final double receitaTotal;
  final double despesaTotal;

  SaldoDinamico({
    required this.periodos,
    required this.receitaTotal,
    required this.despesaTotal,
  });

  double get saldoTotal => receitaTotal - despesaTotal;
}
