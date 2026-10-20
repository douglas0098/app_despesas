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
      version: 1,
      onCreate: _createTables,
    );
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
        dia_vencimento INTEGER NOT NULL
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

  Future<int> removerLancamento(int id) async {
    final db = await database;
    return db.delete('lancamentos', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Lancamento>> listarLancamentosDoMes(String mesReferencia) async {
    final db = await database;
    final maps = await db.query(
      'lancamentos',
      where: "substr(data, 1, 7) = ?",
      whereArgs: [mesReferencia],
      orderBy: 'data DESC',
    );
    return maps.map((m) => Lancamento.fromMap(m)).toList();
  }

  /// Calcula o saldo do mês dividido por quinzena, replicando a lógica
  /// "Despesas dia 01" / "Despesas dia 15" da planilha original:
  /// - Quinzena 1 (vencimento <= dia 14): cartões + categorias/boletos
  ///   com vencimento até dia 14.
  /// - Quinzena 2 (vencimento >= dia 15): categorias/boletos com
  ///   vencimento a partir do dia 15.
  /// Receitas entram na quinzena conforme o dia de vencimento da própria
  /// categoria de receita (ex: Adiantamento dia 15 -> quinzena 1,
  /// Salário dia 30 -> quinzena 2).
  Future<SaldoMensal> calcularSaldoMensal(String mesReferencia) async {
    final categorias = await listarCategorias();
    final cartoes = await listarCartoes();
    final boletos = await listarBoletos(apenasAtivos: false);
    final lancamentos = await listarLancamentosDoMes(mesReferencia);

    final categoriaPorId = {for (var c in categorias) c.id: c};
    final cartaoPorId = {for (var c in cartoes) c.id: c};
    final boletoPorId = {for (var b in boletos) b.id: b};

    double receitaQ1 = 0, receitaQ2 = 0;
    double despesaQ1 = 0, despesaQ2 = 0;

    for (final l in lancamentos) {
      int quinzena = 2; // padrão, se não houver vínculo com vencimento

      if (l.cartaoId != null && cartaoPorId[l.cartaoId] != null) {
        quinzena = cartaoPorId[l.cartaoId]!.quinzena;
      } else if (l.boletoId != null && boletoPorId[l.boletoId] != null) {
        quinzena = boletoPorId[l.boletoId]!.quinzena;
      } else if (l.categoriaId != null && categoriaPorId[l.categoriaId] != null) {
        quinzena = categoriaPorId[l.categoriaId]!.quinzena;
      }

      if (l.tipo == TipoLancamento.receita) {
        if (quinzena == 1) {
          receitaQ1 += l.valor;
        } else {
          receitaQ2 += l.valor;
        }
      } else {
        if (quinzena == 1) {
          despesaQ1 += l.valor;
        } else {
          despesaQ2 += l.valor;
        }
      }
    }

    return SaldoMensal(
      saldoQuinzena1: receitaQ1 - despesaQ1,
      saldoQuinzena2: receitaQ2 - despesaQ2,
      receitaTotal: receitaQ1 + receitaQ2,
      despesaTotal: despesaQ1 + despesaQ2,
    );
  }
}

class SaldoMensal {
  final double saldoQuinzena1;
  final double saldoQuinzena2;
  final double receitaTotal;
  final double despesaTotal;

  SaldoMensal({
    required this.saldoQuinzena1,
    required this.saldoQuinzena2,
    required this.receitaTotal,
    required this.despesaTotal,
  });

  double get saldoTotal => receitaTotal - despesaTotal;
}
