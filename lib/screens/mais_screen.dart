import 'package:flutter/material.dart';
import '../repositories/categoria_repository.dart';
import '../services/categoria_service.dart';
import 'categorias_screen.dart';

class MaisScreen extends StatelessWidget {
  const MaisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Mais', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categorias'),
            subtitle: const Text('Gerenciar receitas e despesas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => CategoriasScreen(
                service: CategoriaService(CategoriaRepository()),
              )),
            ),
          ),
        ),
      ],
    );
  }
}
