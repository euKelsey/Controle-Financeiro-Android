import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro_android/app/app.dart';
import 'package:controle_financeiro_android/screens/home_screen.dart';
import 'package:controle_financeiro_android/screens/dashboard_screen.dart';
import 'package:controle_financeiro_android/screens/lancamentos_screen.dart';
import 'package:controle_financeiro_android/screens/cartoes_screen.dart';
import 'package:controle_financeiro_android/services/dashboard_service.dart';
import 'package:controle_financeiro_android/services/lancamento_service.dart';
import 'package:controle_financeiro_android/services/cartao_service.dart';
import 'package:controle_financeiro_android/services/fatura_service.dart';
import 'package:controle_financeiro_android/repositories/lancamento_repository.dart';
import 'package:controle_financeiro_android/repositories/cartao_repository.dart';
import 'package:controle_financeiro_android/repositories/fatura_repository.dart';
import 'package:controle_financeiro_android/models/cartao_model.dart';
import 'package:controle_financeiro_android/models/lancamento_model.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Repositories em memoria para testar a interface sem plugin nativo.
// O SQLite real continua coberto pelos testes de integracao no Android.
class _LancamentosVazios extends LancamentoRepository {
  @override
  Future<({int receitas, int despesas, int saldoPrevisto})> obterResumoMensal({
    required int ano, required int mes,
  }) async => (receitas: 0, despesas: 0, saldoPrevisto: 0);

  @override
  Future<List<LancamentoModel>> listarProximosVencimentos({
    required String dataReferencia, int limite = 5,
  }) async => [];

  @override
  Future<List<LancamentoModel>> listarPorPeriodo({
    required int ano, required int mes, String? tipo, String? status,
    int limite = 100, int deslocamento = 0,
  }) async => [];
}

class _CartoesVazios extends CartaoRepository {
  @override
  Future<List<CartaoModel>> listar() async => [];
}

class _FaturasVazias extends FaturaRepository {
  @override
  Future<List<FaturaResumoDashboard>> listarResumoDashboard({
    required int ano, required int mes, int limite = 5,
  }) async => [];

  @override
  Future<({int faturasFechadas, int lancamentosGerados})>
      processarFaturasAutomaticamente({required String dataReferencia}) async =>
          (faturasFechadas: 0, lancamentosGerados: 0);
}

ControleFinanceiroApp _appTeste() {
  final lancamentos = _LancamentosVazios();
  final faturas = _FaturasVazias();
  final dashboard = DashboardService(lancamentos, faturaRepository: faturas);
  final service = LancamentoService(lancamentos);
  final cartoes = CartaoService(_CartoesVazios());
  final faturaService = FaturaService(faturas);
  return ControleFinanceiroApp(
    homeBuilder: (tema, alterar) => HomeScreen(
      temaAtual: tema,
      onTemaAlterado: alterar,
      faturaService: faturaService,
      dashboardBuilder: (r) => DashboardScreen(service: dashboard, revisaoDados: r, iniciarAnual: true),
      lancamentosBuilder: (r) => LancamentosScreen(service: service, revisaoDados: r),
      cartoesBuilder: (r) => CartoesScreen(
        cartaoService: cartoes,
        faturaRepository: faturas,
        faturaService: faturaService,
        revisaoDados: r,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Exibe as quatro abas principais', (tester) async {
    await tester.pumpWidget(_appTeste());
    await tester.pumpAndSettle();
    for (final label in ['Início', 'Lançamentos', 'Cartões', 'Mais']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    expect(find.text('Saldo previsto anual'), findsOneWidget);
  });

  testWidgets('Permite navegar entre as abas', (tester) async {
    await tester.pumpWidget(_appTeste());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Lançamentos'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum lançamento neste período.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Cartões'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum cartão cadastrado.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Início'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo previsto anual'), findsOneWidget);
  });

  testWidgets('Navega entre anos e abre o mês selecionado', (tester) async {
    await tester.pumpWidget(_appTeste());
    await tester.pumpAndSettle();
    final ano = DateTime.now().year;
    expect(find.text('$ano'), findsOneWidget);
    await tester.tap(find.byTooltip('Próximo ano'));
    await tester.pumpAndSettle();
    expect(find.text('${ano + 1}'), findsOneWidget);
    final mes = find.byKey(const ValueKey('mes-1'));
    await tester.ensureVisible(mes);
    await tester.tap(mes);
    await tester.pumpAndSettle();
    expect(find.text('Janeiro de ${ano + 1}'), findsOneWidget);
    expect(find.text('Resumo do mês'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('${ano + 1}'), findsOneWidget);
    await tester.ensureVisible(find.text('Voltar ao ano atual'));
    await tester.tap(find.text('Voltar ao ano atual'));
    await tester.pumpAndSettle();
    expect(find.text('$ano'), findsOneWidget);
  });

  testWidgets('Exibe as opções de tema', (tester) async {
    await tester.pumpWidget(_appTeste());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Selecionar tema'));
    await tester.pumpAndSettle();
    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
  });
}
