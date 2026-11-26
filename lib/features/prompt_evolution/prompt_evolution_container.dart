import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'application/prompt_evolution_controller.dart';
import 'data/supabase_prompt_evolution_repository.dart';
import 'domain/prompt_evolution_models.dart';
import 'presentation/prompt_evolution_view.dart';

class PromptEvolutionContainer extends StatefulWidget {
  const PromptEvolutionContainer({
    super.key,
    this.repository,
  });

  final PromptEvolutionRepository? repository;

  @override
  State<PromptEvolutionContainer> createState() =>
      _PromptEvolutionContainerState();
}

class _PromptEvolutionContainerState extends State<PromptEvolutionContainer> {
  late final PromptEvolutionController _controller;

  @override
  void initState() {
    super.initState();
    final PromptEvolutionRepository repo = widget.repository ??
        SupabasePromptEvolutionRepository(Supabase.instance.client);
    _controller = PromptEvolutionController(repository: repo);
    _controller.loadRecentEvaluations();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PromptEvolutionView(controller: _controller);
  }
}
