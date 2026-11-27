import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

import '../screens/home_screen.dart';

class ControleFinanceiroApp extends StatefulWidget {
  final HomeScreen Function(ThemeMode, ValueChanged<ThemeMode>)? homeBuilder;

  const ControleFinanceiroApp({super.key, this.homeBuilder});

  @override
  State<ControleFinanceiroApp> createState() => _ControleFinanceiroAppState();
}

class _ControleFinanceiroAppState extends State<ControleFinanceiroApp> {
  final SharedPreferencesAsync _preferencias = SharedPreferencesAsync();

  static const String _chaveTema = 'tema_aplicativo';

  ThemeMode _temaAtual = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _carregarTema();
  }

  Future<void> _carregarTema() async {
    try {
      final temaSalvo = await _preferencias.getString(_chaveTema);

      if (!mounted) return;

      setState(() {
        _temaAtual = switch (temaSalvo) {
          'claro' => ThemeMode.light,
          'escuro' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
      });
    } catch (erro) {
      debugPrint('Erro ao carregar tema: $erro');
    }
  }

  Future<void> _alterarTema(ThemeMode novoTema) async {
    setState(() {
      _temaAtual = novoTema;
    });

    final valor = switch (novoTema) {
      ThemeMode.light => 'claro',
      ThemeMode.dark => 'escuro',
      ThemeMode.system => 'sistema',
    };

    try {
      await _preferencias.setString(_chaveTema, valor);
    } catch (erro) {
      debugPrint('Erro ao salvar tema: $erro');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle Financeiro',
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,

      theme: AppTheme.temaClaro,
      darkTheme: AppTheme.temaEscuro,

      themeMode: _temaAtual,

      home: widget.homeBuilder?.call(_temaAtual, _alterarTema) ??
          HomeScreen(temaAtual: _temaAtual, onTemaAlterado: _alterarTema),
    );
  }
}
