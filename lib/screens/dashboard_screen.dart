import 'package:flutter/material.dart';

import '../repositories/lancamento_repository.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';
import '../models/lancamento_model.dart';

class DashboardScreen extends StatefulWidget {
  final DashboardService? service;

  const DashboardScreen({super.key, this.service});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardService _service;

  late Future<({int receitas, int despesas, int saldoPrevisto})> _resumo;

  // Armazena a consulta dos proximos vencimentos.
  late Future<List<LancamentoModel>> _vencimentos;

  // Periodo selecionado no Dashboard.
  late int _anoSelecionado;
  late int _mesSelecionado;

  // Nomes utilizados no seletor.
  static const List<String> _nomesMeses = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  @override
  void initState() {
    super.initState();

    // Identifica o mes e ano atuais do aparelho.
    final hoje = DateTime.now();

    _anoSelecionado = hoje.year;
    _mesSelecionado = hoje.month;

    // Configura o Service principal ou o de testes.
    _service = widget.service ?? DashboardService(LancamentoRepository());

    // Consulta o periodo inicialmente selecionado.
    _resumo = _consultarPeriodoSelecionado();

    // Carrega os proximos vencimentos a partir de hoje.
    _vencimentos = _service.listarProximosVencimentos();
  }

  // Consulta os valores do periodo selecionado.
  Future<({int receitas, int despesas, int saldoPrevisto})>
  _consultarPeriodoSelecionado() {
    return _service.obterResumoMensal(
      ano: _anoSelecionado,
      mes: _mesSelecionado,
    );
  }

  // Navega para o mes anterior ou seguinte.
  void _mudarMes(int deslocamento) {
    final novoPeriodo = DateTime(
      _anoSelecionado,
      _mesSelecionado + deslocamento,
    );

    // Respeita o intervalo aceito pelo Repository.
    if (novoPeriodo.year < 1 || novoPeriodo.year > 9999) {
      return;
    }

    setState(() {
      _anoSelecionado = novoPeriodo.year;
      _mesSelecionado = novoPeriodo.month;

      // Recarrega os valores do novo periodo.
      _resumo = _consultarPeriodoSelecionado();
    });
  }

  // Retorna ao mes e ano atuais do aparelho.
  void _voltarMesAtual() {
    final hoje = DateTime.now();

    setState(() {
      _anoSelecionado = hoje.year;
      _mesSelecionado = hoje.month;

      // Atualiza os valores do mes atual.
      _resumo = _consultarPeriodoSelecionado();
    });
  }

  // Atualiza o resumo e os proximos vencimentos.
  void _atualizarResumo() {
    setState(() {
      _resumo = _consultarPeriodoSelecionado();

      _vencimentos = _service.listarProximosVencimentos();
    });
  }

  // Atualiza os dados ao puxar a tela para baixo.
  Future<void> _atualizarPorGesto() async {
    final novaConsulta = _consultarPeriodoSelecionado();

    final novosVencimentos = _service.listarProximosVencimentos();

    setState(() {
      _resumo = novaConsulta;
      _vencimentos = novosVencimentos;
    });

    try {
      // Aguarda as duas consultas terminarem.
      await Future.wait([novaConsulta, novosVencimentos]);
    } catch (erro) {
      // Cada FutureBuilder apresentara seu erro.
      debugPrint('Erro ao atualizar Dashboard: $erro');
    }
  }

  // Converte centavos para o formato monetario brasileiro.
  String _formatarMoeda(int centavos) {
    final negativo = centavos < 0;
    final valor = centavos.abs();

    final reais = (valor ~/ 100).toString();
    final centavosTexto = (valor % 100).toString().padLeft(2, '0');

    final reaisFormatados = reais.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );

    final sinal = negativo ? '-' : '';

    return '$sinal'
        'R\$ $reaisFormatados,$centavosTexto';
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    // Verifica se o periodo selecionado e o atual.
    final hoje = DateTime.now();

    final ehMesAtual =
        _anoSelecionado == hoje.year && _mesSelecionado == hoje.month;

