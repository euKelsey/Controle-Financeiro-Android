import 'package:flutter/material.dart';
import '../services/dashboard_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';

typedef ResumoMes = ({int receitas, int despesas, int saldoPrevisto});

class DashboardAnualView extends StatefulWidget {
  final DashboardService service;
  final int revisaoDados;
  const DashboardAnualView({super.key, required this.service, required this.revisaoDados});

  @override
  State<DashboardAnualView> createState() => _DashboardAnualViewState();
}

class _DashboardAnualViewState extends State<DashboardAnualView> {
  static const meses = ['Jan','Fev','Mar','Abr','Mai','Jun','Jul','Ago','Set','Out','Nov','Dez'];
  late int _ano;
  late Future<List<ResumoMes>> _consulta;

  @override
  void initState() {
    super.initState();
    _ano = DateTime.now().year;
    _consulta = widget.service.obterResumoAnual(ano: _ano);
  }

  @override
  void didUpdateWidget(covariant DashboardAnualView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revisaoDados != widget.revisaoDados) {
      _consulta = widget.service.obterResumoAnual(ano: _ano);
    }
  }

  Future<void> _atualizar() async {
    setState(() { _consulta = widget.service.obterResumoAnual(ano: _ano); });
    try { await _consulta; } catch (_) { /* FutureBuilder mostra o erro. */ }
  }

  void _mudarAno(int ano) {
    if (ano < 1 || ano > 9998) return;
    setState(() {
      _ano = ano;
      _consulta = widget.service.obterResumoAnual(ano: _ano);
    });
  }

  String _moeda(int centavos) {
    final v = centavos.abs();
    final reais = (v ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return '${centavos < 0 ? '-' : ''}R\$ $reais,${(v % 100).toString().padLeft(2, '0')}';
  }

  Color _corSaldo(int valor) => valor == 0
      ? Theme.of(context).colorScheme.onSurface
      : valor < 0 ? AppTheme.corDespesa(context) : AppTheme.corReceita(context);

  Widget _valor(String titulo, int valor, Color cor, {String? chave}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(titulo, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
        child: Text(_moeda(valor), key: chave == null ? null : ValueKey(chave),
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: cor))),
    ],
  );

  Future<void> _abrirMes(int mes) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('Detalhamento mensal')),
      body: DashboardScreen(service: widget.service, anoInicial: _ano, mesInicial: mes),
    )));
    if (mounted) await _atualizar();
  }

  @override
  Widget build(BuildContext context) {
    final hoje = DateTime.now();
    final cores = Theme.of(context).colorScheme;
    final receita = AppTheme.corReceita(context);
    final despesa = AppTheme.corDespesa(context);
    return RefreshIndicator(
      onRefresh: _atualizar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(child: Text('Visão financeira', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
            IconButton(tooltip: 'Atualizar resumo anual', onPressed: _atualizar, icon: const Icon(Icons.refresh_rounded)),
          ]),
          const SizedBox(height: 12),
          Card(child: Row(children: [
            IconButton(tooltip: 'Ano anterior', onPressed: _ano > 1 ? () => _mudarAno(_ano - 1) : null, icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text('$_ano', key: const ValueKey('ano-selecionado'), textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
            IconButton(tooltip: 'Próximo ano', onPressed: _ano < 9998 ? () => _mudarAno(_ano + 1) : null, icon: const Icon(Icons.chevron_right)),
          ])),
          if (_ano != hoje.year)
            TextButton(onPressed: () => _mudarAno(hoje.year), child: const Text('Voltar ao ano atual')),
          const SizedBox(height: 12),
          FutureBuilder<List<ResumoMes>>(future: _consulta, builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
            }
            if (snapshot.hasError || snapshot.data == null || snapshot.data!.length != 12) {
              return Column(children: [
                const Text('Não foi possível carregar o resumo anual.'),
                TextButton(onPressed: _atualizar, child: const Text('Tentar novamente')),
              ]);
            }
            final dados = snapshot.data!;
            final r = dados.fold<int>(0, (s, m) => s + m.receitas);
            final d = dados.fold<int>(0, (s, m) => s + m.despesas);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saldo previsto anual'),
                  const SizedBox(height: 8),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                    child: Text(_moeda(r-d), key: const ValueKey('saldo-anual'),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: _corSaldo(r-d), fontWeight: FontWeight.bold))),
                  const Divider(height: 26),
                  Row(children: [
                    Expanded(child: _valor('Receitas anuais', r, receita, chave: 'receitas-anuais')),
                    const SizedBox(width: 12),
                    Expanded(child: _valor('Despesas anuais', d, despesa, chave: 'despesas-anuais')),
                  ]),
                ],
              ))),
              const SizedBox(height: 14),
              Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Evolução financeira', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.square, size: 12, color: receita), const SizedBox(width: 4), const Text('Receitas'),
                    const SizedBox(width: 18), Icon(Icons.square, size: 12, color: despesa), const SizedBox(width: 4), const Text('Despesas'),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(height: 150, width: double.infinity, child: CustomPaint(
                    painter: _GraficoAnual(dados, receita, despesa, cores.onSurfaceVariant, cores.outlineVariant),
                  )),
                ],
              ))),
              const SizedBox(height: 18),
              Text('Resumo por mês', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, c) {
                final colunas = c.maxWidth < 280 ? 2 : 3;
                final largura = (c.maxWidth - (colunas - 1)*8)/colunas;
                return Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < 12; i++)
                    SizedBox(width: largura, child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
                        side: _ano == hoje.year && i+1 == hoje.month
                          ? BorderSide(color: cores.primary, width: 2) : BorderSide.none),
                      child: InkWell(
                        key: ValueKey('mes-${i+1}'),
                        borderRadius: BorderRadius.circular(14), onTap: () => _abrirMes(i+1),
                        child: Padding(padding: const EdgeInsets.all(10), child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Expanded(child: Text(meses[i])), const Icon(Icons.chevron_right, size: 16)]),
                            if (_ano == hoje.year && i+1 == hoje.month)
                              const Text('Atual', style: TextStyle(fontSize: 10)),
                            const SizedBox(height: 6),
                            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                              child: Text(_moeda(dados[i].saldoPrevisto),
                                style: TextStyle(fontWeight: FontWeight.bold, color: _corSaldo(dados[i].saldoPrevisto)))),
                          ],
                        )),
                      ),
                    )),
                ]);
              }),
              const SizedBox(height: 12),
              const Text('Toque em um mês para abrir os detalhes.'),
            ]);
          }),
        ],
      ),
    );
  }
}

