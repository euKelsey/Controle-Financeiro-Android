
import 'package:flutter_test/flutter_test.dart';
import 'package:controle_financeiro_android/app/app.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    // Cria um armazenamento vazio para cada teste.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('Exibe as quatro abas principais', (tester) async {
    await tester.pumpWidget(const ControleFinanceiroApp());
    await tester.pumpAndSettle();

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Lançamentos'), findsOneWidget);
    expect(find.text('Cartões'), findsOneWidget);
    expect(find.text('Mais'), findsOneWidget);
  });

  testWidgets('Permite navegar entre as abas', (tester) async {
    await tester.pumpWidget(const ControleFinanceiroApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lançamentos'));
    await tester.pumpAndSettle();

    expect(
      find.text('Lançamentos em desenvolvimento'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cartões'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cartões em desenvolvimento'),
      findsOneWidget,
    );
  });

  testWidgets('Exibe as opções de tema', (tester) async {
    await tester.pumpWidget(const ControleFinanceiroApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Selecionar tema'));
    await tester.pumpAndSettle();

    expect(find.text('Claro'), findsOneWidget);
    expect(find.text('Escuro'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
  });
}
