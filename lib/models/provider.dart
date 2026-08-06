import 'package:cloud_firestore/cloud_firestore.dart';

/// Catégorie d'un prestataire (cahier des charges §5, champ Firestore `type`).
///
/// Sert aussi de discriminant : les [processeurPaiement] ont une grille
/// tarifaire publique et fixe (champs `frais_*`), les [banquePro] ont des
/// tarifs négociés au cas par cas, affichés en fourchette (champs
/// `fourchette_*`) — voir §3.2.
enum ProviderType {
  processeurPaiement,
  banquePro;

  static ProviderType fromFirestore(String value) {
    return ProviderType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => ProviderType.processeurPaiement,
    );
  }
}

/// Un taux qui ne s'applique qu'à certains encaissements (Amex, cartes
/// hors zone, paiement à distance…).
///
/// Ces cas ne servent pas au calcul principal — celui-ci retient le taux
/// courant, l'encaissement en personne par carte domestique — mais ils
/// sont affichés sur la fiche : un commerçant qui encaisse beaucoup d'Amex
/// ou de cartes étrangères doit pouvoir le voir.
class TarifAdditionnel {
  const TarifAdditionnel({
    required this.libelle,
    required this.taux,
    this.fraisFixe,
  });

  final String libelle;
  final double taux;
  final double? fraisFixe;

  factory TarifAdditionnel.fromMap(Map<String, dynamic> data) {
    return TarifAdditionnel(
      libelle: data['libelle'] as String? ?? '',
      taux: (data['taux'] as num?)?.toDouble() ?? 0,
      fraisFixe: (data['frais_fixe'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'libelle': libelle,
        'taux': taux,
        if (fraisFixe != null) 'frais_fixe': fraisFixe,
      };
}

/// Un prestataire de paiement (collection Firestore `providers`).
///
/// Nommée `TpeProvider` plutôt que `Provider` pour ne pas entrer en
/// conflit avec `package:provider`, largement utilisé dans l'écosystème
/// Flutter.
///
/// Un même prestataire peut avoir plusieurs offres (SumUp avec et sans
/// abonnement) : chacune est un document distinct, distingué par [offre].
class TpeProvider {
  final String id;
  final String nom;

  /// Nom de l'offre quand le prestataire en propose plusieurs
  /// (« Paiements Plus »). `null` s'il n'en a qu'une.
  final String? offre;

  final ProviderType type;

  /// % prélevé par transaction pour le cas courant : encaissement en
  /// personne, carte domestique. Les autres cas sont dans
  /// [tarifsAdditionnels].
  final double? fraisTransactionCb;

  /// Montant fixe (€) prélevé par transaction (prestataires à tarifs fixes).
  final double? fraisFixeTransaction;

  /// Frais mensuels (€) : abonnement, location de terminal, etc.
  final double? fraisMensuels;

  /// Taux applicables à des encaissements particuliers, pour affichage.
  final List<TarifAdditionnel> tarifsAdditionnels;

  /// Prix d'achat du terminal (€ HT). Achat unique : volontairement exclu
  /// du coût mensuel, qu'il fausserait, mais affiché sur la fiche car il
  /// pèse à l'entrée — de 29 € à 249 € selon les prestataires.
  final double? coutTerminalMin;
  final double? coutTerminalMax;

  /// Borne basse indicative (%) pour les banques traditionnelles.
  final double? fourchetteMin;

  /// Borne haute indicative (%) pour les banques traditionnelles.
  final double? fourchetteMax;

  /// Texte d'accompagnement affiché avec la fourchette (ex. argument de
  /// négociation).
  final String? mentionNegociation;

  final DateTime? derniereMaj;

  /// Saisi par l'utilisateur plutôt que chargé depuis Firestore, pour un
  /// prestataire absent de la base ou un tarif négocié individuellement.
  final bool estPersonnalise;

  const TpeProvider({
    required this.id,
    required this.nom,
    required this.type,
    this.offre,
    this.fraisTransactionCb,
    this.fraisFixeTransaction,
    this.fraisMensuels,
    this.tarifsAdditionnels = const [],
    this.coutTerminalMin,
    this.coutTerminalMax,
    this.fourchetteMin,
    this.fourchetteMax,
    this.mentionNegociation,
    this.derniereMaj,
    this.estPersonnalise = false,
  });

  bool get aTarifsFixes => type == ProviderType.processeurPaiement;

  /// Nom affiché : « SumUp — Paiements Plus » quand l'offre est précisée.
  String get nomComplet => offre == null ? nom : '$nom — $offre';

  bool get aUnTerminalAAcheter =>
      coutTerminalMin != null || coutTerminalMax != null;

  factory TpeProvider.fromMap(String id, Map<String, dynamic> data) {
    final rawMaj = data['derniere_maj'];
    final rawTarifs = data['tarifs_additionnels'];
    return TpeProvider(
      id: id,
      nom: data['nom'] as String? ?? id,
      offre: data['offre'] as String?,
      type: ProviderType.fromFirestore(data['type'] as String? ?? ''),
      fraisTransactionCb: (data['frais_transaction_cb'] as num?)?.toDouble(),
      fraisFixeTransaction:
          (data['frais_fixe_transaction'] as num?)?.toDouble(),
      fraisMensuels: (data['frais_mensuels'] as num?)?.toDouble(),
      tarifsAdditionnels: rawTarifs is List
          ? rawTarifs
              .whereType<Map<String, dynamic>>()
              .map(TarifAdditionnel.fromMap)
              .toList()
          : const [],
      coutTerminalMin: (data['cout_terminal_min'] as num?)?.toDouble(),
      coutTerminalMax: (data['cout_terminal_max'] as num?)?.toDouble(),
      fourchetteMin: (data['fourchette_min'] as num?)?.toDouble(),
      fourchetteMax: (data['fourchette_max'] as num?)?.toDouble(),
      mentionNegociation: data['mention_negociation'] as String?,
      derniereMaj: rawMaj is Timestamp ? rawMaj.toDate() : null,
    );
  }

  factory TpeProvider.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TpeProvider.fromMap(doc.id, doc.data() ?? const {});
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      if (offre != null) 'offre': offre,
      'type': type.name,
      if (fraisTransactionCb != null) 'frais_transaction_cb': fraisTransactionCb,
      if (fraisFixeTransaction != null)
        'frais_fixe_transaction': fraisFixeTransaction,
      if (fraisMensuels != null) 'frais_mensuels': fraisMensuels,
      if (tarifsAdditionnels.isNotEmpty)
        'tarifs_additionnels':
            tarifsAdditionnels.map((t) => t.toMap()).toList(),
      if (coutTerminalMin != null) 'cout_terminal_min': coutTerminalMin,
      if (coutTerminalMax != null) 'cout_terminal_max': coutTerminalMax,
      if (fourchetteMin != null) 'fourchette_min': fourchetteMin,
      if (fourchetteMax != null) 'fourchette_max': fourchetteMax,
      if (mentionNegociation != null) 'mention_negociation': mentionNegociation,
      if (derniereMaj != null) 'derniere_maj': Timestamp.fromDate(derniereMaj!),
    };
  }
}
