import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Remise du rapport à l'utilisateur (partage, impression, enregistrement).
///
/// Isolée derrière une interface pour deux raisons : les tests n'ont pas à
/// déclencher la feuille de partage du système, et le jour où l'envoi par
/// e-mail s'ajoutera, seul ce fichier changera.
abstract class ReportSharing {
  Future<void> partager({
    required Uint8List document,
    required String nomFichier,
  });
}

class PrintingReportSharing implements ReportSharing {
  const PrintingReportSharing();

  @override
  Future<void> partager({
    required Uint8List document,
    required String nomFichier,
  }) {
    return Printing.sharePdf(bytes: document, filename: nomFichier);
  }
}
