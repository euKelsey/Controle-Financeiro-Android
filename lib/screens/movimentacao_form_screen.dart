import 'package:flutter/material.dart';
import '../models/lancamento_model.dart';
import '../services/movimentacao_service.dart';

class MovimentacaoFormScreen extends StatefulWidget {
  final LancamentoModel lancamento;
  final MovimentacaoService service;
  const MovimentacaoFormScreen({super.key, required this.lancamento, required this.service});

  @override
  State<MovimentacaoFormScreen> createState() => _MovimentacaoFormScreenState();
}

class _MovimentacaoFormScreenState extends State<MovimentacaoFormScreen> {
  final _observacao = TextEditingController();
  DateTime _data = DateTime.now();
  String _forma = 'PIX';
  bool _salvando = false;
  bool get _receita => widget.lancamento.tipo == 'RECEITA';

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _escolherData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(1900),
      lastDate: DateTime(9999, 12, 31),
    );
    if (data != null && mounted) setState(() => _data = data);
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      await widget.service.cadastrarMovimentacao(
        lancamentoId: widget.lancamento.id!,
        valor: widget.lancamento.valorPrevisto,
        dataMovimentacao: _iso(_data),
        forma: _forma,
        observacao: _observacao.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível registrar: $erro')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  void dispose() {
    _observacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valor = widget.lancamento.valorPrevisto;
    final moeda = 'R\$ ${valor ~/ 100},${(valor % 100).toString().padLeft(2, '0')}';
    final data = _iso(_data).split('-').reversed.join('/');
    return Scaffold(
      appBar: AppBar(title: Text(_receita ? 'Registrar recebimento' : 'Registrar pagamento')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.lancamento.descricao, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('Valor integral: $moeda'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _salvando ? null : _escolherData,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text('Data: $data'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _forma,
            decoration: const InputDecoration(labelText: 'Forma'),
            items: const [
              DropdownMenuItem(value: 'PIX', child: Text('PIX')),
              DropdownMenuItem(value: 'DINHEIRO', child: Text('Dinheiro')),
              DropdownMenuItem(value: 'DEBITO', child: Text('Débito')),
              DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferência')),
              DropdownMenuItem(value: 'BOLETO', child: Text('Boleto')),
              DropdownMenuItem(value: 'OUTRO', child: Text('Outro')),
            ],
            onChanged: _salvando ? null : (v) {
              if (v != null) setState(() => _forma = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _observacao,
            enabled: !_salvando,
            decoration: const InputDecoration(labelText: 'Observação (opcional)'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _salvando ? null : _salvar,
            child: Text(_salvando ? 'Registrando...' : 'Confirmar movimentação'),
          ),
        ],
      ),
    );
  }
}
