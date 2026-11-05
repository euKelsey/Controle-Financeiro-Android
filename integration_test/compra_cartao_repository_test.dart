
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/models/compra_cartao_model.dart';
import 'package:controle_financeiro_android/repositories/compra_cartao_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Testa cadastro e consultas de compras no cartao',
      (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_compra_cartao_repository.db',
    );

    // Remove somente o banco temporário deste teste.
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
      final repository = CompraCartaoRepository(banco: db);

      // TESTE 1: Criar cartão válido.
      final cartaoId = await db.insert(
        'cartao',
        {
          'nome': 'Nubank Principal',
          'instituicao': 'Nubank',
          'limite_total': 500000,
          'dia_fechamento': 2,
          'dia_vencimento': 10,
        },
      );

      // TESTE 2: Criar categoria de despesa.
      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Alimentação',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // TESTE 3: Inserir primeira compra.
      final primeira = await repository.inserir(
        CompraCartaoModel(
          cartaoId: cartaoId,
          categoriaId: categoriaId,
          descricao: 'Supermercado',
          dataCompra: '2026-11-05',
          valorTotal: 25990,
        ),
      );

      expect(primeira.id, isNotNull);
      expect(primeira.id, greaterThan(0));
      expect(primeira.descricao, 'Supermercado');
      expect(primeira.valorTotal, 25990);
      expect(primeira.quantidadeParcelas, 1);
      expect(primeira.status, 'ATIVA');

      // TESTE 4: Consultar compra por ID.
      final encontrada = await repository.buscarPorId(
        primeira.id!,
      );

      expect(encontrada, isNotNull);
      expect(encontrada!.cartaoId, cartaoId);
      expect(encontrada.categoriaId, categoriaId);
      expect(encontrada.descricao, 'Supermercado');
      expect(encontrada.valorTotal, 25990);
      expect(encontrada.dataCompra, '2026-11-05');
      expect(encontrada.quantidadeParcelas, 1);
      expect(encontrada.primeiraParcelaControlada, 0);

      // TESTE 5: Inserir segunda compra.
      final segunda = await repository.inserir(
        CompraCartaoModel(
          cartaoId: cartaoId,
          categoriaId: categoriaId,
          descricao: 'Farmácia',
          dataCompra: '2026-11-10',
          valorTotal: 8500,
        ),
      );

      expect(segunda.id, isNotNull);

      // TESTE 6: Inserir terceira compra na mesma data.
      final terceira = await repository.inserir(
        CompraCartaoModel(
          cartaoId: cartaoId,
          categoriaId: categoriaId,
          descricao: 'Restaurante',
          dataCompra: '2026-11-10',
          valorTotal: 12050,
        ),
      );

      expect(terceira.id, isNotNull);

      // TESTE 7: Listar por data e ID decrescente.
      final compras = await repository.listar();

      expect(compras.length, 3);

      // Mesma data: ID mais recente aparece primeiro.
      expect(compras[0].descricao, 'Restaurante');
      expect(compras[1].descricao, 'Farmácia');

      // Compra com data anterior aparece por último.
      expect(compras[2].descricao, 'Supermercado');

      // TESTE 8: Confirmar valores em centavos.
      expect(compras[0].valorTotal, 12050);
      expect(compras[1].valorTotal, 8500);
      expect(compras[2].valorTotal, 25990);

      // TESTE 9: Buscar compra inexistente.
      final inexistente = await repository.buscarPorId(999999);

      expect(inexistente, isNull);

      // TESTE 10: Impedir compra com cartão inexistente.
      await expectLater(
        repository.inserir(
          CompraCartaoModel(
            cartaoId: 999999,
            categoriaId: categoriaId,
            descricao: 'Cartão inexistente',
            dataCompra: '2026-11-15',
            valorTotal: 10000,
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 11: Impedir compra com categoria inexistente.
      await expectLater(
        repository.inserir(
          CompraCartaoModel(
            cartaoId: cartaoId,
            categoriaId: 999999,
            descricao: 'Categoria inexistente',
            dataCompra: '2026-11-15',
            valorTotal: 10000,
          ),
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 12: Confirmar que somente três compras
      // foram armazenadas no SQLite.
      final registros = await db.query('compra_cartao');

      expect(registros.length, 3);

      // TESTE 13: Conferir integridade referencial.
      final integridade = await db.rawQuery(
        'PRAGMA foreign_key_check;',
      );

      expect(integridade, isEmpty);
    } finally {
      // Fecha e remove exclusivamente o banco temporário.
      await db.close();
      await deleteDatabase(caminho);
    }
  });

  
  testWidgets('Testa transacoes e rollback de compras no cartao',
      (tester) async {
    final pasta = await getDatabasesPath();

    final caminho = join(
      pasta,
      'teste_compra_cartao_transacao.db',
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
      final repository = CompraCartaoRepository(banco: db);

      // Funcoes auxiliares para datas ISO.
      String dataIso(DateTime data) {
        return '${data.year.toString().padLeft(4, '0')}-'
            '${data.month.toString().padLeft(2, '0')}-'
            '${data.day.toString().padLeft(2, '0')}';
      }

      String mesIso(DateTime data) {
        return '${data.year.toString().padLeft(4, '0')}-'
            '${data.month.toString().padLeft(2, '0')}';
      }

      final hoje = DateTime.now();
      final fechamento = DateTime(
        hoje.year,
        hoje.month + 3,
        15,
      );
      final vencimento = DateTime(
        hoje.year,
        hoje.month + 3,
        25,
      );

      final fechamentoErro = DateTime(
        hoje.year,
        hoje.month + 4,
        15,
      );
      final vencimentoErro = DateTime(
        hoje.year,
        hoje.month + 4,
        25,
      );

      final fechamentoParcela = DateTime(
        hoje.year,
        hoje.month + 5,
        15,
      );
      final vencimentoParcela = DateTime(
        hoje.year,
        hoje.month + 5,
        25,
      );

      // TESTE 1: Criar cartao e categoria.
      final cartaoId = await db.insert(
        'cartao',
        {
          'nome': 'Cartao Teste',
          'instituicao': 'Banco Teste',
          'limite_total': 500000,
          'dia_fechamento': 15,
          'dia_vencimento': 25,
        },
      );

      final categoriaId = await db.insert(
        'categoria',
        {
          'nome': 'Alimentacao',
          'tipo': 'DESPESA',
          'status': 'ATIVA',
        },
      );

      // Funcao auxiliar para criar compras em 1x.
      CompraCartaoModel criarCompra(
        String descricao,
        int valor, {
        int? categoria,
      }) {
        return CompraCartaoModel(
          cartaoId: cartaoId,
          categoriaId: categoria ?? categoriaId,
          descricao: descricao,
          dataCompra: dataIso(hoje),
          valorTotal: valor,
        );
      }

      // TESTE 2: Criar compra e fatura automaticamente.
      final primeira = await repository.inserirCompraComParcela(
        compra: criarCompra('Supermercado', 25990),
        mesReferencia: mesIso(fechamento),
        dataFechamento: dataIso(fechamento),
        dataVencimento: dataIso(vencimento),
      );

      expect(primeira.id, isNotNull);
      expect(primeira.valorTotal, 25990);
      expect(primeira.quantidadeParcelas, 1);

      final faturas = await db.query('fatura');

      expect(faturas.length, 1);
      expect(faturas.first['status'], 'ABERTA');

      final faturaId = faturas.first['id'] as int;

      // TESTE 3: Conferir parcela unica.
      final parcelas = await db.query(
        'parcela_cartao',
        where: 'compra_cartao_id = ?',
        whereArgs: [primeira.id],
      );

      expect(parcelas.length, 1);
      expect(parcelas.first['fatura_id'], faturaId);
      expect(parcelas.first['numero_parcela'], 1);
      expect(parcelas.first['valor'], 25990);
      expect(
        parcelas.first['data_prevista'],
        dataIso(vencimento),
      );

      // TESTE 4: Reutilizar a fatura aberta.
      final segunda = await repository.inserirCompraComParcela(
        compra: criarCompra('Farmacia', 8500),
        mesReferencia: mesIso(fechamento),
        dataFechamento: dataIso(fechamento),
        dataVencimento: dataIso(vencimento),
      );

      expect(segunda.id, isNotNull);

      final faturasAposSegunda = await db.query('fatura');

      expect(faturasAposSegunda.length, 1);

      final parcelasAposSegunda = await db.query(
        'parcela_cartao',
      );

      expect(parcelasAposSegunda.length, 2);

      for (final parcela in parcelasAposSegunda) {
        expect(parcela['fatura_id'], faturaId);
      }

      // TESTE 5: Fechar a fatura.
      await db.update(
        'fatura',
        {'status': 'FECHADA'},
        where: 'id = ?',
        whereArgs: [faturaId],
      );

      // TESTE 6: Impedir compra em fatura fechada.
      await expectLater(
        repository.inserirCompraComParcela(
          compra: criarCompra('Compra bloqueada', 10000),
          mesReferencia: mesIso(fechamento),
          dataFechamento: dataIso(fechamento),
          dataVencimento: dataIso(vencimento),
        ),
        throwsA(isA<StateError>()),
      );

      // TESTE 7: Impedir criar fatura com
      // fechamento ja atingido.
      await expectLater(
        repository.inserirCompraComParcela(
          compra: criarCompra('Compra fora do prazo', 12000),
          mesReferencia: mesIso(hoje),
          dataFechamento: dataIso(hoje),
          dataVencimento: dataIso(vencimento),
        ),
        throwsA(isA<StateError>()),
      );

      // TESTE 8: Forcar erro de chave estrangeira
      // em uma nova fatura.
      await expectLater(
        repository.inserirCompraComParcela(
          compra: criarCompra(
            'Categoria inexistente',
            15000,
            categoria: 999999,
          ),
          mesReferencia: mesIso(fechamentoErro),
          dataFechamento: dataIso(fechamentoErro),
          dataVencimento: dataIso(vencimentoErro),
        ),
        throwsA(isA<DatabaseException>()),
      );

      // TESTE 9: Confirmar rollback da fatura.
      final faturaErro = await db.query(
        'fatura',
        where: 'mes_referencia = ?',
        whereArgs: [mesIso(fechamentoErro)],
      );

      expect(faturaErro, isEmpty);

      // TESTE 10: Forcar erro na insercao da parcela.
      // Trigger exclusivo deste banco de testes.
      await db.execute('''
        CREATE TRIGGER bloquear_parcela_teste
        BEFORE INSERT ON parcela_cartao
        BEGIN
          SELECT RAISE(ABORT, 'Falha simulada na parcela');
        END;
      ''');

      await expectLater(
        repository.inserirCompraComParcela(
          compra: criarCompra('Falha na parcela', 20000),
          mesReferencia: mesIso(fechamentoParcela),
          dataFechamento: dataIso(fechamentoParcela),
          dataVencimento: dataIso(vencimentoParcela),
        ),
        throwsA(isA<DatabaseException>()),
      );

      // Remove o trigger usado para simular o erro.
      await db.execute(
        'DROP TRIGGER bloquear_parcela_teste',
      );

      // TESTE 11: Confirmar rollback completo.
      final faturaParcela = await db.query(
        'fatura',
        where: 'mes_referencia = ?',
        whereArgs: [mesIso(fechamentoParcela)],
      );

      expect(faturaParcela, isEmpty);

      final comprasFinais = await db.query('compra_cartao');
      final parcelasFinais = await db.query('parcela_cartao');
      final faturasFinais = await db.query('fatura');

      expect(comprasFinais.length, 2);
      expect(parcelasFinais.length, 2);
      expect(faturasFinais.length, 1);

      // TESTE 12: Verificar integridade referencial.
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
