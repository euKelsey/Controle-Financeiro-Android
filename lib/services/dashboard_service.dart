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
