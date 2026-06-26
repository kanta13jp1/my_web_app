import 'package:flutter/material.dart';

import 'legal_document_page.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key, this.showBackButton = true});

  static const assetPath = 'assets/legal/terms.md';

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      assetPath: assetPath,
      title: 'Terms',
      subtitle: 'Jibun K.K. / Terms of Service',
      showBackButton: showBackButton,
    );
  }
}
