import '../models/lancamento_model.dart';
import '../repositories/lancamento_repository.dart';
import '../repositories/categoria_repository.dart';

class LancamentoService {
  final LancamentoRepository _repository;
  final CategoriaRepository _categoriaRepository;

  LancamentoService(
    this._repository, {
    CategoriaRepository? categoriaRepository,
  }) : _categoriaRepository = categoriaRepository ?? CategoriaRepository();

  // Verifica se a data é real e está no formato AAAA-MM-DD.
  void _validarDataPrevista(String data) {
    final formato = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (!formato.hasMatch(data)) {
      throw ArgumentError('A data prevista deve estar no formato AAAA-MM-DD.');
    }

    final dataConvertida = DateTime.tryParse(data);

    if (dataConvertida == null ||
        dataConvertida.year.toString().padLeft(4, '0') !=
            data.substring(0, 4) ||
        dataConvertida.month.toString().padLeft(2, '0') !=
            data.substring(5, 7) ||
        dataConvertida.day.toString().padLeft(2, '0') !=
            data.substring(8, 10)) {
      throw ArgumentError('A data prevista é inválida.');
    }
  }

  // Verifica se a categoria pode ser utilizada no lançamento.
  Future<void> _validarCategoria({
    required int? categoriaId,
    required String tipo,
    int? categoriaAnteriorId,
  }) async {
    if (categoriaId == null) {
      throw ArgumentError('A categoria é obrigatória.');
    }

    final categoria = await _categoriaRepository.buscarPorId(categoriaId);

    if (categoria == null) {
      throw ArgumentError('Categoria não encontrada.');
    }

    if (categoria.tipo != tipo) {
      throw ArgumentError(
        'O tipo da categoria deve corresponder ao tipo do lançamento.',
      );
    }

    // Uma categoria inativa pode ser mantida em
    // um lançamento existente, mas não selecionada
    // para um novo lançamento.
    if (categoria.status != 'ATIVA' && categoriaId != categoriaAnteriorId) {
      throw ArgumentError('Não é permitido utilizar uma categoria inativa.');
    }
  }

  // Valida e cadastra um lançamento manual.
  Future<LancamentoModel> cadastrarLancamento({
    required String tipo,
    required String descricao,
    required int valorPrevisto,
    required String dataPrevista,
    required int? categoriaId,
    String? observacao,
  }) async {
    // Padroniza os dados recebidos.
    tipo = tipo.trim().toUpperCase();
    descricao = descricao.trim();

    // REGRA 1: Tipo válido.
    if (tipo != 'RECEITA' && tipo != 'DESPESA') {
      throw ArgumentError('O tipo deve ser RECEITA ou DESPESA.');
    }

    // REGRA 2: Descrição obrigatória.
    if (descricao.isEmpty) {
      throw ArgumentError('A descrição é obrigatória.');
    }

    // REGRA 3: Valor maior que zero.
    if (valorPrevisto <= 0) {
      throw ArgumentError('O valor previsto deve ser maior que zero.');
    }

    // REGRA 4: Categoria válida e compatível.
    await _validarCategoria(categoriaId: categoriaId, tipo: tipo);

    // Cria o lançamento após as validações.
    // REGRA 5: Data prevista válida.
    _validarDataPrevista(dataPrevista);
    final lancamento = LancamentoModel(
      tipo: tipo,
      descricao: descricao,
      valorPrevisto: valorPrevisto,
      dataPrevista: dataPrevista,
      categoriaId: categoriaId,
      observacao: observacao,
      status: 'PENDENTE',
      origem: 'MANUAL',
    );

    // Envia ao Repository para gravar no SQLite.
    return _repository.inserir(lancamento);
  }

  // Lista todos os lançamentos financeiros.
  Future<List<LancamentoModel>> listarLancamentos() async {
    return _repository.listar();
  }

  // Busca um lançamento e verifica se ele existe.
  Future<LancamentoModel> buscarLancamentoPorId(int id) async {
    final lancamento = await _repository.buscarPorId(id);

    if (lancamento == null) {
      throw ArgumentError('Lançamento não encontrado.');
    }

    return lancamento;
  }

