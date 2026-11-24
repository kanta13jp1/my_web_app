import 'package:flutter/material.dart';

import 'application/feature_architecture_controller.dart';
import 'presentation/feature_architecture_view.dart';

/// Controller と Presentation View を接続し、ライフサイクルを管理する Container (#2603)。
class FeatureArchitectureContainer extends StatefulWidget {
  const FeatureArchitectureContainer({
    super.key,
    this.controller,
  });

  final FeatureArchitectureController? controller;

  @override
  State<FeatureArchitectureContainer> createState() =>
      _FeatureArchitectureContainerState();
}

class _FeatureArchitectureContainerState
    extends State<FeatureArchitectureContainer> {
  late FeatureArchitectureController _controller;
  late bool _ownsController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provided = widget.controller;
    _ownsController = provided == null;
    _controller = provided ?? FeatureArchitectureController();
    _searchController.text = _controller.state.searchQuery;
  }

  @override
  void didUpdateWidget(covariant FeatureArchitectureContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.dispose();
      }
      final provided = widget.controller;
      _ownsController = provided == null;
      _controller = provided ?? FeatureArchitectureController();
      _searchController.text = _controller.state.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handleReset() {
    _searchController.clear();
    _controller.resetDefaults();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return FeatureArchitectureView(
          state: _controller.state,
          searchController: _searchController,
          onSelectFilter: _controller.selectFilter,
          onSelectRule: _controller.selectRule,
          onToggleChecklist: _controller.toggleChecklistItem,
          onSearchChanged: _controller.setSearchQuery,
          onReset: _handleReset,
        );
      },
    );
  }
}
