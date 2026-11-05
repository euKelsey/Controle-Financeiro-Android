
import 'package:flutter/material.dart';

class AppTheme {
  // Cores financeiras para o tema escuro.
  static const Color receitaEscuro = Color(0xFF00D681);
  static const Color despesaEscuro = Color(0xFFFF455C);
  static const Color alertaEscuro = Color(0xFFFFB020);

  // Cores financeiras para o tema claro.
  static const Color receitaClaro = Color(0xFF008E58);
  static const Color despesaClaro = Color(0xFFD92845);
  static const Color alertaClaro = Color(0xFF9C6200);

  // Retorna as cores de acordo com o tema ativo.
  static Color corReceita(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? receitaEscuro
        : receitaClaro;
  }

  static Color corDespesa(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? despesaEscuro
        : despesaClaro;
  }

  static Color corAlerta(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? alertaEscuro
        : alertaClaro;
  }

  // Tema claro.
  static ThemeData get temaClaro {
    const fundo = Color(0xFFF5F5F6);
    const superficie = Color(0xFFFFFFFF);
    const texto = Color(0xFF17181B);

    final cores = ColorScheme.fromSeed(
      seedColor: const Color(0xFF34363C),
      brightness: Brightness.light,
    ).copyWith(
      primary: texto,
      onPrimary: Colors.white,
      surface: superficie,
      onSurface: texto,
      error: despesaClaro,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: cores,
      scaffoldBackgroundColor: fundo,
      appBarTheme: const AppBarTheme(
        backgroundColor: fundo,
        foregroundColor: texto,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(
            color: Color(0xFFE5E5E8),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: superficie,
        indicatorColor: Color(0xFFE5E5E8),
      ),
      dividerColor: const Color(0xFFE5E5E8),
    );
  }

  // Tema escuro.
  static ThemeData get temaEscuro {
    const fundo = Color(0xFF111216);
    const superficie = Color(0xFF22242A);
    const texto = Color(0xFFF5F5F5);

    final cores = ColorScheme.fromSeed(
      seedColor: const Color(0xFFD5D6DA),
      brightness: Brightness.dark,
    ).copyWith(
      primary: texto,
      onPrimary: fundo,
      surface: superficie,
      onSurface: texto,
      error: despesaEscuro,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cores,
      scaffoldBackgroundColor: fundo,
      appBarTheme: const AppBarTheme(
        backgroundColor: fundo,
        foregroundColor: texto,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(
            color: Color(0xFF35373E),
          ),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: superficie,
        indicatorColor: Color(0xFF41444C),
      ),
      dividerColor: const Color(0xFF35373E),
    );
  }
}
