
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/fatura_model.dart';

class FaturaRepository {
  final Database? _bancoTeste;

  // Permite utilizar o banco principal ou um banco de testes.
  FaturaRepository({Database? banco}) : _bancoTeste = banco;

  Future<Database> _obterBanco() async {
    return _bancoTeste ?? await DatabaseHelper.obterBanco();
  }

  // Insere uma nova fatura no SQLite.
  Future<FaturaModel> inserir(FaturaModel fatura) async {
    final db = await _obterBanco();

    final id = await db.insert(
      'fatura',
      fatura.toMap(),
    );

    return FaturaModel(
      id: id,
      cartaoId: fatura.cartaoId,
      mesReferencia: fatura.mesReferencia,
      dataFechamento: fatura.dataFechamento,
      dataVencimento: fatura.dataVencimento,
      status: fatura.status,
    );
  }

  // Lista todas as faturas por competência.
  Future<List<FaturaModel>> listar() async {
    final db = await _obterBanco();

    final registros = await db.query(
      'fatura',
      orderBy: 'mes_referencia ASC, id ASC',
    );

    return registros
        .map((registro) => FaturaModel.fromMap(registro))
        .toList();
  }

  // Busca uma fatura pelo seu identificador.
  Future<FaturaModel?> buscarPorId(int id) async {
    final db = await _obterBanco();

    final registros = await db.query(
      'fatura',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return FaturaModel.fromMap(registros.first);
  }

  // Busca a fatura de um cartão em determinado mês.
  Future<FaturaModel?> buscarPorCartaoMes({
    required int cartaoId,
    required String mesReferencia,
  }) async {
    final db = await _obterBanco();

    final registros = await db.query(
      'fatura',
      where: 'cartao_id = ? AND mes_referencia = ?',
      whereArgs: [cartaoId, mesReferencia],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return FaturaModel.fromMap(registros.first);
  }

  
  // Calcula o total da fatura em centavos.
  // Considera somente compras com status ATIVA.
  Future<int> calcularTotalFatura(int faturaId) async {
    final db = await _obterBanco();

    final resultado = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(p.valor), 0) AS total
      FROM parcela_cartao AS p
      INNER JOIN compra_cartao AS c
        ON c.id = p.compra_cartao_id
      WHERE p.fatura_id = ?
        AND c.status = 'ATIVA'
      ''',
      [faturaId],
    );

    return resultado.first['total'] as int;
  }


  // Fecha automaticamente as faturas cujo prazo chegou
  // e gera os lançamentos financeiros pendentes.
  Future<({
    int faturasFechadas,
    int lancamentosGerados,
  })> processarFaturasAutomaticamente({
    required String dataReferencia,
  }) async {
    final formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    final data = DateTime.tryParse(dataReferencia);

    if (!formato.hasMatch(dataReferencia) ||
        data == null ||
        data.year.toString().padLeft(4, '0') !=
            dataReferencia.substring(0, 4) ||
        data.month.toString().padLeft(2, '0') !=
            dataReferencia.substring(5, 7) ||
        data.day.toString().padLeft(2, '0') !=
            dataReferencia.substring(8, 10)) {
      throw ArgumentError(
        'Informe uma data de referência válida '
        'no formato AAAA-MM-DD.',
      );
    }

    final db = await _obterBanco();

    return db.transaction((txn) async {
      // ETAPA 1: Fechar faturas cujo prazo chegou.
      final faturasFechadas = await txn.update(
        'fatura',
        {'status': 'FECHADA'},
        where: 'status = ? AND data_fechamento <= ?',
        whereArgs: ['ABERTA', dataReferencia],
      );

      // ETAPA 2: Localizar faturas fechadas
      // que ainda não possuem lançamento financeiro.
      final faturas = await txn.rawQuery('''
        SELECT
          f.id,
          f.mes_referencia,
          f.data_vencimento,
          COALESCE((
            SELECT SUM(p.valor)
            FROM parcela_cartao AS p
            INNER JOIN compra_cartao AS c
              ON c.id = p.compra_cartao_id
            WHERE p.fatura_id = f.id
              AND c.status = 'ATIVA'
          ), 0) AS total
        FROM fatura AS f
        WHERE f.status = 'FECHADA'
          AND NOT EXISTS (
            SELECT 1
            FROM lancamento AS l
            WHERE l.fatura_id = f.id
          )
      ''');

      var lancamentosGerados = 0;

      // ETAPA 3: Gerar um lançamento para cada
      // fatura com total maior que zero.
      for (final fatura in faturas) {
        final total = fatura['total'] as int;

        // Faturas zeradas não geram despesas.
        if (total <= 0) {
          continue;
        }

        final faturaId = fatura['id'] as int;
        final mesReferencia =
            fatura['mes_referencia'] as String;
        final dataVencimento =
            fatura['data_vencimento'] as String;

        await txn.insert(
          'lancamento',
          {
            'tipo': 'DESPESA',
            'descricao':
                'Fatura do cartão - $mesReferencia',
            'valor_previsto': total,
            'data_prevista': dataVencimento,
            'categoria_id': null,
            'fatura_id': faturaId,
            'status': 'PENDENTE',
            'origem': 'FATURA',
          },
        );

        lancamentosGerados++;
      }

      // ETAPA 4: Retornar o resultado do processamento.
      return (
        faturasFechadas: faturasFechadas,
        lancamentosGerados: lancamentosGerados,
      );
    });
  }


  // Confere se o valor do lançamento financeiro
  // corresponde ao total das compras ativas da fatura.
  Future<({
    int totalCompras,
    int? valorLancamento,
    bool consistente,
  })> conferirValorLancamento(int faturaId) async {
    final db = await _obterBanco();

    // ETAPA 1: Verificar se a fatura existe.
    final faturas = await db.query(
      'fatura',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [faturaId],
      limit: 1,
    );

    if (faturas.isEmpty) {
      throw ArgumentError(
        'Fatura não encontrada.',
      );
    }

    // ETAPA 2: Calcular o total das compras ativas.
    final resultado = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(p.valor), 0) AS total
      FROM parcela_cartao AS p
      INNER JOIN compra_cartao AS c
        ON c.id = p.compra_cartao_id
      WHERE p.fatura_id = ?
        AND c.status = 'ATIVA'
      ''',
      [faturaId],
    );

    final totalCompras = resultado.first['total'] as int;

    // ETAPA 3: Consultar o lançamento da fatura.
    final lancamentos = await db.query(
      'lancamento',
      columns: ['valor_previsto'],
      where: 'fatura_id = ?',
      whereArgs: [faturaId],
      limit: 1,
    );

    // Uma fatura sem compras e sem lançamento
    // não apresenta divergência de valores.
    if (lancamentos.isEmpty) {
      return (
        totalCompras: totalCompras,
        valorLancamento: null,
        consistente: totalCompras == 0,
      );
    }

    // ETAPA 4: Comparar os valores.
    final valorLancamento =
        lancamentos.first['valor_previsto'] as int;

    return (
      totalCompras: totalCompras,
      valorLancamento: valorLancamento,
      consistente: totalCompras > 0 &&
          totalCompras == valorLancamento,
    );
  }

}
