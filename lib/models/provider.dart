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

/// Un prestataire de paiement (collection Firestore `providers`).
///
/// Nommée `TpeProvider` plutôt que `Provider` pour ne pas entrer en
/// conflit avec `package:provider`, largement utilisé dans l'écosystème
/// Flutter.
class TpeProvider {
  final String id;
  final String nom;
  final ProviderType type;

  /// % prélevé par transaction CB (prestataires à tarifs fixes uniquement).
  final double? fraisTransactionCb;

  /// Montant fixe (€) prélevé par transaction (prestataires à tarifs fixes).
  final double? fraisFixeTransaction;

  /// Frais mensuels (€) : abonnement, location de terminal, etc.
  final double? fraisMensuels;

  /// Borne basse indicative (%) pour les banques traditionnelles.
  final double? fourchetteMin;

  /// Borne haute indicative (%) pour les banques traditionnelles.
  final double? fourchetteMax;

  /// Texte d'accompagnement affiché avec la fourchette (ex. argument de
  /// négociation).
  final String? mentionNegociation;

  final DateTime? derniereMaj;

  const TpeProvider({
    required this.id,
    required this.nom,
    required this.type,
    this.fraisTransactionCb,
    this.fraisFixeTransaction,
    this.fraisMensuels,
    this.fourchetteMin,
    this.fourchetteMax,
    this.mentionNegociation,
    this.derniereMaj,
  });

  bool get aTarifsFixes => type == ProviderType.processeurPaiement;

  factory TpeProvider.fromMap(String id, Map<String, dynamic> data) {
    final rawMaj = data['derniere_maj'];
    return TpeProvider(
      id: id,
      nom: data['nom'] as String? ?? id,
      type: ProviderType.fromFirestore(data['type'] as String? ?? ''),
      fraisTransactionCb: (data['frais_transaction_cb'] as num?)?.toDouble(),
      fraisFixeTransaction:
          (data['frais_fixe_transaction'] as num?)?.toDouble(),
      fraisMensuels: (data['frais_mensuels'] as num?)?.toDouble(),
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
      'type': type.name,
      if (fraisTransactionCb != null) 'frais_transaction_cb': fraisTransactionCb,
      if (fraisFixeTransaction != null)
        'frais_fixe_transaction': fraisFixeTransaction,
      if (fraisMensuels != null) 'frais_mensuels': fraisMensuels,
      if (fourchetteMin != null) 'fourchette_min': fourchetteMin,
      if (fourchetteMax != null) 'fourchette_max': fourchetteMax,
      if (mentionNegociation != null) 'mention_negociation': mentionNegociation,
      if (derniereMaj != null) 'derniere_maj': Timestamp.fromDate(derniereMaj!),
    };
  }
}
