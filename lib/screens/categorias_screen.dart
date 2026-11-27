import 'package:flutter/material.dart';
import '../models/categoria_model.dart';
import '../services/categoria_service.dart';

class CategoriasScreen extends StatefulWidget {
  final CategoriaService service;
  const CategoriasScreen({super.key, required this.service});

  @override
  State<CategoriasScreen> createState() => _CategoriasScreenState();
}

class _CategoriasScreenState extends State<CategoriasScreen> {
  late Future<List<CategoriaModel>> _categorias;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _categorias = widget.service.listarCategorias();
  }

  void _atualizar() {
    final consulta = widget.service.listarCategorias();
    setState(() {
      _categorias = consulta;
    });
  }

  Future<void> _editar([CategoriaModel? categoria]) async {
    if (_ocupado) return;
    final alterado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _CategoriaForm(
        service: widget.service, categoria: categoria,
      )),
    );
    if (alterado == true && mounted) _atualizar();
  }

  Future<void> _status(CategoriaModel categoria) async {
    if (_ocupado) return;
    final inativar = categoria.status == 'ATIVA';
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(inativar ? 'Inativar categoria?' : 'Reativar categoria?'),
        content: Text(inativar
            ? 'A categoria ficará indisponível para novos registros. O histórico será preservado.'
            : 'A categoria voltará a estar disponível nos formulários.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmado != true || !mounted || _ocupado) return;
    setState(() => _ocupado = true);
    try {
      if (inativar) {
        await widget.service.inativarCategoria(categoria.id!);
      } else {
        await widget.service.atualizarCategoria(
          categoriaId: categoria.id!, nome: categoria.nome,
          tipo: categoria.tipo, descricao: categoria.descricao, status: 'ATIVA',
        );
      }
      if (mounted) _atualizar();
    } catch (erro) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível alterar a categoria: $erro')),
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categorias'), actions: [
        IconButton(
          tooltip: 'Nova categoria',
          onPressed: _ocupado ? null : () => _editar(),
          icon: const Icon(Icons.add_circle_outline),
        ),
        IconButton(
          tooltip: 'Atualizar categorias',
          onPressed: _atualizar,
          icon: const Icon(Icons.refresh),
        ),
      ]),
      body: FutureBuilder<List<CategoriaModel>>(
        future: _categorias,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Não foi possível consultar categorias.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lista = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              _atualizar();
              try { await _categorias; } catch (_) { /* FutureBuilder exibe o erro. */ }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (lista.isEmpty) const Text('Nenhuma categoria cadastrada.'),
                for (final tipo in ['RECEITA', 'DESPESA']) ...[
                  Text(tipo == 'RECEITA' ? 'Receitas' : 'Despesas',
                    style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final c in lista.where((c) => c.tipo == tipo))
                    Card(child: ListTile(
                      title: Text(c.nome),
                      subtitle: Text(c.status == 'ATIVA' ? 'Ativa' : 'Inativa'),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Ações de ${c.nome}',
                        enabled: !_ocupado,
                        onSelected: (acao) {
                          if (acao == 'editar') {
                            _editar(c);
                          } else if (acao == 'status') {
                            _status(c);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'editar', child: Text('Editar categoria')),
                          PopupMenuItem(value: 'status', child: Text(
                            c.status == 'ATIVA' ? 'Inativar categoria' : 'Reativar categoria',
                          )),
                        ],
                      ),
                    )),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoriaForm extends StatefulWidget {
  final CategoriaService service;
  final CategoriaModel? categoria;
  const _CategoriaForm({required this.service, this.categoria});

  @override
  State<_CategoriaForm> createState() => _CategoriaFormState();
}

class _CategoriaFormState extends State<_CategoriaForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _descricao;
  late String _tipo;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.categoria?.nome ?? '');
    _descricao = TextEditingController(text: widget.categoria?.descricao ?? '');
    _tipo = widget.categoria?.tipo ?? 'DESPESA';
  }

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final atual = widget.categoria;
      if (atual == null) {
        await widget.service.cadastrarCategoria(
          nome: _nome.text, tipo: _tipo, descricao: _descricao.text.trim(),
        );
      } else {
        await widget.service.atualizarCategoria(
          categoriaId: atual.id!, nome: _nome.text, tipo: atual.tipo,
          descricao: _descricao.text.trim(), status: atual.status,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (erro) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $erro')),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.categoria != null;
    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar categoria' : 'Nova categoria')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'DESPESA', child: Text('Despesa')),
                DropdownMenuItem(value: 'RECEITA', child: Text('Receita')),
              ],
              onChanged: editando || _salvando ? null : (v) {
                if (v != null) setState(() => _tipo = v);
              },
            ),
            if (editando) const Text('O tipo é preservado para proteger o histórico.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nome,
              enabled: !_salvando,
              decoration: const InputDecoration(labelText: 'Nome da categoria'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descricao,
              enabled: !_salvando,
              decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _salvando ? null : _salvar,
              child: Text(_salvando ? 'Salvando...' : 'Salvar categoria'),
            ),
          ],
        ),
      ),
    );
  }
}