    return RefreshIndicator(
      onRefresh: _atualizarPorGesto,
      color: Theme.of(context).colorScheme.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Cabecalho.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VISÃO FINANCEIRA',
                    style: textos.labelSmall?.copyWith(
                      color: cores.onSurfaceVariant,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Resumo do mês',
                    style: textos.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              IconButton(
                onPressed: _atualizarResumo,
                tooltip: 'Atualizar resumo financeiro',
                icon: Icon(
                  Icons.refresh_rounded,
                  color: cores.onSurfaceVariant,
                  size: 28,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Seletor de mes e ano.
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Mês anterior',
                    onPressed: () => _mudarMes(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),

                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${_nomesMeses[_mesSelecionado - 1]} '
                          'de $_anoSelecionado',
                          textAlign: TextAlign.center,
                          style: textos.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Período selecionado',
                          style: textos.bodySmall?.copyWith(
                            color: cores.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    tooltip: 'Próximo mês',
                    onPressed: () => _mudarMes(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Exibe o retorno rapido apenas quando
          // outro mes estiver selecionado.
          if (!ehMesAtual)
            Center(
              child: TextButton.icon(
                onPressed: _voltarMesAtual,
                icon: const Icon(Icons.today_outlined, size: 20),
                label: const Text('Voltar ao mês atual'),
              ),
            ),

          // Dados reais consultados pelo DashboardService.
          FutureBuilder<({int receitas, int despesas, int saldoPrevisto})>(
            future: _resumo,
            builder: (context, snapshot) {
              // Enquanto a consulta estiver em andamento.
              if (snapshot.connectionState != ConnectionState.done) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              // Quando ocorrer um erro na consulta.
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppTheme.corAlerta(context),
                          size: 32,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Não foi possível carregar o resumo.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _atualizarResumo,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final resumo = snapshot.data;

              if (resumo == null) {
                return const Center(child: Text('Resumo indisponível.'));
              }

              final corSaldo = resumo.saldoPrevisto < 0
                  ? AppTheme.corDespesa(context)
                  : cores.onSurface;

              return Column(
                children: [
                  // Cartao principal do saldo.
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo previsto do mês',
                            style: textos.bodyMedium?.copyWith(
                              color: cores.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _formatarMoeda(resumo.saldoPrevisto),
                              style: textos.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: corSaldo,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Divider(color: Theme.of(context).dividerColor),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 18,
                                color: cores.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Resumo financeiro mensal',
                                style: textos.bodySmall?.copyWith(
                                  color: cores.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Receitas e despesas.
                  Row(
                    children: [
                      Expanded(
                        child: _cartaoFinanceiro(
                          context,
                          titulo: 'Receitas',
                          icone: Icons.south_west_rounded,
                          cor: AppTheme.corReceita(context),
                          valor: resumo.receitas,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _cartaoFinanceiro(
                          context,
                          titulo: 'Despesas',
                          icone: Icons.north_east_rounded,
                          cor: AppTheme.corDespesa(context),
                          valor: resumo.despesas,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          _tituloSecao(
            context,
            titulo: 'Próximos vencimentos',
            icone: Icons.event_outlined,
          ),

          const SizedBox(height: 12),

          FutureBuilder<List<LancamentoModel>>(
            future: _vencimentos,
            builder: (context, snapshot) {
              // Enquanto consulta o SQLite.
              if (snapshot.connectionState != ConnectionState.done) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              // Caso ocorra algum erro.
              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppTheme.corAlerta(context),
                          size: 30,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Não foi possível carregar os vencimentos.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _atualizarResumo,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final vencimentos = snapshot.data ?? [];

              // Nenhum vencimento pendente encontrado.
              if (vencimentos.isEmpty) {
                return _cartaoVazio(
                  context,
                  icone: Icons.event_available_outlined,
                  mensagem: 'Nenhum vencimento futuro pendente.',
                );
              }

              // Apresenta os lancamentos encontrados.
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (var i = 0; i < vencimentos.length; i++) ...[
                        if (i > 0) ...[
                          const SizedBox(height: 14),
                          const Divider(),
                          const SizedBox(height: 14),
                        ],
                        _itemVencimento(context, vencimentos[i]),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          _tituloSecao(
            context,
            titulo: 'Faturas de cartões',
            icone: Icons.credit_card_outlined,
          ),

          const SizedBox(height: 12),

          _cartaoVazio(
            context,
            icone: Icons.credit_card_outlined,
            mensagem: 'Suas faturas aparecerão aqui.',
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Exibe um lancamento pendente na lista de vencimentos.
  Widget _itemVencimento(BuildContext context, LancamentoModel lancamento) {
    final cores = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;

    // Define a cor conforme o tipo do lancamento.
    final ehReceita = lancamento.tipo == 'RECEITA';

    final cor = ehReceita
        ? AppTheme.corReceita(context)
        : AppTheme.corDespesa(context);

    // Converte AAAA-MM-DD para DD/MM/AAAA.
    final partes = lancamento.dataPrevista.split('-');

    final dataFormatada = '${partes[2]}/${partes[1]}/${partes[0]}';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            ehReceita ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: cor,
            size: 22,
          ),
        ),

        const SizedBox(width: 12),

        // Descricao e data.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lancamento.descricao,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Vence em $dataFormatada',
                style: textos.bodySmall?.copyWith(
                  color: cores.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Valor e status.
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatarMoeda(lancamento.valorPrevisto),
              style: textos.bodyMedium?.copyWith(
                color: cor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pendente',
              style: textos.labelSmall?.copyWith(
                color: AppTheme.corAlerta(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cartaoFinanceiro(
    BuildContext context, {
    required String titulo,
    required IconData icone,
    required Color cor,
    required int valor,
  }) {
    final textos = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icone, color: cor, size: 22),
            ),
            const SizedBox(height: 16),
            Text(titulo, style: textos.bodyMedium),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _formatarMoeda(valor),
                style: textos.titleLarge?.copyWith(
                  color: cor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tituloSecao(
    BuildContext context, {
    required String titulo,
    required IconData icone,
  }) {
    final cores = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            titulo,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Icon(icone, color: cores.onSurfaceVariant),
      ],
    );
  }

  Widget _cartaoVazio(
    BuildContext context, {
    required IconData icone,
    required String mensagem,
  }) {
    final cores = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(icone, size: 32, color: cores.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: cores.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
