import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/fee_breakdown.dart';
import 'fee_calculator.dart';
import 'report_templates.dart';

/// Compose le rapport PDF à partir des templates (§3.1, §6).
///
/// Le document est construit hors de tout contexte Flutter : il est donc
/// testable sans rendu d'écran, et la même méthode sert à l'aperçu comme
/// au partage.
class PdfReportService {
  const PdfReportService({this.templates = const ReportTemplates()});

  final ReportTemplates templates;

  /// Terre cuite et vert épargne de la palette « Le Ticket ». Le rapport
  /// est destiné à l'impression : seule la version claire existe.
  static const _terreCuite = PdfColor.fromInt(0xFFB85A32);
  static const _vertEpargne = PdfColor.fromInt(0xFF3F7A5E);
  static const _encre = PdfColor.fromInt(0xFF1C1A17);
  static const _grisChaud = PdfColor.fromInt(0xFF6E675E);
  static const _papier = PdfColor.fromInt(0xFFEFEAE1);

  Future<Uint8List> construire({
    required ComparisonResult resultat,
    required List<FeeBreakdown> classement,
    required double volumeMensuel,
    double? panierMoyen,
    DateTime? date,
  }) async {
    final maintenant = date ?? DateTime.now();
    final panier = panierMoyen ?? FeeCalculator.panierMoyenParDefaut;
    final contientEstimation =
        classement.any((b) => !b.provider.aTarifsFixes);

    final document = pw.Document(
      title: 'Frais TPE — Rapport de comparaison',
      author: 'Frais TPE',
    );

    document.addPage(
      pw.MultiPage(
        theme: await _theme(),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 46),
        footer: (context) => _piedDePage(context, maintenant),
        build: (context) => [
          _entete(maintenant),
          pw.SizedBox(height: 24),
          _titre(resultat),
          pw.SizedBox(height: 14),
          _paragraphe(
            templates.introduction(
              resultat,
              volumeMensuel: volumeMensuel,
              panierMoyen: panier,
            ),
          ),
          pw.SizedBox(height: 22),
          _blocComparaison(resultat),
          if (!resultat.dejaOptimal && resultat.ecartParPoste.isNotEmpty)
            _section("D'où vient l'écart", _tableauEcart(resultat)),
          _section(
            'Recommandation',
            _encadre(templates.recommandation(resultat)),
          ),
          // Le titre et le tableau sont deux éléments de premier niveau, et
          // non un bloc unique : imbriquer un `Table` sécable dans une
          // `Column` elle-même sécable fait boucler la pagination de
          // `MultiPage` jusqu'à sa limite de pages. Le titre peut donc se
          // retrouver seul en bas de page si le tableau est long — c'est le
          // compromis retenu contre un échec de génération.
          pw.SizedBox(height: 22),
          _sousTitre('Toutes les offres comparées'),
          pw.SizedBox(height: 8),
          _tableauClassement(classement, resultat),
          _section(
            'Méthode de calcul',
            _paragraphe(
              templates.noteMethode(
                contientEstimationBancaire: contientEstimation,
              ),
              taille: 9.5,
              couleur: _grisChaud,
            ),
          ),
        ],
      ),
    );

