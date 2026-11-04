import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'lancamentos_screen.dart';
import 'cartoes_screen.dart';
import 'mais_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeMode temaAtual;
  final ValueChanged<ThemeMode> onTemaAlterado;

  const HomeScreen({
    super.key,
    required this.temaAtual,
    required this.onTemaAlterado,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceAtual = 0;

  final List<Widget> _paginas = const [
    DashboardScreen(),
    LancamentosScreen(),
    CartoesScreen(),
    MaisScreen(),
  ];

  void _selecionarPagina(int indice) {
    setState(() {
      _indiceAtual = indice;
    });
  }

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

      body: IndexedStack(index: _indiceAtual, children: _paginas),

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
