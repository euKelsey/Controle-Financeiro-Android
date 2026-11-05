import '../repositories/lancamento_repository.dart';
import '../models/lancamento_model.dart';

class DashboardService {
  final LancamentoRepository _lancamentoRepository;

  DashboardService(this._lancamentoRepository);

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
