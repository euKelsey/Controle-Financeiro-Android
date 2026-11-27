
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/compra_cartao_model.dart';

class CompraCartaoRepository {
  final Database? _bancoTeste;

  // Permite utilizar o banco principal ou um banco de testes.
  CompraCartaoRepository({Database? banco}) : _bancoTeste = banco;

  Future<Database> _obterBanco() async {
    return _bancoTeste ?? await DatabaseHelper.obterBanco();
  }

  // Insere uma compra na tabela compra_cartao.
  Future<CompraCartaoModel> inserir(
    CompraCartaoModel compra,
  ) async {
    final db = await _obterBanco();

    final id = await db.insert(
      'compra_cartao',
      compra.toMap(),
    );

    return CompraCartaoModel(
      id: id,
      cartaoId: compra.cartaoId,
      categoriaId: compra.categoriaId,
      recorrenciaId: compra.recorrenciaId,
      descricao: compra.descricao,
      dataCompra: compra.dataCompra,
      valorTotal: compra.valorTotal,
      quantidadeParcelas: compra.quantidadeParcelas,
      primeiraParcelaControlada:
          compra.primeiraParcelaControlada,
      dataPrimeiraParcelaControlada:
          compra.dataPrimeiraParcelaControlada,
      status: compra.status,
      observacao: compra.observacao,
    );
  }

  // Lista as compras por data, da mais recente para a mais antiga.
  Future<List<CompraCartaoModel>> listar() async {
    final db = await _obterBanco();

    final registros = await db.query(
      'compra_cartao',
      orderBy: 'data_compra DESC, id DESC',
    );

    return registros
        .map((registro) => CompraCartaoModel.fromMap(registro))
        .toList();
  }

