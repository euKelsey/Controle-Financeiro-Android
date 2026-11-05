
class CompetenciaFaturaService {
  // Retorna o último dia de determinado mês.
  static int _ultimoDiaMes(int ano, int mes) {
    return DateTime.utc(ano, mes + 1, 0).day;
  }

  // Formata uma data como AAAA-MM-DD.
  static String _formatarData(DateTime data) {
    final ano = data.year.toString().padLeft(4, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final dia = data.day.toString().padLeft(2, '0');

    return '$ano-$mes-$dia';
  }

  // Valida uma data ISO e retorna um DateTime.
  static DateTime _validarData(String data) {
    final formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (!formato.hasMatch(data)) {
      throw ArgumentError(
        'Informe uma data no formato AAAA-MM-DD.',
      );
    }

    final convertida = DateTime.tryParse(data);

    if (convertida == null ||
        _formatarData(convertida) != data) {
      throw ArgumentError(
        'A data informada é inválida.',
      );
    }

    return convertida;
  }

  // Determina a competência da fatura.
  static String calcularMesFatura({
    required String dataCompra,
    required int diaFechamento,
  }) {
    if (diaFechamento < 1 || diaFechamento > 31) {
      throw ArgumentError(
        'O dia de fechamento deve estar entre 1 e 31.',
      );
    }

    final compra = _validarData(dataCompra);

    final ultimoDia = _ultimoDiaMes(
      compra.year,
      compra.month,
    );

    final fechamentoReal =
        diaFechamento < ultimoDia
            ? diaFechamento
            : ultimoDia;

    var ano = compra.year;
    var mes = compra.month;

    // No dia do fechamento, a compra passa
    // para a próxima competência.
    if (compra.day >= fechamentoReal) {
      final proximoMes = DateTime.utc(
        ano,
        mes + 1,
        1,
      );

      ano = proximoMes.year;
      mes = proximoMes.month;
    }

    return '${ano.toString().padLeft(4, '0')}-'
        '${mes.toString().padLeft(2, '0')}';
  }

  // Calcula fechamento e vencimento da competência.
  static ({
    String dataFechamento,
    String dataVencimento,
  }) calcularDatasFatura({
    required String mesReferencia,
    required int diaFechamento,
    required int diaVencimento,
  }) {
    if (diaFechamento < 1 || diaFechamento > 31) {
      throw ArgumentError(
        'Dia de fechamento inválido.',
      );
    }

    if (diaVencimento < 1 || diaVencimento > 31) {
      throw ArgumentError(
        'Dia de vencimento inválido.',
      );
    }

    final formato = RegExp(r'^\d{4}-\d{2}$');

    if (!formato.hasMatch(mesReferencia)) {
      throw ArgumentError(
        'O mês de referência deve estar em AAAA-MM.',
      );
    }

    final partes = mesReferencia.split('-');
    final ano = int.parse(partes[0]);
    final mes = int.parse(partes[1]);

    if (ano < 1 || mes < 1 || mes > 12) {
      throw ArgumentError(
        'Mês de referência inválido.',
      );
    }

    // Calcula a data real de fechamento.
    final ultimoDiaFechamento = _ultimoDiaMes(
      ano,
      mes,
    );

    final diaRealFechamento =
        diaFechamento < ultimoDiaFechamento
            ? diaFechamento
            : ultimoDiaFechamento;

    final fechamento = DateTime.utc(
      ano,
      mes,
      diaRealFechamento,
    );

    // Se o vencimento nominal ocorre até o
    // dia de fechamento, usamos o mês seguinte.
    var anoVencimento = ano;
    var mesVencimento = mes;

    if (diaVencimento <= diaFechamento) {
      final proximoMes = DateTime.utc(
        ano,
        mes + 1,
        1,
      );

      anoVencimento = proximoMes.year;
      mesVencimento = proximoMes.month;
    }

    // Ajusta dias que não existem no mês.
    var ultimoDiaVencimento = _ultimoDiaMes(
      anoVencimento,
      mesVencimento,
    );

    var diaRealVencimento =
        diaVencimento < ultimoDiaVencimento
            ? diaVencimento
            : ultimoDiaVencimento;

    var vencimento = DateTime.utc(
      anoVencimento,
      mesVencimento,
      diaRealVencimento,
    );

    // Garante que o vencimento seja
    // posterior ao fechamento.
    if (!vencimento.isAfter(fechamento)) {
      final proximoMes = DateTime.utc(
        anoVencimento,
        mesVencimento + 1,
        1,
      );

      anoVencimento = proximoMes.year;
      mesVencimento = proximoMes.month;

      ultimoDiaVencimento = _ultimoDiaMes(
        anoVencimento,
        mesVencimento,
      );

      diaRealVencimento =
          diaVencimento < ultimoDiaVencimento
              ? diaVencimento
              : ultimoDiaVencimento;

      vencimento = DateTime.utc(
        anoVencimento,
        mesVencimento,
        diaRealVencimento,
      );
    }

    return (
      dataFechamento: _formatarData(fechamento),
      dataVencimento: _formatarData(vencimento),
    );
  }
}
