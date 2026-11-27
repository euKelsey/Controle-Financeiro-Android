import '../repositories/lancamento_repository.dart';
import '../repositories/fatura_repository.dart';
import '../models/lancamento_model.dart';

class DashboardService {
  final LancamentoRepository _lancamentoRepository;

  // Repositorio opcional para permitir os testes antigos do Dashboard
  // com SQLite isolado, sem abrir o banco principal do aplicativo.
  final FaturaRepository? _faturaRepository;

  DashboardService(
    this._lancamentoRepository, {
    FaturaRepository? faturaRepository,
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
    return repository.listarResumoDashboard(
      ano: ano,
      mes: mes,
      limite: limite,
    );
  }

  // Obtém o resumo de um mês específico.
  Future<({int receitas, int despesas, int saldoPrevisto})> obterResumoMensal({
    required int ano,
    required int mes,
  }) async {
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
