import '../repositories/recorrencia_repository.dart';
import '../repositories/lancamento_repository.dart';
import '../repositories/fatura_repository.dart';
import '../models/lancamento_model.dart';

class DashboardService {
  final LancamentoRepository _lancamentoRepository;

  // Repositorio opcional para permitir os testes antigos do Dashboard
  // com SQLite isolado, sem abrir o banco principal do aplicativo.
  final FaturaRepository? _faturaRepository;
  final RecorrenciaRepository? recorrencias;

  DashboardService(
    this._lancamentoRepository, {
    FaturaRepository? faturaRepository,
    this.recorrencias,
  }) : _faturaRepository = faturaRepository;

  Future<List<FaturaResumoDashboard>> listarFaturasDashboard({
    required int ano,
    required int mes,
    int limite = 5,
  }) async {
    final repository = _faturaRepository;
    if (repository == null) {
      return <FaturaResumoDashboard>[];
    }
    final faturas = await repository.listarResumoDashboard(
      ano: ano,
      mes: mes,
      limite: 50,
    );
    if (limite < 1 || limite > 50) throw ArgumentError('Limite inválido.');
    return faturas.where((f) => f.valorTotal > 0).take(limite).toList();
  }

  // Gera as recorrências uma vez e usa a mesma regra mensal para os 12 meses.
  Future<List<({int receitas, int despesas, int saldoPrevisto})>> obterResumoAnual({
    required int ano,
  }) async {
    if (ano < 1 || ano > 9998) throw ArgumentError('Ano inválido.');
    await recorrencias?.gerarAte(DateTime(ano, 12, 31));
    final resultado = <({int receitas, int despesas, int saldoPrevisto})>[];
    for (var mes = 1; mes <= 12; mes++) {
      resultado.add(await _lancamentoRepository.obterResumoMensal(ano: ano, mes: mes));
    }
    return resultado;
  }

  // Lista os lançamentos da data prevista no mês, exceto faturas,
  // que possuem sua própria seção por competência.
  Future<List<LancamentoModel>> listarLancamentosMes({
    required int ano, required int mes,
  }) async {
    await recorrencias?.gerarAte(DateTime(ano, 12, 31));
    final resultado = <LancamentoModel>[];
    for (var offset = 0; ; offset += 100) {
      final pagina = await _lancamentoRepository.listarPorPeriodo(
        ano: ano, mes: mes, limite: 100, deslocamento: offset);
      resultado.addAll(pagina.where((l) => l.origem != 'FATURA' && l.status != 'CANCELADO'));
      if (pagina.length < 100) break;
    }
    return resultado;
  }

  // Obtém o resumo de um mês específico.
  Future<({int receitas, int despesas, int saldoPrevisto})> obterResumoMensal({
    required int ano,
    required int mes,
  }) async {
    if (ano >= 1 && ano <= 9999 && mes >= 1 && mes <= 12) {
      await recorrencias?.gerarAte(DateTime(ano, 12, 31));
    }
    return _lancamentoRepository.obterResumoMensal(ano: ano, mes: mes);
  }

  // Obtém o resumo do mês atual do aparelho.
  Future<({int receitas, int despesas, int saldoPrevisto})>
  obterResumoAtual() async {
    final hoje = DateTime.now();

    return obterResumoMensal(ano: hoje.year, mes: hoje.month);
  }

  // Vencimentos pela data de pagamento, não pela competência da fatura.
  // Inclui os pendentes do mês inteiro, inclusive os já vencidos.
  Future<List<LancamentoModel>> listarVencimentosMes({
    required int ano, required int mes, int limite = 5,
  }) async {
    if (ano < 1 || ano > 9998 || mes < 1 || mes > 12 || limite < 1 || limite > 50) {
      throw ArgumentError('Período ou limite inválido.');
    }
    await recorrencias?.gerarAte(DateTime(ano, 12, 31));
    final inicio = RecorrenciaRepository.iso(DateTime(ano, mes, 1));
    final fim = RecorrenciaRepository.iso(DateTime(ano, mes+1, 1));
    final lista = await _lancamentoRepository.listarProximosVencimentos(
      dataReferencia: inicio, limite: limite);
    return lista.where((l) => l.dataPrevista.compareTo(fim) < 0).toList();
  }

  // Consulta os proximos vencimentos pendentes.
  Future<List<LancamentoModel>> listarProximosVencimentos({
    DateTime? dataReferencia,
    int limite = 5,
  }) async {
    // Utiliza a data informada ou a data atual.
    final data = dataReferencia ?? DateTime.now();
    if (data.year >= 1 && data.year < 9999) {
      await recorrencias?.gerarAte(DateTime(data.year + 1, 12, 31));
    }

    // Converte para o formato utilizado pelo SQLite.
    final dataFormatada =
        '${data.year.toString().padLeft(4, '0')}-'
        '${data.month.toString().padLeft(2, '0')}-'
        '${data.day.toString().padLeft(2, '0')}';

    // Solicita os lancamentos ao Repository.
    return _lancamentoRepository.listarProximosVencimentos(
      dataReferencia: dataFormatada,
      limite: limite,
    );
  }
}
