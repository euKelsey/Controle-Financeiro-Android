
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Repository consulta proximos vencimentos corretamente',
    (tester) async {
      // ETAPA 1: Criar banco temporario.
      final pasta = await getDatabasesPath();

      final caminho = join(
        pasta,
        'teste_vencimentos_repository.db',
      );

      await deleteDatabase(caminho);

      final schema = await rootBundle.loadString(
        'assets/sql/schema.sql',
      );

      final db = await openDatabase(
        caminho,
        version: 1,
        onConfigure: (database) async {
          await database.execute(
            'PRAGMA foreign_keys = ON',
          );
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
        // ETAPA 2: Criar categorias.
        final categoriaDespesa = await db.insert(
          'categoria',
          {
            'nome': 'Despesas - Teste Vencimentos',
            'tipo': 'DESPESA',
            'status': 'ATIVA',
          },
        );

        final categoriaReceita = await db.insert(
          'categoria',
          {
            'nome': 'Receitas - Teste Vencimentos',
            'tipo': 'RECEITA',
            'status': 'ATIVA',
          },
        );

        // Funcao auxiliar para criar lancamentos.
        Future<int> cadastrar({
          required String descricao,
          required String tipo,
          required String data,
          required String status,
        }) async {
          return db.insert(
            'lancamento',
            {
              'descricao': descricao,
              'tipo': tipo,
              'valor_previsto': 10000,
              'data_prevista': data,
              'categoria_id': tipo == 'RECEITA'
                  ? categoriaReceita
                  : categoriaDespesa,
              'status': status,
              'origem': 'MANUAL',
            },
          );
        }

        // ETAPA 3: Criar dados controlados.
        await cadastrar(
          descricao: 'Conta atrasada',
          tipo: 'DESPESA',
          data: '2026-11-04',
          status: 'PENDENTE',
        );

        await cadastrar(
          descricao: 'Conta de hoje',
          tipo: 'DESPESA',
          data: '2026-11-05',
          status: 'PENDENTE',
        );

        await cadastrar(
          descricao: 'Salario a receber',
          tipo: 'RECEITA',
          data: '2026-11-06',
          status: 'PENDENTE',
        );

        await cadastrar(
          descricao: 'Conta efetivada',
          tipo: 'DESPESA',
          data: '2026-11-07',
          status: 'EFETIVADO',
        );

        await cadastrar(
          descricao: 'Conta cancelada',
          tipo: 'DESPESA',
          data: '2026-11-08',
          status: 'CANCELADO',
        );

        await cadastrar(
          descricao: 'Internet',
          tipo: 'DESPESA',
          data: '2026-11-09',
          status: 'PENDENTE',
        );

        await cadastrar(
          descricao: 'Energia',
          tipo: 'DESPESA',
          data: '2026-11-10',
          status: 'PENDENTE',
        );

        await cadastrar(
          descricao: 'Aluguel',
          tipo: 'DESPESA',
          data: '2026-11-11',
          status: 'PENDENTE',
        );

        await cadastrar(
          descricao: 'Outra conta',
          tipo: 'DESPESA',
          data: '2026-11-12',
          status: 'PENDENTE',
        );

        // ETAPA 4: Criar o Repository.
        final repository = LancamentoRepository(
          banco: db,
        );

        // TESTE 1: Limite padrao de cinco.
        final proximos =
            await repository.listarProximosVencimentos(
          dataReferencia: '2026-11-05',
        );

        expect(proximos.length, 5);

        // TESTE 2: Conferir a ordem das contas.
        expect(
          proximos.map((item) => item.descricao).toList(),
          [
            'Conta de hoje',
            'Salario a receber',
            'Internet',
            'Energia',
            'Aluguel',
          ],
        );

        // TESTE 3: Consultar com limite diferente.
        final apenasDois =
            await repository.listarProximosVencimentos(
          dataReferencia: '2026-11-05',
          limite: 2,
        );

        expect(apenasDois.length, 2);

        expect(
          apenasDois.first.descricao,
          'Conta de hoje',
        );

        // TESTE 4: Consultar um periodo vazio.
        final vazios =
            await repository.listarProximosVencimentos(
          dataReferencia: '2027-01-01',
        );

        expect(vazios, isEmpty);

        // TESTE 5: Validar data incorreta.
        await expectLater(
          repository.listarProximosVencimentos(
            dataReferencia: '05/11/2026',
          ),
          throwsArgumentError,
        );

        // TESTE 6: Validar data inexistente.
        await expectLater(
          repository.listarProximosVencimentos(
            dataReferencia: '2026-02-30',
          ),
          throwsArgumentError,
        );

        // TESTE 7: Validar limite minimo.
        await expectLater(
          repository.listarProximosVencimentos(
            dataReferencia: '2026-11-05',
            limite: 0,
          ),
          throwsArgumentError,
        );

        // TESTE 8: Validar limite maximo.
        await expectLater(
          repository.listarProximosVencimentos(
            dataReferencia: '2026-11-05',
            limite: 51,
          ),
          throwsArgumentError,
        );

        // TESTE 9: Verificar integridade do banco.
        final integridade = await db.rawQuery(
          'PRAGMA foreign_key_check;',
        );

        expect(integridade, isEmpty);

        // TESTE 10: Confirmar que a consulta
        // nao alterou os lancamentos.
        final registros = await db.query(
          'lancamento',
        );

        expect(registros.length, 9);
      } finally {
        await db.close();
        await deleteDatabase(caminho);
      }
    },
  );
}
