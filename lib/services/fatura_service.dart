import '../models/fatura_model.dart';
import '../repositories/fatura_repository.dart';
import '../models/movimentacao_model.dart';
import '../repositories/lancamento_repository.dart';
import '../repositories/movimentacao_repository.dart';

class FaturaService {
  final FaturaRepository _repository;
  final LancamentoRepository? lancamentoRepository;
  final MovimentacaoRepository? movimentacaoRepository;

  FaturaService(
    this._repository, {
    this.lancamentoRepository,
    this.movimentacaoRepository,
  });

  // Lista todas as faturas cadastradas.
  Future<List<FaturaModel>> listarFaturas() async {
    return _repository.listar();
  }

  // Busca uma fatura específica pelo ID.
  Future<FaturaModel> buscarFaturaPorId(int faturaId) async {
    if (faturaId <= 0) {
      throw ArgumentError('ID da fatura inválido.');
    }

    final fatura = await _repository.buscarPorId(faturaId);

    if (fatura == null) {
      throw ArgumentError('Fatura não encontrada.');
    }

    return fatura;
  }

  // Obtém o total da fatura em centavos.
  Future<int> obterTotalFatura(int faturaId) async {
    // Reutiliza as validações da consulta.
    await buscarFaturaPorId(faturaId);

    return _repository.calcularTotalFatura(faturaId);
  }

  // Processa os fechamentos automáticos.
  Future<({int faturasFechadas, int lancamentosGerados})>
  atualizarFaturasAutomaticamente({String? dataReferencia}) async {
    // Quando nenhuma data é informada,
    // utiliza a data local do aparelho.
    final hoje = DateTime.now();

    final dataAtual =
        '${hoje.year.toString().padLeft(4, '0')}-'
        '${hoje.month.toString().padLeft(2, '0')}-'
        '${hoje.day.toString().padLeft(2, '0')}';

    final referencia = dataReferencia ?? dataAtual;

    // O Repository valida a data e executa
    // fechamento e lançamentos na mesma transação.
    return _repository.processarFaturasAutomaticamente(
      dataReferencia: referencia,
    );
  }

  // Registra o pagamento integral de uma fatura fechada.
  Future<MovimentacaoModel> pagarFatura({
    required int faturaId,
    required String dataPagamento,
    required String forma,
    String? observacao,
  }) async {
    // REGRA 1: Conferir os Repositories necessários.
    final lancamentoRepo = lancamentoRepository;
    final movimentacaoRepo = movimentacaoRepository;

    if (lancamentoRepo == null || movimentacaoRepo == null) {
      throw StateError('Os Repositories de pagamento não foram configurados.');
    }

    // REGRA 2: Localizar a fatura.
    final fatura = await buscarFaturaPorId(faturaId);

    // REGRA 3: A fatura precisa estar fechada.
    if (fatura.status != 'FECHADA') {
      throw ArgumentError('Somente faturas fechadas podem ser pagas.');
    }

    // REGRA 4: Localizar o lançamento da fatura.
    final lancamento = await lancamentoRepo.buscarPorFaturaId(faturaId);

    if (lancamento == null || lancamento.id == null) {
      throw ArgumentError('Esta fatura não possui lançamento financeiro.');
    }

    // REGRA 5: Conferir a origem do lançamento.
    if (lancamento.origem != 'FATURA') {
      throw ArgumentError('O lançamento não pertence a uma fatura.');
    }

    // REGRA 6: Impedir pagamentos repetidos.
    if (lancamento.status != 'PENDENTE') {
      throw ArgumentError('Esta fatura não possui pagamento pendente.');
    }

    // REGRA 7: Verificar movimentação anterior.
    final existente = await movimentacaoRepo.buscarPorLancamentoId(
      lancamento.id!,
    );

    if (existente != null) {
      throw ArgumentError('Esta fatura já possui um pagamento registrado.');
    }

    // REGRA 8: Validar o valor integral.
    if (lancamento.valorPrevisto <= 0) {
      throw ArgumentError('O valor da fatura deve ser maior que zero.');
    }

    // REGRA 9: Validar a data do pagamento.
    final formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (!formato.hasMatch(dataPagamento)) {
      throw ArgumentError('Informe uma data no formato AAAA-MM-DD.');
    }

    final data = DateTime.tryParse(dataPagamento);

    if (data == null ||
        data.year.toString().padLeft(4, '0') != dataPagamento.substring(0, 4) ||
        data.month.toString().padLeft(2, '0') !=
            dataPagamento.substring(5, 7) ||
        data.day.toString().padLeft(2, '0') != dataPagamento.substring(8, 10)) {
      throw ArgumentError('A data do pagamento é inválida.');
    }

    // REGRA 10: Validar a forma de pagamento.
    forma = forma.trim().toUpperCase();

    const formasValidas = {
      'PIX',
      'DINHEIRO',
      'DEBITO',
      'TRANSFERENCIA',
      'BOLETO',
      'OUTRO',
    };

    if (!formasValidas.contains(forma)) {
      throw ArgumentError('Forma de pagamento inválida.');
    }

    // REGRA 11: Registrar o pagamento integral
    // utilizando a transação exclusiva de faturas.
    return movimentacaoRepo.pagarFaturaAtomicamente(
      faturaId: faturaId,
      dataPagamento: dataPagamento,
      forma: forma,
      observacao: observacao,
    );
  }
}