  // Valida e atualiza um lançamento existente.
  Future<LancamentoModel> atualizarLancamento({
    required int lancamentoId,
    required String tipo,
    required String descricao,
    required int valorPrevisto,
    required String dataPrevista,
    required int? categoriaId,
    String status = 'PENDENTE',
    String? observacao,
  }) async {
    // Verifica se o lançamento existe.
    final existente = await buscarLancamentoPorId(lancamentoId);

    // Impede edição manual de lançamentos de fatura.
    if (existente.origem == 'FATURA') {
      throw ArgumentError(
        'Lançamentos de faturas não podem ser editados manualmente.',
      );
    }

    // Impede edição de lançamentos já finalizados.
    if (existente.status != 'PENDENTE') {
      throw ArgumentError('Somente lançamentos pendentes podem ser editados.');
    }

    // Padroniza os dados.
    tipo = tipo.trim().toUpperCase();
    descricao = descricao.trim();
    status = status.trim().toUpperCase();

    // REGRA 1: Tipo válido.
    if (tipo != 'RECEITA' && tipo != 'DESPESA') {
      throw ArgumentError('O tipo deve ser RECEITA ou DESPESA.');
    }

    // REGRA 2: Descrição obrigatória.
    if (descricao.isEmpty) {
      throw ArgumentError('A descrição é obrigatória.');
    }

    // REGRA 3: Valor maior que zero.
    if (valorPrevisto <= 0) {
      throw ArgumentError('O valor previsto deve ser maior que zero.');
    }

    // REGRA 4: Categoria válida e compatível.
    await _validarCategoria(
      categoriaId: categoriaId,
      tipo: tipo,
      categoriaAnteriorId: existente.categoriaId,
    );

    // REGRA 5: Status permitido.
    if (status != 'PENDENTE' &&
        status != 'EFETIVADO' &&
        status != 'CANCELADO') {
      throw ArgumentError(
        'O status deve ser PENDENTE, EFETIVADO ou CANCELADO.',
      );
    }

    // O status financeiro não pode ser alterado
    // diretamente pela edição do lançamento.
    if (status != 'PENDENTE') {
      throw ArgumentError(
        'O status não pode ser alterado manualmente. '
        'Utilize a operação financeira correspondente.',
      );
    }

    // REGRA 6: Data prevista válida.
    _validarDataPrevista(dataPrevista);

    // Reconstrói o Model com os novos dados.
    final atualizado = LancamentoModel(
      id: existente.id,
      tipo: tipo,
      descricao: descricao,
      valorPrevisto: valorPrevisto,
      dataPrevista: dataPrevista,
      categoriaId: categoriaId,
      recorrenciaId: existente.recorrenciaId,
      faturaId: existente.faturaId,
      status: status,
      observacao: observacao,
      origem: existente.origem,
    );

    final linhas = await _repository.atualizar(atualizado);

    if (linhas == 0) {
      throw StateError('Não foi possível atualizar o lançamento.');
    }

    return atualizado;
  }

  // Cancela um lançamento sem excluir seu registro.
  Future<LancamentoModel> cancelarLancamento(int lancamentoId) async {
    final existente = await buscarLancamentoPorId(lancamentoId);

    // Faturas possuem um fluxo próprio de gerenciamento.
    if (existente.origem == 'FATURA') {
      throw ArgumentError(
        'Lançamentos de faturas não podem ser cancelados manualmente.',
      );
    }

    // Apenas lançamentos pendentes podem ser cancelados.
    if (existente.status != 'PENDENTE') {
      throw ArgumentError(
        'Somente lançamentos pendentes podem ser cancelados.',
      );
    }

    final linhas = await _repository.cancelar(lancamentoId);

    if (linhas == 0) {
      throw StateError('Não foi possível cancelar o lançamento.');
    }

    return buscarLancamentoPorId(lancamentoId);
  }
}
