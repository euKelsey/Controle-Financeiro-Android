import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/fatura_repository.dart';
import 'package:controle_financeiro_android/repositories/movimentacao_repository.dart';
import 'package:controle_financeiro_android/services/fatura_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Resumo mantém competência da fatura sem duplicidade', (tester) async {
    final caminho = join(await getDatabasesPath(), 'teste_resumo_competencia.db');
    await deleteDatabase(caminho);
    final schema = await rootBundle.loadString('assets/sql/schema.sql');
    final db = await openDatabase(caminho, version: 1,
      onConfigure: (b) async { await b.execute('PRAGMA foreign_keys = ON'); },
      onCreate: (b, v) async {
        for (final comando in schema.split(';')) {
          if (comando.trim().isNotEmpty) await b.execute(comando.trim());
        }
      },
    );
    try {
      final categoria = await db.insert('categoria', {
        'nome': 'Mercado', 'tipo': 'DESPESA', 'status': 'ATIVA',
      });
      final cartao = await db.insert('cartao', {
        'nome': 'Teste', 'instituicao': 'Banco', 'limite_total': 500000,
        'dia_fechamento': 25, 'dia_vencimento': 5, 'status': 'ATIVO',
      });
      final fatura = await db.insert('fatura', {
        'cartao_id': cartao, 'mes_referencia': '2026-12',
        'data_fechamento': '2026-12-25', 'data_vencimento': '2027-01-05',
        'status': 'ABERTA',
      });
      for (final (valor, status) in [(25000, 'ATIVA'), (15000, 'ATIVA'), (9000, 'CANCELADA')]) {
        final compra = await db.insert('compra_cartao', {
          'cartao_id': cartao, 'categoria_id': categoria,
          'descricao': 'Compra teste', 'data_compra': '2026-11-27',
          'valor_total': valor, 'quantidade_parcelas': 1, 'status': status,
        });
        await db.insert('parcela_cartao', {
          'compra_cartao_id': compra, 'fatura_id': fatura,
          'numero_parcela': 1, 'valor': valor, 'data_prevista': '2027-01-05',
        });
      }
      await db.insert('lancamento', {
        'tipo': 'DESPESA', 'descricao': 'Despesa manual',
        'valor_previsto': 10000, 'data_prevista': '2026-12-10',
        'categoria_id': categoria, 'status': 'PENDENTE', 'origem': 'MANUAL',
      });
      final lancamentos = LancamentoRepository(banco: db);
      final service = FaturaService(FaturaRepository(banco: db),
        lancamentoRepository: lancamentos,
        movimentacaoRepository: MovimentacaoRepository(banco: db),
      );
      Future<void> conferir() async {
        final dezembro = await lancamentos.obterResumoMensal(ano: 2026, mes: 12);
        expect(dezembro.despesas, 50000);
        expect(dezembro.saldoPrevisto, -50000);
        expect((await lancamentos.obterResumoMensal(ano: 2026, mes: 11)).despesas, 0);
        expect((await lancamentos.obterResumoMensal(ano: 2027, mes: 1)).despesas, 0);
      }
      await conferir();
      expect((await db.query('lancamento')).length, 1);
      final fechamento = await service.atualizarFaturasAutomaticamente(dataReferencia: '2026-12-25');
      expect(fechamento.lancamentosGerados, 1);
      await conferir();
      await service.pagarFatura(faturaId: fatura, dataPagamento: '2027-01-05', forma: 'PIX');
      await conferir();
      expect((await db.query('lancamento')).length, 2);
      expect((await db.query('movimentacao')).length, 1);
      expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    } finally {
      await db.close();
      await deleteDatabase(caminho);
    }
  });
}
