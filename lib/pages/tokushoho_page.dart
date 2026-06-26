import 'package:flutter/material.dart';

import 'legal_document_page.dart';

class TokushohoPage extends StatelessWidget {
  const TokushohoPage({super.key, this.showBackButton = true});

  static const assetPath = 'assets/legal/tokushoho.md';

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      assetPath: assetPath,
      title: 'Commercial Disclosure',
      subtitle: 'Specified Commercial Transactions Act',
      showBackButton: showBackButton,
    );
  }
}
