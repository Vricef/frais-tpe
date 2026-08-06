#!/usr/bin/env node
/**
 * Importe les grilles tarifaires dans la collection Firestore `providers`.
 *
 * Les tarifs vivent en base et non dans le code (cahier des charges §6),
 * pour être corrigés à distance sans repasser par la review des stores :
 * ce script est donc aussi l'outil de mise à jour, et pas seulement
 * d'initialisation.
 *
 * Usage :
 *   npm install
 *   GOOGLE_APPLICATION_CREDENTIALS=/chemin/cle-service.json node seed_providers.js
 *
 * Options :
 *   --dry-run   affiche ce qui serait écrit, sans rien écrire
 *
 * Contre l'émulateur local, aucune clé n'est nécessaire :
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=frais-tpe node seed_providers.js
 *
 * L'écriture est idempotente : relancer le script met à jour les documents
 * existants (merge) sans dupliquer ni supprimer ceux qui ne figurent pas
 * dans le fichier.
 */
const fs = require('fs');
const path = require('path');

// API modulaire : le namespace historique `admin.firestore` n'existe plus
// dans firebase-admin v13, où il vaut `undefined`.
const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const DRY_RUN = process.argv.includes('--dry-run');
const SEED_FILE = path.join(__dirname, 'providers.seed.json');
const EMULATEUR = Boolean(process.env.FIRESTORE_EMULATOR_HOST);

function parseSeed() {
  const raw = JSON.parse(fs.readFileSync(SEED_FILE, 'utf8'));
  return Object.entries(raw).map(([id, data]) => {
    const doc = { ...data };
    // Les dates sont écrites en ISO dans le JSON ; Firestore attend un
    // Timestamp, faute de quoi `derniere_maj` remonterait en String côté
    // app et la fiche prestataire n'afficherait aucune date.
    if (doc.derniere_maj) {
      doc.derniere_maj = Timestamp.fromDate(
        new Date(`${doc.derniere_maj}T00:00:00Z`)
      );
    }
    return { id, doc };
  });
}

async function main() {
  const entries = parseSeed();

  if (DRY_RUN) {
    for (const { id, doc } of entries) {
      console.log(`${id} →`, JSON.stringify(doc, null, 2));
    }
    console.log(`\n${entries.length} document(s) — aucune écriture (--dry-run).`);
    return;
  }

  // L'émulateur n'authentifie pas : chercher une clé de service ferait
  // échouer le script là où il n'en a pas besoin.
  initializeApp(
    EMULATEUR
      ? { projectId: process.env.GCLOUD_PROJECT || 'frais-tpe' }
      : { credential: applicationDefault() }
  );
  const db = getFirestore();

  const batch = db.batch();
  for (const { id, doc } of entries) {
    batch.set(db.collection('providers').doc(id), doc, { merge: true });
  }
  await batch.commit();

  const cible = EMULATEUR
    ? `l'émulateur (${process.env.FIRESTORE_EMULATOR_HOST})`
    : 'Firestore';
  console.log(`${entries.length} prestataire(s) écrit(s) dans ${cible}.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
