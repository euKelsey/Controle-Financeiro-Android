import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'lancamentos_screen.dart';
import 'cartoes_screen.dart';
import 'mais_screen.dart';
import '../repositories/fatura_repository.dart';
import '../services/fatura_service.dart';

class HomeScreen extends StatefulWidget {
  final FaturaService? faturaService;
  final DashboardScreen Function(int)? dashboardBuilder;
  final LancamentosScreen Function(int)? lancamentosBuilder;
  final CartoesScreen Function(int)? cartoesBuilder;
  final ThemeMode temaAtual;
  final ValueChanged<ThemeMode> onTemaAlterado;

  const HomeScreen({
    super.key,
    this.faturaService,
    this.dashboardBuilder,
    this.lancamentosBuilder,
    this.cartoesBuilder,
    required this.temaAtual,
    required this.onTemaAlterado,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _indiceAtual = 0;

  int _revisaoDados = 0;
  bool _inicializando = true;
  bool _processando = false;
  String? _erroInicializacao;
  late final _faturas = widget.faturaService ?? FaturaService(FaturaRepository());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _processarFaturas();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _processarFaturas();
  }

  Future<void> _processarFaturas() async {
    if (_processando) return;
    _processando = true;
    try {
      await _faturas.atualizarFaturasAutomaticamente();
      if (!mounted) return;
      setState(() {
        _erroInicializacao = null;
        _inicializando = false;
        _revisaoDados++;
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erroInicializacao = 'Não foi possível processar as faturas automaticamente.';
        _inicializando = false;
      });
      debugPrint('Erro no processamento automático: $erro');
    } finally {
      _processando = false;
    }
  }

  void _selecionarPagina(int indice) {
    setState(() {
      _indiceAtual = indice;
      _revisaoDados++;
    });
    _processarFaturas();
  }

  List<Widget> get _paginas => [
    widget.dashboardBuilder?.call(_revisaoDados) ??
        DashboardScreen(revisaoDados: _revisaoDados, iniciarAnual: true),
    widget.lancamentosBuilder?.call(_revisaoDados) ??
        LancamentosScreen(revisaoDados: _revisaoDados),
    widget.cartoesBuilder?.call(_revisaoDados) ??
        CartoesScreen(revisaoDados: _revisaoDados),
    const MaisScreen(),
  ];

  IconData _iconeTema() {
    switch (widget.temaAtual) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle Financeiro'),
        actions: [
          PopupMenuButton<ThemeMode>(
            tooltip: 'Selecionar tema',
            icon: Icon(_iconeTema()),
            initialValue: widget.temaAtual,
            onSelected: widget.onTemaAlterado,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: ThemeMode.light,
                child: ListTile(
                  leading: Icon(Icons.light_mode_outlined),
                  title: Text('Claro'),
                ),
              ),
              PopupMenuItem(
                value: ThemeMode.dark,
                child: ListTile(
                  leading: Icon(Icons.dark_mode_outlined),
                  title: Text('Escuro'),
                ),
              ),
              PopupMenuItem(
                value: ThemeMode.system,
                child: ListTile(
                  leading: Icon(Icons.brightness_auto_outlined),
                  title: Text('Sistema'),
                ),
              ),
            ],
          ),
        ],
      ),

      body: _inicializando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_erroInicializacao != null)
                  MaterialBanner(
                    content: Text(_erroInicializacao!),
                    actions: [
                      TextButton(
                        onPressed: _processarFaturas,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                Expanded(
                  child: IndexedStack(index: _indiceAtual, children: _paginas),
                ),
              ],
            ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceAtual,
        onDestinationSelected: _selecionarPagina,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Lançamentos',
          ),
          NavigationDestination(
            icon: Icon(Icons.credit_card_outlined),
            selectedIcon: Icon(Icons.credit_card),
            label: 'Cartões',
          ),
          NavigationDestination(icon: Icon(Icons.menu), label: 'Mais'),
        ],
      ),
    );
  }
}
