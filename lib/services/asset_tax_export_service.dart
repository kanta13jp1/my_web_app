enum AssetTaxRecordKind { income, expense, deduction }

enum AssetTaxRecordCategory {
  miscIncome,
  businessIncome,
  realEstateIncome,
  businessExpense,
  realEstateExpense,
  furusatoTaxDonation,
}

class AssetTaxRecord {
  final String id;
  final DateTime occurredOn;
  final AssetTaxRecordKind kind;
  final AssetTaxRecordCategory category;
  final double amount;
  final String title;
  final String counterparty;
  final String invoiceNumber;
  final double? taxRate;
  final String memo;
  final String source;

  const AssetTaxRecord({
    required this.id,
    required this.occurredOn,
    required this.kind,
    required this.category,
    required this.amount,
    required this.title,
    this.counterparty = '',
    this.invoiceNumber = '',
    this.taxRate,
    this.memo = '',
    this.source = '',
  });
}

class AssetTaxExportConfirmation {
  final String title;
  final List<String> summaryLines;
  final List<String> warnings;

  const AssetTaxExportConfirmation({
    required this.title,
    required this.summaryLines,
    required this.warnings,
  });

  bool get requiresReview => warnings.isNotEmpty;
}

class AssetTaxExportPreview {
  final int taxYear;
  final DateTime generatedAt;
  final List<AssetTaxRecord> records;
  final Map<AssetTaxRecordCategory, double> totalsByCategory;
  final double totalIncome;
  final double totalExpense;
  final double totalDeduction;
  final double netBeforeSpecialRules;
  final int ignoredRecordCount;
  final List<String> warnings;
  final AssetTaxExportConfirmation confirmation;

  const AssetTaxExportPreview({
    required this.taxYear,
    required this.generatedAt,
    required this.records,
    required this.totalsByCategory,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalDeduction,
    required this.netBeforeSpecialRules,
    required this.ignoredRecordCount,
    required this.warnings,
    required this.confirmation,
  });

  bool get hasRecords => records.isNotEmpty;
}

class AssetTaxExportBundle {
  final AssetTaxExportPreview preview;
  final String csv;
  final String eTaxXmlSkeleton;

  const AssetTaxExportBundle({
    required this.preview,
    required this.csv,
    required this.eTaxXmlSkeleton,
  });
}

class AssetTaxExportService {
  const AssetTaxExportService();

  AssetTaxExportBundle buildExportBundle({
    required int taxYear,
    required List<AssetTaxRecord> records,
    DateTime? generatedAt,
  }) {
    final preview = buildPreview(
      taxYear: taxYear,
      records: records,
      generatedAt: generatedAt,
    );
    return AssetTaxExportBundle(
      preview: preview,
      csv: buildCsv(preview),
      eTaxXmlSkeleton: buildETaxXmlSkeleton(preview),
    );
  }

  AssetTaxExportPreview buildPreview({
    required int taxYear,
    required List<AssetTaxRecord> records,
    DateTime? generatedAt,
  }) {
    final inYear =
        records.where((record) => record.occurredOn.year == taxYear).toList()
          ..sort((a, b) {
            final byDate = a.occurredOn.compareTo(b.occurredOn);
            if (byDate != 0) return byDate;
            return a.id.compareTo(b.id);
          });
    final warnings = <String>[];
    final ignored = records.length - inYear.length;
    if (ignored > 0) {
      warnings.add(
        '$ignored record(s) outside tax year $taxYear were ignored.',
      );
    }
    if (inYear.isEmpty) {
      warnings.add('No tax records are available for tax year $taxYear.');
    }
    for (final record in inYear) {
      if (record.amount == 0) {
        warnings.add('Record ${record.id} has zero amount.');
      }
      if (record.title.trim().isEmpty) {
        warnings.add('Record ${record.id} is missing a title.');
      }
      if (record.category == AssetTaxRecordCategory.furusatoTaxDonation &&
          record.kind != AssetTaxRecordKind.deduction) {
        warnings.add(
          'Record ${record.id} is furusato tax but is not marked as deduction.',
        );
      }
    }

    final totalsByCategory = <AssetTaxRecordCategory, double>{};
    var totalIncome = 0.0;
    var totalExpense = 0.0;
    var totalDeduction = 0.0;
    for (final record in inYear) {
      final amount = record.amount.abs();
      totalsByCategory[record.category] =
          (totalsByCategory[record.category] ?? 0) + amount;
      switch (record.kind) {
        case AssetTaxRecordKind.income:
          totalIncome += amount;
          break;
        case AssetTaxRecordKind.expense:
          totalExpense += amount;
          break;
        case AssetTaxRecordKind.deduction:
          totalDeduction += amount;
          break;
      }
    }
    final netBeforeSpecialRules = totalIncome - totalExpense - totalDeduction;
    final timestamp = generatedAt ?? DateTime.now().toUtc();
    final confirmation = AssetTaxExportConfirmation(
      title: 'Tax export preview for $taxYear',
      summaryLines: <String>[
        'Records: ${inYear.length}',
        'Income total: ${_amount(totalIncome)}',
        'Expense total: ${_amount(totalExpense)}',
        'Deduction total: ${_amount(totalDeduction)}',
        'Net before special rules: ${_amount(netBeforeSpecialRules)}',
      ],
      warnings: List<String>.unmodifiable(warnings),
    );

    return AssetTaxExportPreview(
      taxYear: taxYear,
      generatedAt: timestamp,
      records: List<AssetTaxRecord>.unmodifiable(inYear),
      totalsByCategory: Map<AssetTaxRecordCategory, double>.unmodifiable(
        totalsByCategory,
      ),
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      totalDeduction: totalDeduction,
      netBeforeSpecialRules: netBeforeSpecialRules,
      ignoredRecordCount: ignored,
      warnings: List<String>.unmodifiable(warnings),
      confirmation: confirmation,
    );
  }