    return document.save();
  }

  /// Police embarquée plutôt que les polices standard d'un PDF : celles-ci
  /// ne contiennent ni le symbole « € » ni le tiret cadratin, qui
  /// disparaissaient purement et simplement du document — les montants
  /// s'imprimaient « 26,12 » sans unité.
  ///
  /// Chargée une fois par instance : composer plusieurs rapports ne relit
  /// pas les 800 Ko de fichiers.
  static pw.ThemeData? _themeCache;

  Future<pw.ThemeData> _theme() async {
    final cache = _themeCache;
    if (cache != null) return cache;

    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/LiberationSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/LiberationSans-Bold.ttf'),
    );
    return _themeCache = pw.ThemeData.withFont(base: regular, bold: bold);
  }

  pw.Widget _entete(DateTime date) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 22,
              height: 22,
              decoration: pw.BoxDecoration(
                color: _terreCuite,
                borderRadius: pw.BorderRadius.circular(5),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Frais TPE',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: _encre,
              ),
            ),
          ],
        ),
        pw.Text(
          DateFormat('d MMMM yyyy', 'fr_FR').format(date),
          style: const pw.TextStyle(fontSize: 10, color: _grisChaud),
        ),
      ],
    );
  }

  pw.Widget _titre(ComparisonResult resultat) {
    return pw.Text(
      templates.titre(resultat),
      style: pw.TextStyle(
        fontSize: 22,
        fontWeight: pw.FontWeight.bold,
        color: _encre,
      ),
    );
  }

  /// Un titre et son contenu.
  ///
  /// [insecable] enveloppe le bloc dans un `Container`, que `MultiPage` ne
  /// coupe pas — une `Column` seule serait scindée, laissant le titre
  /// orphelin en bas de page pendant que son contenu bascule sur la
  /// suivante.
  ///
  /// À réserver aux sections de hauteur bornée : `MultiPage` lève
  /// `PdfTooBigPageException` sur un bloc insécable plus haut qu'une page.
  /// Le tableau des offres, dont la longueur dépend du nombre de
  /// prestataires en base, est donc composé hors de cette méthode.
  pw.Widget _section(String titre, pw.Widget contenu) {
    // `Stack` est le conteneur retenu parce qu'il est le seul à ne pas se
    // laisser couper : `Column` déclare `canSpan` dès qu'elle est
    // verticale, et tous les autres emballages (`Container`, `Padding`,
    // `ConstrainedBox`) délèguent la question à leur enfant, donc à la
    // `Column`. `Stack` n'implémente pas `SpanningWidget` du tout :
    // `MultiPage` le reporte en bloc sur la page suivante s'il n'y tient
    // pas, au lieu d'y laisser le titre seul.
    return pw.Stack(
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 22),
            _sousTitre(titre),
            pw.SizedBox(height: 8),
            contenu,
          ],
        ),
      ],
    );
  }

  pw.Widget _sousTitre(String texte) {
    return pw.Text(
      texte.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        letterSpacing: 1,
        fontWeight: pw.FontWeight.bold,
        color: _grisChaud,
      ),
    );
  }

  pw.Widget _paragraphe(
    String texte, {
    double taille = 11,
    PdfColor couleur = _encre,
  }) {
    return pw.Text(
      texte,
      style: pw.TextStyle(fontSize: taille, color: couleur, lineSpacing: 3),
    );
  }

  pw.Widget _encadre(String texte) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _papier,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: _paragraphe(texte),
    );
  }

  /// Les deux montants en vis-à-vis, transposition imprimée de la jauge.
  pw.Widget _blocComparaison(ComparisonResult resultat) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _carteMontant(
            libelle: "Aujourd'hui",
            valeur: resultat.actuel.totalMensuel,
            detail: resultat.actuel.provider.nomComplet,
            couleur: _encre,
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _carteMontant(
            libelle: resultat.dejaOptimal
                ? 'Meilleure autre offre'
                : 'Avec ${resultat.optimise.provider.nom}',
            valeur: resultat.optimise.totalMensuel,
            detail: resultat.optimise.provider.nomComplet,
            couleur: resultat.dejaOptimal ? _encre : _vertEpargne,
          ),
        ),
        if (!resultat.dejaOptimal) ...[
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _carteMontant(
              libelle: 'Économie par mois',
              valeur: resultat.economieMensuelle,
              detail: '${_euro(resultat.economieAnnuelle)} par an',
              couleur: _terreCuite,
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _carteMontant({
    required String libelle,
    required double valeur,
    required String detail,
    required PdfColor couleur,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _papier, width: 1.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            libelle,
            style: const pw.TextStyle(fontSize: 8.5, color: _grisChaud),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            _euro(valeur),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: couleur,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            detail,
            style: const pw.TextStyle(fontSize: 8, color: _grisChaud),
          ),
        ],
      ),
    );
  }

  pw.Widget _tableauEcart(ComparisonResult resultat) {
    return pw.Column(
      children: [
        for (final ligne in resultat.ecartParPoste)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  ligne.libelle,
                  style: const pw.TextStyle(fontSize: 10.5, color: _encre),
                ),
                pw.Text(
                  '${ligne.montantMensuel >= 0 ? '-' : '+'} '
                  '${_euro(ligne.montantMensuel.abs())}',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: ligne.montantMensuel >= 0 ? _encre : _grisChaud,
                  ),
                ),
              ],
            ),
          ),
        // La somme est rappelée : le lecteur doit pouvoir vérifier que le
        // détail tombe juste sur l'économie annoncée.
        pw.Divider(color: _papier, thickness: 1),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: _encre,
              ),
            ),
            pw.Text(
              '- ${_euro(resultat.economieMensuelle)}',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: _vertEpargne,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _tableauClassement(
    List<FeeBreakdown> classement,
    ComparisonResult resultat,
  ) {
    final idActuel = resultat.actuel.provider.id;
    return pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _papier, width: 1),
        bottom: pw.BorderSide(color: _papier, width: 1),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(1.6),
      },
      children: [
        pw.TableRow(
          children: [
            _celluleEntete('Prestataire'),
            _celluleEntete('Par mois', alignerADroite: true),
            _celluleEntete('Par an', alignerADroite: true),
          ],
        ),
        for (final b in classement)
          pw.TableRow(
            children: [
              _cellule(
                b.provider.id == idActuel
                    ? '${b.provider.nomComplet}  (votre offre)'
                    : b.provider.nomComplet,
                gras: b.provider.id == idActuel,
              ),
              _cellule(
                '${b.provider.aTarifsFixes ? '' : '~ '}'
                '${_euro(b.totalMensuel)}',
                alignerADroite: true,
              ),
              _cellule(
                '${b.provider.aTarifsFixes ? '' : '~ '}'
                '${_euro(b.totalAnnuel)}',
                alignerADroite: true,
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _celluleEntete(String texte, {bool alignerADroite = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Text(
        texte,
        textAlign: alignerADroite ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: _grisChaud,
        ),
      ),
    );
  }

  pw.Widget _cellule(
    String texte, {
    bool alignerADroite = false,
    bool gras = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Text(
        texte,
        textAlign: alignerADroite ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 10,
          color: _encre,
          fontWeight: gras ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _piedDePage(pw.Context context, DateTime date) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(color: _papier, thickness: 1),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                templates.piedDePage(date),
                style: const pw.TextStyle(fontSize: 7.5, color: _grisChaud),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 7.5, color: _grisChaud),
            ),
          ],
        ),
      ],
    );
  }
}

String _euro(double montant) {
  return NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  ).format(montant);
}
