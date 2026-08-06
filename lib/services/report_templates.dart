import 'package:intl/intl.dart';

import '../models/fee_breakdown.dart';

/// Les variantes de wording du rapport (cahier des charges §10).
///
/// La variante est choisie d'après le résultat, pas au hasard : annoncer
/// « vous économisez » pour 2 € par mois décrédibiliserait le reste du
/// rapport auprès d'un commerçant qui sait compter.
enum VarianteRapport {
  /// L'écart justifie de changer de prestataire.
  economieSignificative,

  /// Un écart existe, mais trop faible pour valoir la démarche à lui seul.
  economieFaible,

  /// Le prestataire actuel est déjà le moins cher.
  dejaOptimal,
}

/// Le texte d'un rapport, composé de templates pré-écrits dans lesquels
/// les valeurs calculées sont injectées.
///
/// Aucun appel à un service d'IA (§6) : le texte est déterministe, ce qui
/// rend le coût par rapport nul et le contenu vérifiable — deux
/// utilisateurs dans la même situation reçoivent exactement le même texte.
class ReportTemplates {
  const ReportTemplates();

  /// En dessous de ce gain mensuel, changer de prestataire ne s'impose
  /// pas : les démarches et le rachat éventuel d'un terminal absorbent
  /// l'écart.
  static const double seuilEconomieFaible = 5;

  VarianteRapport variantePour(ComparisonResult resultat) {
    if (resultat.dejaOptimal) return VarianteRapport.dejaOptimal;
    if (resultat.economieMensuelle < seuilEconomieFaible) {
      return VarianteRapport.economieFaible;
    }
    return VarianteRapport.economieSignificative;
  }

  String titre(ComparisonResult resultat) {
    switch (variantePour(resultat)) {
      case VarianteRapport.economieSignificative:
        return 'Vous payez ${_euro(resultat.economieMensuelle)} de trop '
            'chaque mois';
      case VarianteRapport.economieFaible:
        return 'Votre offre actuelle est correcte';
      case VarianteRapport.dejaOptimal:
        return 'Vous êtes déjà au meilleur tarif';
    }
  }

  /// Le paragraphe d'ouverture. Il reprend les chiffres saisis pour que le
  /// lecteur puisse vérifier sur quelle base le calcul a été fait.
  String introduction(
    ComparisonResult resultat, {
    required double volumeMensuel,
    required double panierMoyen,
  }) {
    final volume = _euro(volumeMensuel);
    final panier = _euro(panierMoyen);
    final actuel = resultat.actuel.provider.nomComplet;
    final base =
        "Ce rapport compare le coût de vos encaissements par carte sur la "
        "base de $volume encaissés par mois, pour un panier moyen de "
        "$panier, avec $actuel comme prestataire actuel.";

    switch (variantePour(resultat)) {
      case VarianteRapport.economieSignificative:
        return "$base\n\n"
            "À ce volume, ${resultat.optimise.provider.nomComplet} vous "
            "coûterait ${_euro(resultat.optimise.totalMensuel)} par mois "
            "contre ${_euro(resultat.actuel.totalMensuel)} aujourd'hui, soit "
            "${_euro(resultat.economieMensuelle)} d'économie mensuelle et "
            "${_euro(resultat.economieAnnuelle)} sur un an.";
      case VarianteRapport.economieFaible:
        return "$base\n\n"
            "L'offre la moins chère à ce volume est "
            "${resultat.optimise.provider.nomComplet}, pour "
            "${_euro(resultat.economieMensuelle)} d'économie par mois "
            "(${_euro(resultat.economieAnnuelle)} par an). L'écart est réel "
            "mais modeste : il ne justifie pas à lui seul de changer, "
            "d'autant qu'un nouveau terminal peut être à acheter.";
      case VarianteRapport.dejaOptimal:
        return "$base\n\n"
            "Aucune des offres comparées ne fait mieux que la vôtre à ce "
            "volume. Votre choix actuel est le bon : ce rapport vous servira "
            "à le vérifier si vos encaissements évoluent.";
    }
  }

  /// La recommandation, en une phrase actionnable.
  String recommandation(ComparisonResult resultat) {
    switch (variantePour(resultat)) {
      case VarianteRapport.economieSignificative:
        return "Demandez à ${resultat.actuel.provider.nomComplet} de "
            "s'aligner sur ${_euro(resultat.optimise.totalMensuel)} par "
            "mois. À défaut, le passage à "
            "${resultat.optimise.provider.nomComplet} est justifié.";
      case VarianteRapport.economieFaible:
        return "Conservez votre offre actuelle, et refaites le calcul si "
            "votre volume d'encaissement change nettement.";
      case VarianteRapport.dejaOptimal:
        return "Vous n'avez rien à changer. Refaites le calcul si votre "
            "volume d'encaissement change nettement.";
    }
  }

  /// La note de méthode. Elle explique ce que le calcul retient et ce
  /// qu'il laisse de côté — un chiffre dont on ignore la méthode ne
  /// convainc personne, et sert mal une négociation.
  String noteMethode({required bool contientEstimationBancaire}) {
    final buffer = StringBuffer(
      "Les montants sont calculés à partir des grilles tarifaires publiques "
      "des prestataires, pour un encaissement en personne par carte "
      "domestique. Les taux particuliers (American Express, cartes hors "
      "zone euro, paiement à distance) ne sont pas inclus dans l'estimation.",
    );
    buffer.write(
      "\n\nLe prix d'achat du terminal n'est pas compté dans le coût "
      "mensuel : c'est une dépense unique, qui varie de 29 € à 249 € HT "
      "selon les prestataires.",
    );
    if (contientEstimationBancaire) {
      buffer.write(
        "\n\nLes banques traditionnelles ne publient pas de grille fixe. "
        "Leur coût est estimé au milieu des tarifs habituellement "
        "constatés et se négocie au cas par cas : traitez-le comme un ordre "
        "de grandeur, pas comme un prix ferme.",
      );
    }
    return buffer.toString();
  }

  String piedDePage(DateTime date) {
    final format = DateFormat('d MMMM yyyy', 'fr_FR');
    return 'Rapport établi le ${format.format(date)} par Frais TPE. '
        'Les tarifs évoluent : vérifiez-les auprès des prestataires avant '
        'toute décision.';
  }
}

String _euro(double montant) {
  return NumberFormat.currency(
    locale: 'fr_FR',
    symbol: '€',
    decimalDigits: 2,
  ).format(montant);
}
