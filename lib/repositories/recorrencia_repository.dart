import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class RecorrenciaRepository {
  final Database? banco;
  RecorrenciaRepository({this.banco});
  Future<Database> _db() async => banco ?? await DatabaseHelper.obterBanco();

  static String iso(DateTime d) => d.toIso8601String().substring(0, 10);

  static DateTime dataMensal(DateTime inicio, int deslocamento, int dia) {
    final mes = DateTime(inicio.year, inicio.month + deslocamento);
    final ultimo = DateTime(mes.year, mes.month + 1, 0).day;
    return DateTime(mes.year, mes.month, dia > ultimo ? ultimo : dia);
  }

  Future<int> cadastrar({
    required String tipo, required String descricao, required int valor,
    required int categoriaId, required DateTime inicio,
    int? quantidadeMeses, String? observacao,
  }) async {
    if (!['RECEITA', 'DESPESA'].contains(tipo) || descricao.trim().isEmpty ||
        valor <= 0 || inicio.year < 1 || inicio.year > 9999 ||
        (quantidadeMeses != null && (quantidadeMeses < 1 || quantidadeMeses > 600))) {
      throw ArgumentError('Dados da recorrência inválidos.');
    }
    final fim = quantidadeMeses == null ? null :
        dataMensal(inicio, quantidadeMeses - 1, inicio.day);
    if (fim != null && fim.year > 9999) throw ArgumentError('Período inválido.');
    final db = await _db();
    return db.transaction((txn) async {
      final categorias = await txn.query('categoria',
        where: 'id = ? AND tipo = ? AND status = ?',
        whereArgs: [categoriaId, tipo, 'ATIVA']);
      if (categorias.length != 1) throw ArgumentError('Categoria inválida.');
      final id = await txn.insert('recorrencia', {
        'tipo_lancamento': tipo, 'descricao': descricao.trim(), 'valor': valor,
        'categoria_id': categoriaId, 'periodicidade': 'MENSAL',
        'data_inicio': iso(inicio), 'data_fim': fim == null ? null : iso(fim),
        'dia_referencia': inicio.day, 'destino_geracao': 'LANCAMENTO',
        'status': 'ATIVA', 'observacao': observacao,
      });
      final regra = (await txn.query('recorrencia', where: 'id = ?', whereArgs: [id])).single;
      final hoje = DateTime.now();
      final horizonte = DateTime(hoje.year > inicio.year ? hoje.year : inicio.year, 12, 31);
      await _gerar(txn, regra, horizonte);
      return id;
    });
  }

  Future<int> gerarAte(DateTime horizonte) async {
    final db = await _db();
    return db.transaction((txn) async {
      final regras = await txn.query('recorrencia',
        where: "status = 'ATIVA' AND periodicidade = 'MENSAL' AND destino_geracao = 'LANCAMENTO'");
      var total = 0;
      for (final regra in regras) {
        total += await _gerar(txn, regra, horizonte);
      }
      return total;
    });
  }

  Future<int> _gerar(Transaction txn, Map<String, Object?> regra, DateTime horizonte) async {
    final inicio = DateTime.parse(regra['data_inicio'] as String);
    final fim = regra['data_fim'] == null ? horizonte : DateTime.parse(regra['data_fim'] as String);
    final limite = fim.isBefore(horizonte) ? fim : horizonte;
    final existentes = await txn.query('lancamento', columns: ['data_prevista'],
      where: 'recorrencia_id = ?', whereArgs: [regra['id']]);
    final meses = existentes.map((r) => (r['data_prevista'] as String).substring(0, 7)).toSet();
    var total = 0;
    for (var i = 0; ; i++) {
      final data = dataMensal(inicio, i, regra['dia_referencia'] as int? ?? inicio.day);
      if (data.isAfter(limite)) break;
      if (data.isBefore(inicio)) continue;
      final dia = iso(data);
      if (!meses.add(dia.substring(0, 7))) continue;
      // Recorrências são previsões; não inventamos pagamentos futuros.
      await txn.insert('lancamento', {
        'tipo': regra['tipo_lancamento'], 'descricao': regra['descricao'],
        'valor_previsto': regra['valor'], 'categoria_id': regra['categoria_id'],
        'data_prevista': dia, 'recorrencia_id': regra['id'],
        'origem': 'RECORRENCIA', 'status': 'PENDENTE', 'observacao': regra['observacao'],
      });
      total++;
    }
    return total;
  }
}