  // Busca uma compra pelo seu identificador.
  Future<CompraCartaoModel?> buscarPorId(int id) async {
    final db = await _obterBanco();

    final registros = await db.query(
      'compra_cartao',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (registros.isEmpty) {
      return null;
    }

    return CompraCartaoModel.fromMap(registros.first);
  }

  
  // Registra uma compra em 1x e associa à fatura
  // dentro de uma única transação SQLite.
  Future<CompraCartaoModel> inserirCompraComParcela({
    required CompraCartaoModel compra,
    required String mesReferencia,
    required String dataFechamento,
    required String dataVencimento,
  }) async {
    final db = await _obterBanco();

    // Data atual no formato AAAA-MM-DD.
    final hoje = DateTime.now()
        .toIso8601String()
        .substring(0, 10);

    return db.transaction((txn) async {
      // ETAPA 1: Procurar a fatura correspondente.
      final faturas = await txn.query(
        'fatura',
        columns: ['id', 'status', 'data_fechamento'],
        where: 'cartao_id = ? AND mes_referencia = ?',
        whereArgs: [compra.cartaoId, mesReferencia],
        limit: 1,
      );

      late final int faturaId;

      if (faturas.isNotEmpty) {
        // ETAPA 2A: A fatura já existe.
        final fatura = faturas.first;

        if (fatura['status'] != 'ABERTA') {
          throw StateError(
            'Esta compra pertence a uma fatura já fechada.',
          );
        }

        final fechamento = fatura['data_fechamento'] as String;

        if (fechamento.compareTo(hoje) <= 0) {
          throw StateError(
            'Não é possível adicionar compras a uma '
            'fatura cuja data de fechamento já chegou.',
          );
        }

        faturaId = fatura['id'] as int;
      } else {
        // ETAPA 2B: A fatura ainda não existe.
        if (dataFechamento.compareTo(hoje) <= 0) {
          throw StateError(
            'Não é possível criar uma fatura aberta '
            'com data de fechamento já atingida.',
          );
        }

        faturaId = await txn.insert(
          'fatura',
          {
            'cartao_id': compra.cartaoId,
            'mes_referencia': mesReferencia,
            'data_fechamento': dataFechamento,
            'data_vencimento': dataVencimento,
            'status': 'ABERTA',
          },
        );
      }

      // ETAPA 3: Registrar a compra.
      final compraId = await txn.insert(
        'compra_cartao',
        compra.toMap(),
      );

      // ETAPA 4: Associar a compra à fatura.
      await txn.insert(
        'parcela_cartao',
        {
          'compra_cartao_id': compraId,
          'fatura_id': faturaId,
          'numero_parcela': 1,
          'valor': compra.valorTotal,
          'data_prevista': dataVencimento,
        },
      );

      // ETAPA 5: Retornar a compra cadastrada.
      return CompraCartaoModel(
        id: compraId,
        cartaoId: compra.cartaoId,
        categoriaId: compra.categoriaId,
        recorrenciaId: compra.recorrenciaId,
        descricao: compra.descricao,
        dataCompra: compra.dataCompra,
        valorTotal: compra.valorTotal,
        quantidadeParcelas: compra.quantidadeParcelas,
        primeiraParcelaControlada:
            compra.primeiraParcelaControlada,
        dataPrimeiraParcelaControlada:
            compra.dataPrimeiraParcelaControlada,
        status: compra.status,
        observacao: compra.observacao,
      );
    });
  }


  // A edição/cancelamento só pode ocorrer antes do fechamento real.
  Future<Map<String, Object?>> _parcelaEditavel(
    DatabaseExecutor txn, int compraId,
  ) async {
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    final linhas = await txn.rawQuery('''
      SELECT p.id AS parcela_id, f.id AS fatura_id, f.mes_referencia,
             f.data_vencimento, f.data_fechamento, f.status AS fatura_status,
             c.status AS compra_status, c.quantidade_parcelas, c.cartao_id,
             c.data_compra, c.categoria_id, c.recorrencia_id
      FROM compra_cartao c
      JOIN parcela_cartao p ON p.compra_cartao_id = c.id
      JOIN fatura f ON f.id = p.fatura_id
      WHERE c.id = ?
    ''', [compraId]);
    if (linhas.length != 1) throw StateError('Compra sem parcela única vinculada.');
    final linha = linhas.single;
    if (linha['compra_status'] != 'ATIVA' ||
        linha['quantidade_parcelas'] != 1 ||
        linha['recorrencia_id'] != null ||
        linha['fatura_status'] != 'ABERTA' ||
        (linha['data_fechamento'] as String).compareTo(hoje) <= 0) {
      throw StateError('Somente compras avulsas ativas de faturas abertas podem ser alteradas.');
    }
    final lancamentos = await txn.query('lancamento',
      where: 'fatura_id = ?', whereArgs: [linha['fatura_id']], limit: 1);
    if (lancamentos.isNotEmpty) throw StateError('Fatura já possui lançamento financeiro.');
    return linha;
  }

  Future<bool> podeAlterar(int compraId) async {
    final db = await _obterBanco();
    try {
      return await db.transaction((txn) async {
        await _parcelaEditavel(txn, compraId);
        return true;
      });
    } on StateError {
      return false;
    }
  }

  Future<void> atualizarCompraComParcela({
    required int compraId,
    required int categoriaId,
    required String descricao,
    required String dataCompra,
    required int valorTotal,
    required String mesReferencia,
    required String dataFechamento,
    required String dataVencimento,
    String? observacao,
  }) async {
    final db = await _obterBanco();
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    await db.transaction((txn) async {
      final origem = await _parcelaEditavel(txn, compraId);
      final categorias = await txn.query('categoria',
        where: 'id = ? AND tipo = ?', whereArgs: [categoriaId, 'DESPESA']);
      if (categorias.length != 1 ||
          (categorias.single['status'] != 'ATIVA' && categoriaId != origem['categoria_id'])) {
        throw StateError('Categoria indisponível.');
      }
      var faturaId = origem['fatura_id'] as int;
      var vencimento = origem['data_vencimento'] as String;
      // Preserva a fatura histórica se a data não foi modificada.
      if (dataCompra != origem['data_compra'] &&
          mesReferencia != origem['mes_referencia']) {
        final destino = await txn.query('fatura',
          where: 'cartao_id = ? AND mes_referencia = ?',
          whereArgs: [origem['cartao_id'], mesReferencia], limit: 1);
        if (destino.isEmpty) {
          if (dataFechamento.compareTo(hoje) <= 0) {
            throw StateError('O fechamento da fatura de destino já chegou.');
          }
          faturaId = await txn.insert('fatura', {
            'cartao_id': origem['cartao_id'], 'mes_referencia': mesReferencia,
            'data_fechamento': dataFechamento, 'data_vencimento': dataVencimento,
            'status': 'ABERTA',
          });
          vencimento = dataVencimento;
        } else {
          final f = destino.single;
          if (f['status'] != 'ABERTA' ||
              (f['data_fechamento'] as String).compareTo(hoje) <= 0) {
            throw StateError('A fatura de destino não está disponível para alterações.');
          }
          faturaId = f['id'] as int;
          vencimento = f['data_vencimento'] as String;
          if ((await txn.query('lancamento', where: 'fatura_id = ?',
              whereArgs: [faturaId], limit: 1)).isNotEmpty) {
            throw StateError('A fatura de destino já possui lançamento financeiro.');
          }
        }
      }
      await txn.update('compra_cartao', {
        'categoria_id': categoriaId, 'descricao': descricao,
        'data_compra': dataCompra, 'valor_total': valorTotal,
        'observacao': observacao,
      }, where: 'id = ?', whereArgs: [compraId]);
      await txn.update('parcela_cartao', {
        'fatura_id': faturaId, 'valor': valorTotal, 'data_prevista': vencimento,
      }, where: 'id = ?', whereArgs: [origem['parcela_id']]);
    });
  }

  Future<void> cancelarCompra(int compraId) async {
    final db = await _obterBanco();
    await db.transaction((txn) async {
      await _parcelaEditavel(txn, compraId);
      await txn.update('compra_cartao', {'status': 'CANCELADA'},
        where: 'id = ?', whereArgs: [compraId]);
    });
  }

}
