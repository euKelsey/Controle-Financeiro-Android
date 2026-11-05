
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/cartao_repository.dart';
import 'package:controle_financeiro_android/repositories/categoria_repository.dart';
import 'package:controle_financeiro_android/repositories/compra_cartao_repository.dart';
import 'package:controle_financeiro_android/services/compra_cartao_service.dart';
import 'package:controle_financeiro_android/services/competencia_fatura_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Valida cadastro de compras no CompraCartaoService',
      (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_compra_cartao_service.db',
    );

    await deleteDatabase(caminho);

    final schema = await rootBundle.loadString(
      'assets/sql/schema.sql',
    );

    final db = await openDatabase(
      caminho,
      version: 1,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        for (final comando in schema.split(';')) {
          final sql = comando.trim();

          if (sql.isNotEmpty) {
            await database.execute(sql);
          }
        }
      },
    );

    try {
      final compraRepository = CompraCartaoRepository(
        banco: db,
      );

      final cartaoRepository = CartaoRepository(
        banco: db,
      );

      final categoriaRepository = CategoriaRepository(
        banco: db,
      );

      final service = CompraCartaoService(
        compraRepository,
        cartaoRepository: cartaoRepository,
        categoriaRepository: categoriaRepository,
      );

      // Datas futuras para evitar fechamento já ocorrido.
      String dataIso(DateTime data) {
        final ano = data.year.toString().padLeft(4, '0');
        final mes = data.month.toString().padLeft(2, '0');
        final dia = data.day.toString().padLeft(2, '0');

        return '$ano-$mes-$dia';
      }

      final hoje = DateTime.now();

      final dataCompra = dataIso(
        DateTime(hoje.year, hoje.month + 2, 5),
      );

      // TESTE 1: Criar cartão ativo.
      final cartaoId = await db.insert(
        'cartao',
        {
          'nome': 'Nubank Principal',
          'instituicao': 'Nubank',
          'limite_total': 500000,
          'dia_fechamento': 20,
          'dia_vencimento': 28,
          'status': 'ATIVO',
        },
      );

      // TESTE 2: Criar categoria de despesa.
      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Alimentacao',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // TESTE 3: Criar categoria de receita.
      final categoriaReceitaId = await db.insert(
        'categoria',
        {
          'nome': 'Salario',
          'tipo': 'RECEITA',
          'status': 'ATIVA',
        },
      );

      // TESTE 4: Cadastrar compra válida.
      final compra = await service.cadastrarCompra(
        cartaoId: cartaoId,
        categoriaId: categoriaId,
        descricao: '  Supermercado  ',
        dataCompra: dataCompra,
        valorTotal: 25990,
        observacao: 'Compra mensal',
      );

      expect(compra.id, isNotNull);
      expect(compra.descricao, 'Supermercado');
      expect(compra.valorTotal, 25990);
      expect(compra.quantidadeParcelas, 1);
      expect(compra.status, 'ATIVA');
      expect(compra.observacao, 'Compra mensal');

      // TESTE 5: Conferir a fatura criada.
      final faturas = await db.query('fatura');

      expect(faturas.length, 1);

      final fatura = faturas.first;

      final mesEsperado =
          CompetenciaFaturaService.calcularMesFatura(
        dataCompra: dataCompra,
        diaFechamento: 20,
      );

      final datasEsperadas =
          CompetenciaFaturaService.calcularDatasFatura(
        mesReferencia: mesEsperado,
        diaFechamento: 20,
        diaVencimento: 28,
      );

      expect(fatura['cartao_id'], cartaoId);
      expect(fatura['mes_referencia'], mesEsperado);
      expect(fatura['status'], 'ABERTA');
      expect(
        fatura['data_fechamento'],
        datasEsperadas.dataFechamento,
      );
      expect(
        fatura['data_vencimento'],
        datasEsperadas.dataVencimento,
      );

      // TESTE 6: Conferir parcela única.
      final parcelas = await db.query('parcela_cartao');

      expect(parcelas.length, 1);
      expect(parcelas.first['compra_cartao_id'], compra.id);
      expect(parcelas.first['fatura_id'], fatura['id']);
      expect(parcelas.first['numero_parcela'], 1);
      expect(parcelas.first['valor'], 25990);
      expect(
        parcelas.first['data_prevista'],
        datasEsperadas.dataVencimento,
      );

      // TESTE 7: Consultar a compra por ID.
      final encontrada = await service.buscarCompraPorId(
        compra.id!,
      );

      expect(encontrada.id, compra.id);
      expect(encontrada.cartaoId, cartaoId);
      expect(encontrada.categoriaId, categoriaId);
      expect(encontrada.valorTotal, 25990);

      // TESTE 8: Listar compras cadastradas.
      final compras = await service.listarCompras();

      expect(compras.length, 1);
      expect(compras.first.id, compra.id);

      // Função auxiliar para testar cadastros inválidos.
      Future<void> verificarBloqueio({
        int? cartao,
        int? categoria,
        String descricao = 'Compra de teste',
        int valor = 10000,
        String? data,
      }) async {
        await expectLater(
          service.cadastrarCompra(
            cartaoId: cartao ?? cartaoId,
            categoriaId: categoria ?? categoriaId,
            descricao: descricao,
            dataCompra: data ?? dataCompra,
            valorTotal: valor,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }

      // TESTE 9: Cartão inexistente.
      await verificarBloqueio(cartao: 999999);

      // TESTE 10: Cartão inativo.
      await db.update(
        'cartao',
        {'status': 'INATIVO'},
        where: 'id = ?',
        whereArgs: [cartaoId],
      );

      await verificarBloqueio();

      // Reativar para os próximos testes.
      await db.update(
        'cartao',
        {'status': 'ATIVO'},
        where: 'id = ?',
        whereArgs: [cartaoId],
      );

      // TESTE 11: Categoria inexistente.
      await verificarBloqueio(categoria: 999999);

      // TESTE 12: Categoria inativa.
      await db.update(
        'categoria',
        {'status': 'INATIVA'},
        where: 'id = ?',
        whereArgs: [categoriaId],
      );

      await verificarBloqueio();

      // Reativar para os próximos testes.
      await db.update(
        'categoria',
        {'status': 'ATIVA'},
        where: 'id = ?',
        whereArgs: [categoriaId],
      );

      // TESTE 13: Categoria de receita.
      await verificarBloqueio(
        categoria: categoriaReceitaId,
      );

      // TESTE 14: Descrição vazia.
      await verificarBloqueio(descricao: '   ');

      // TESTE 15: Valor zero.
      await verificarBloqueio(valor: 0);

      // TESTE 16: Valor negativo.
      await verificarBloqueio(valor: -500);

      // TESTE 17: Data em formato inválido.
      await verificarBloqueio(data: '05/11/2026');

      // TESTE 18: Data inexistente.
      await verificarBloqueio(data: '2026-02-30');

      // TESTE 19: Compra inexistente.
      await expectLater(
        service.buscarCompraPorId(999999),
        throwsA(isA<ArgumentError>()),
      );

      // TESTE 20: Fechar a fatura.
      await db.update(
        'fatura',
        {'status': 'FECHADA'},
        where: 'id = ?',
        whereArgs: [fatura['id']],
      );

      // TESTE 21: Impedir compra em fatura fechada.
      await expectLater(
        service.cadastrarCompra(
          cartaoId: cartaoId,
          categoriaId: categoriaId,
          descricao: 'Compra bloqueada',
          dataCompra: dataCompra,
          valorTotal: 15000,
        ),
        throwsA(isA<StateError>()),
      );

      // TESTE 22: Conferir que nenhum cadastro
      // inválido gerou registros adicionais.
      final comprasFinais = await db.query('compra_cartao');
      final faturasFinais = await db.query('fatura');
      final parcelasFinais = await db.query('parcela_cartao');

      expect(comprasFinais.length, 1);
      expect(faturasFinais.length, 1);
      expect(parcelasFinais.length, 1);

      // TESTE 23: Conferir integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