class _GraficoAnual extends CustomPainter {
  final List<ResumoMes> dados;
  final Color receita, despesa, texto, linha;
  _GraficoAnual(this.dados, this.receita, this.despesa, this.texto, this.linha);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 40 || size.height < 40) return;
    final maximo = dados.fold<int>(0, (m, v) {
      final maior = v.receitas > v.despesas ? v.receitas : v.despesas;
      return maior > m ? maior : m;
    });
    final escala = maximo == 0 ? 1 : maximo;
    final base = size.height - 22;
    final altura = base - 10;
    final passo = size.width / 12;
    final w = passo * .30;
    final paint = Paint();
    for (var i = 0; i <= 4; i++) {
      final y = base - altura*i/4;
      canvas.drawLine(Offset(0,y), Offset(size.width,y), paint..color = linha..strokeWidth = 1);
    }
    for (var i=0; i<12; i++) {
      final x = i*passo + passo*.15;
      final hr = dados[i].receitas/escala*altura;
      final hd = dados[i].despesas/escala*altura;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,base-hr,w,hr),const Radius.circular(2)),paint..color=receita);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x+w+2,base-hd,w,hd),const Radius.circular(2)),paint..color=despesa);
      final tp = TextPainter(text: TextSpan(text: _DashboardAnualViewState.meses[i],
        style: TextStyle(fontSize: 9,color:texto)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas,Offset(i*passo+(passo-tp.width)/2,base+6));
    }
  }

  @override
  bool shouldRepaint(covariant _GraficoAnual oldDelegate) =>
      oldDelegate.dados != dados || oldDelegate.receita != receita ||
      oldDelegate.despesa != despesa || oldDelegate.texto != texto || oldDelegate.linha != linha;
}
