import '../models/movimentacao_model.dart';
import '../repositories/lancamento_repository.dart';
import '../repositories/movimentacao_repository.dart';

class MovimentacaoService {
  final MovimentacaoRepository _repository;
  final LancamentoRepository _lancamentoRepository;

  MovimentacaoService(
    this._repository, {
    required this._lancamentoRepository,
  });

  // Valida uma data no formato AAAA-MM-DD.
  void _validarData(String data) {
    final formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (!formato.hasMatch(data)) {
      throw ArgumentError('A data deve estar no formato AAAA-MM-DD.');
    }

    final convertida = DateTime.tryParse(data);

    if (convertida == null ||
        convertida.year.toString().padLeft(4, '0') != data.substring(0, 4) ||
        convertida.month.toString().padLeft(2, '0') != data.substring(5, 7) ||
        convertida.day.toString().padLeft(2, '0') != data.substring(8, 10)) {
      throw ArgumentError('A data da movimentação é inválida.');
    }
  }

  // Valida e registra um pagamento ou recebimento.
  Future<MovimentacaoModel> cadastrarMovimentacao({
    required int lancamentoId,
    required int valor,
    required String dataMovimentacao,
    required String forma,
    String? observacao,
  }) async {
    forma = forma.trim().toUpperCase();

    // REGRA 1: O lançamento precisa existir.
    final lancamento = await _lancamentoRepository.buscarPorId(lancamentoId);

    if (lancamento == null) {
      throw ArgumentError('Lançamento não encontrado.');
    }

    // REGRA 2: Somente lançamentos pendentes.
    if (lancamento.status != 'PENDENTE') {
      throw ArgumentError(
        'Somente lançamentos pendentes podem ser efetivados.',
      );
    }

    // REGRA 3: Faturas possuem pagamento exclusivo.
    if (lancamento.origem == 'FATURA') {
      throw ArgumentError(
        'Pagamentos de faturas devem utilizar '
        'o serviço exclusivo de faturas.',
      );
    }

    // REGRA 4: Valor positivo.
    if (valor <= 0) {
      throw ArgumentError('O valor da movimentação deve ser maior que zero.');
    }

    // REGRA 5: Pagamento ou recebimento integral.
    if (valor != lancamento.valorPrevisto) {
      throw ArgumentError(
        'O valor da movimentação deve ser igual '
        'ao valor previsto do lançamento.',
      );
    }

    // REGRA 6: Forma de movimentação válida.
    const formasValidas = {
      'PIX',
      'DINHEIRO',
      'DEBITO',
      'TRANSFERENCIA',
      'BOLETO',
      'OUTRO',
    };

    if (!formasValidas.contains(forma)) {
      throw ArgumentError('Forma de movimentação inválida.');
    }

    // REGRA 7: Data válida.
    _validarData(dataMovimentacao);

    // REGRA 8: Impedir movimentação duplicada.
    final existente = await _repository.buscarPorLancamentoId(lancamentoId);

    if (existente != null) {
      throw ArgumentError('Este lançamento já possui uma movimentação.');
    }

    // Cria o Model após todas as validações.
    final movimentacao = MovimentacaoModel(
      lancamentoId: lancamentoId,
      valor: valor,
      dataMovimentacao: dataMovimentacao,
      forma: forma,
      observacao: observacao,
    );

    // Insere e efetiva dentro de uma transação SQLite.
    return _repository.inserirEEfetivar(movimentacao);
  }

  
  // Lista todos os pagamentos e recebimentos.
  Future<List<MovimentacaoModel>> listarMovimentacoes() async {
    return _repository.listar();
  }

  // Busca uma movimentação e verifica se existe.
  Future<MovimentacaoModel> buscarMovimentacaoPorId(
    int movimentacaoId,
  ) async {
    final movimentacao = await _repository.buscarPorId(
      movimentacaoId,
    );

    if (movimentacao == null) {
      throw ArgumentError(
        'Movimentação não encontrada.',
      );
    }

    return movimentacao;
  }

  // Valida e atualiza uma movimentação existente.
  Future<MovimentacaoModel> atualizarMovimentacao({
    required int movimentacaoId,
    required int valor,
    required String dataMovimentacao,
    required String forma,
    String? observacao,
  }) async {
    // REGRA 1: Verificar se a movimentação existe.
    final existente = await buscarMovimentacaoPorId(
      movimentacaoId,
    );

    // REGRA 2: Consultar o lançamento relacionado.
    final lancamento = await _lancamentoRepository.buscarPorId(
      existente.lancamentoId,
    );

    if (lancamento == null) {
      throw ArgumentError(
        'Lançamento associado não encontrado.',
      );
    }

    // REGRA 3: Bloquear alterações em pagamentos de faturas.
    if (lancamento.origem == 'FATURA') {
      throw ArgumentError(
        'Pagamentos de faturas não podem ser alterados '
        'após o registro.',
      );
    }

    // REGRA 4: Conferir o status do lançamento.
    if (lancamento.status != 'EFETIVADO') {
      throw ArgumentError(
        'O lançamento associado não está efetivado.',
      );
    }

    // REGRA 5: Valor positivo.
    if (valor <= 0) {
      throw ArgumentError(
        'O valor da movimentação deve ser maior que zero.',
      );
    }

    // REGRA 6: Preservar o pagamento integral.
    if (valor != lancamento.valorPrevisto) {
      throw ArgumentError(
        'O valor deve ser igual ao valor previsto '
        'do lançamento.',
      );
    }

    // Padroniza a forma de pagamento.
    forma = forma.trim().toUpperCase();

    // REGRA 7: Forma permitida.
    const formasValidas = {
      'PIX',
      'DINHEIRO',
      'DEBITO',
      'TRANSFERENCIA',
      'BOLETO',
      'OUTRO',
    };

    if (!formasValidas.contains(forma)) {
      throw ArgumentError(
        'Forma de movimentação inválida.',
      );
    }

    // REGRA 8: Data válida.
    _validarData(dataMovimentacao);

    // Preserva o ID e o lançamento original.
    final atualizada = MovimentacaoModel(
      id: existente.id,
      lancamentoId: existente.lancamentoId,
      valor: valor,
      dataMovimentacao: dataMovimentacao,
      forma: forma,
      observacao: observacao,
    );

    final linhas = await _repository.atualizar(
      atualizada,
    );

    if (linhas != 1) {
      throw StateError(
        'Não foi possível atualizar a movimentação.',
      );
    }

    return atualizada;
  }

}