  String buildCsv(AssetTaxExportPreview preview) {
    return _csv(<List<Object?>>[
      const <Object?>[
        'tax_year',
        'date',
        'kind',
        'category',
        'category_label',
        'amount',
        'title',
        'counterparty',
        'invoice_number',
        'tax_rate',
        'memo',
        'source',
        'source_record_id',
      ],
      for (final record in preview.records)
        <Object?>[
          preview.taxYear,
          _date(record.occurredOn),
          record.kind.name,
          record.category.name,
          _categoryLabel(record.category),
          _amount(record.amount.abs()),
          record.title,
          record.counterparty,
          record.invoiceNumber,
          record.taxRate ?? '',
          record.memo,
          record.source,
          record.id,
        ],
    ]);
  }

  String buildETaxXmlSkeleton(AssetTaxExportPreview preview) {
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<jibun_tax_export version="0.1" tax_year="${preview.taxYear}" generated_at="${_xml(preview.generatedAt.toUtc().toIso8601String())}">',
      )
      ..writeln(
        '  <notice>This is an e-Tax XML skeleton for review. It is not a final filing document.</notice>',
      )
      ..writeln(
        '  <summary total_income="${_amount(preview.totalIncome)}" total_expense="${_amount(preview.totalExpense)}" total_deduction="${_amount(preview.totalDeduction)}" net_before_special_rules="${_amount(preview.netBeforeSpecialRules)}" />',
      );

    for (final category in AssetTaxRecordCategory.values) {
      final categoryRecords = preview.records
          .where((record) => record.category == category)
          .toList();
      if (categoryRecords.isEmpty) continue;
      buffer.writeln(
        '  <section code="${category.name}" label="${_xml(_categoryLabel(category))}" total="${_amount(preview.totalsByCategory[category] ?? 0)}">',
      );
      for (final record in categoryRecords) {
        buffer
          ..writeln(
            '    <record id="${_xml(record.id)}" date="${_date(record.occurredOn)}" kind="${record.kind.name}" amount="${_amount(record.amount.abs())}">',
          )
          ..writeln('      <title>${_xml(record.title)}</title>');
        if (record.counterparty.trim().isNotEmpty) {
          buffer.writeln(
            '      <counterparty>${_xml(record.counterparty)}</counterparty>',
          );
        }
        if (record.invoiceNumber.trim().isNotEmpty) {
          buffer.writeln(
            '      <invoice_number>${_xml(record.invoiceNumber)}</invoice_number>',
          );
        }
        if (record.taxRate != null) {
          buffer.writeln('      <tax_rate>${record.taxRate}</tax_rate>');
        }
        if (record.memo.trim().isNotEmpty) {
          buffer.writeln('      <memo>${_xml(record.memo)}</memo>');
        }
        buffer.writeln('    </record>');
      }
      buffer.writeln('  </section>');
    }

    if (preview.warnings.isNotEmpty) {
      buffer.writeln('  <warnings>');
      for (final warning in preview.warnings) {
        buffer.writeln('    <warning>${_xml(warning)}</warning>');
      }
      buffer.writeln('  </warnings>');
    }

    buffer.writeln('</jibun_tax_export>');
    return buffer.toString();
  }

  static String _categoryLabel(AssetTaxRecordCategory category) {
    switch (category) {
      case AssetTaxRecordCategory.miscIncome:
        return 'Misc income';
      case AssetTaxRecordCategory.businessIncome:
        return 'Business income';
      case AssetTaxRecordCategory.realEstateIncome:
        return 'Real estate income';
      case AssetTaxRecordCategory.businessExpense:
        return 'Business expense';
      case AssetTaxRecordCategory.realEstateExpense:
        return 'Real estate expense';
      case AssetTaxRecordCategory.furusatoTaxDonation:
        return 'Furusato tax donation';
    }
  }

  static String _csv(List<List<Object?>> rows) {
    return rows
        .map((row) => row.map((cell) => _csvCell(cell)).join(','))
        .join('\n');
  }

  static String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }

  static String _date(DateTime value) {
    final utc = DateTime.utc(value.year, value.month, value.day);
    return utc.toIso8601String().substring(0, 10);
  }

  static String _amount(double value) {
    if (value.isNaN || value.isInfinite) return '0';
    final normalized = value.abs() < 0.000001 ? 0.0 : value;
    return normalized.toStringAsFixed(0);
  }

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
