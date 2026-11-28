import '../repositories/recorrencia_repository.dart';
import 'package:flutter/material.dart';

import '../models/lancamento_model.dart';
import '../repositories/lancamento_repository.dart';
import '../services/lancamento_service.dart';
import '../services/movimentacao_service.dart';
import '../theme/app_theme.dart';
import 'lancamento_form_screen.dart';

class LancamentosScreen extends StatefulWidget {
  final int revisaoDados;
  final LancamentoService? service;
  final MovimentacaoService? movimentacaoService;

  const LancamentosScreen({super.key, this.service, this.movimentacaoService, this.revisaoDados = 0});

  @override
  State<LancamentosScreen> createState() => _LancamentosScreenState();
}

class _LancamentosScreenState extends State<LancamentosScreen> {
  @override
  void didUpdateWidget(covariant LancamentosScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revisaoDados != widget.revisaoDados) {
      _atualizar();
    }
  }

  late final LancamentoService _service;
  late Future<List<LancamentoModel>> _lancamentos;
  late int _ano;
  late int _mes;
  String? _tipo;
  String? _status;
  int _limite = 100;

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    final hoje = DateTime.now();
    _ano = hoje.year;
    _mes = hoje.month;
    _service = widget.service ?? LancamentoService(LancamentoRepository(), recorrencias: RecorrenciaRepository());
    _recarregarSemSetState();
  }

  void _recarregarSemSetState() {
    _lancamentos = _service.listarPorPeriodo(
      ano: _ano,
      mes: _mes,
      tipo: _tipo,
      status: _status,
      limite: _limite,
    );
  }

  void _atualizar() {
    setState(_recarregarSemSetState);
  }

  Future<void> _atualizarPorGesto() async {
    setState(_recarregarSemSetState);
    try {
      await _lancamentos;
    } catch (_) {
      // O FutureBuilder exibe o estado de erro.
    }
  }

  void _alterarMes(int deslocamento) {
    final proximo = DateTime(_ano, _mes + deslocamento);
    if (proximo.year < 1 || proximo.year > 9999) return;
    setState(() {
      _ano = proximo.year;
      _mes = proximo.month;
      _limite = 100;
      _recarregarSemSetState();
    });
  }

  String _moeda(int centavos) {
    final abs = centavos.abs();
    final inteiros = (abs ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '${centavos < 0 ? '-' : ''}R\$ $inteiros,${(abs % 100).toString().padLeft(2, '0')}';
  }

  String _data(String iso) {
    final partes = iso.split('-');
    return partes.length == 3
        ? '${partes[2]}/${partes[1]}/${partes[0]}'
        : iso;
  }

  String _situacao(String status) {
    switch (status) {
      case 'PENDENTE':
        return 'Pendente';
      case 'EFETIVADO':
        return 'Efetivado';
      case 'CANCELADO':
        return 'Cancelado';
      default:
        return status;
    }
  }

  Future<void> _abrirFormulario([LancamentoModel? lancamento]) async {
    final alterado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LancamentoFormScreen(
          service: _service,
          lancamento: lancamento,
        ),
      ),
    );
    if (alterado == true && mounted) _atualizar();
  }

  Future<void> _cancelarLancamento(LancamentoModel lancamento) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar lançamento?'),
        content: Text(
          'O lançamento "${lancamento.descricao}" será marcado como cancelado. '
          'O histórico será preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar cancelamento'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    try {
      await _service.cancelarLancamento(lancamento.id!, registroDireto: true);
      if (mounted) _atualizar();
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível cancelar: $erro')),
        );
      }
    }
  }

  Future<void> _encerrar(LancamentoModel lancamento) async {
    final confirmar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Encerrar recorrência?'),
      content: const Text('Este mês e os seguintes serão cancelados. Os meses anteriores serão preservados.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Encerrar')),
      ],
    ));
    if (confirmar != true || !mounted) return;
    try {
      await _service.encerrarRecorrencia(lancamento.id!);
      if (mounted) _atualizar();
    } catch (erro) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível encerrar: $erro')));
    }
  }

  Widget _linha(LancamentoModel lancamento) {
    final cores = Theme.of(context).colorScheme;
    final receita = lancamento.tipo == 'RECEITA';
    final cor = receita
        ? AppTheme.corReceita(context)
        : AppTheme.corDespesa(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              receita ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: cor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lancamento.descricao,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_data(lancamento.dataPrevista)} · ${lancamento.origem == 'RECORRENCIA' && lancamento.status == 'PENDENTE' ? 'Previsto' : _situacao(lancamento.status)}',
                    style: TextStyle(color: cores.onSurfaceVariant),
                  ),
                  if (lancamento.origem == 'RECORRENCIA')
                    const Text('Recorrente · mensal'),
                  if (lancamento.origem == 'FATURA')
                    Text(
                      'Fatura de cartão',
                      style: TextStyle(color: cores.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _moeda(lancamento.valorPrevisto),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cor,
                    decoration: lancamento.status == 'CANCELADO'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (lancamento.origem != 'FATURA' &&
                    (lancamento.status == 'PENDENTE' || (lancamento.origem == 'MANUAL' && lancamento.status == 'EFETIVADO')))
                  PopupMenuButton<String>(
                    tooltip: 'Ações de ${lancamento.descricao}',
                    onSelected: (acao) {
                      if (acao == 'editar') {
                        _abrirFormulario(lancamento);
                      } else if (acao == 'encerrar') {
                        _encerrar(lancamento);
                      } else if (acao == 'cancelar') {
                        _cancelarLancamento(lancamento);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'editar', child: Text('Editar')),
                      const PopupMenuItem(value: 'cancelar', child: Text('Cancelar')),
                      if (lancamento.origem == 'RECORRENCIA')
                        const PopupMenuItem(value: 'encerrar', child: Text('Encerrar recorrência')),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final hoje = DateTime.now();
    final mesAtual = hoje.year == _ano && hoje.month == _mes;

    return RefreshIndicator(
      onRefresh: _atualizarPorGesto,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lançamentos',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => _abrirFormulario(),
                tooltip: 'Novo lançamento',
                icon: const Icon(Icons.add_circle_outline),
              ),
              IconButton(
                onPressed: _atualizar,
                tooltip: 'Atualizar lançamentos',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mês anterior',
                  onPressed: () => _alterarMes(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_meses[_mes - 1]} de $_ano',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo mês',
                  onPressed: () => _alterarMes(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          if (!mesAtual)
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _ano = hoje.year;
                    _mes = hoje.month;
                    _limite = 100;
                    _recarregarSemSetState();
                  });
                },
                icon: const Icon(Icons.today_outlined),
                label: const Text('Voltar ao mês atual'),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _tipo ?? 'TODOS',
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'TODOS', child: Text('Todos')),
                    DropdownMenuItem(value: 'RECEITA', child: Text('Receitas')),
                    DropdownMenuItem(value: 'DESPESA', child: Text('Despesas')),
                  ],
                  onChanged: (valor) {
                    setState(() {
                      _tipo = valor == 'TODOS' ? null : valor;
                      _limite = 100;
                      _recarregarSemSetState();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _status ?? 'TODOS',
                  decoration: const InputDecoration(labelText: 'Situação'),
                  items: const [
                    DropdownMenuItem(value: 'TODOS', child: Text('Todas')),
                    DropdownMenuItem(value: 'PENDENTE', child: Text('Pendentes')),
                    DropdownMenuItem(value: 'EFETIVADO', child: Text('Efetivados')),
                    DropdownMenuItem(value: 'CANCELADO', child: Text('Cancelados')),
                  ],
                  onChanged: (valor) {
                    setState(() {
                      _status = valor == 'TODOS' ? null : valor;
                      _limite = 100;
                      _recarregarSemSetState();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<LancamentoModel>>(
            future: _lancamentos,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Column(
                  children: [
                    const Text('Não foi possível carregar os lançamentos.'),
                    TextButton(
                      onPressed: _atualizar,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                );
              }
              final lista = snapshot.data ?? [];
              if (lista.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Nenhum lançamento neste período.',
                      style: TextStyle(color: cores.onSurfaceVariant),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final lancamento in lista) ...[
                    _linha(lancamento),
                    const SizedBox(height: 8),
                  ],
                  if (lista.length == _limite && _limite < 500)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _limite = (_limite + 100).clamp(1, 500);
                          _recarregarSemSetState();
                        });
                      },
                      child: const Text('Carregar mais lançamentos'),
                    ),
                  if (lista.length == 500)
                    Text(
                      'Exibindo até 500 lançamentos. Use os filtros para refinar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cores.onSurfaceVariant),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
