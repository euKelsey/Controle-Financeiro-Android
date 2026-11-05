
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

}
