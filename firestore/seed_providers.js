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
 *   npm install firebase-admin
 *   GOOGLE_APPLICATION_CREDENTIALS=./cle-service.json node seed_providers.js
 *
 * Options :
 *   --dry-run   affiche ce qui serait écrit, sans rien écrire
 *
 * L'écriture est idempotente : relancer le script met à jour les documents
 * existants (merge) sans dupliquer ni supprimer ceux qui ne figurent pas
 * dans le fichier.
 */
const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DRY_RUN = process.argv.includes('--dry-run');
const SEED_FILE = path.join(__dirname, 'providers.seed.json');

function parseSeed() {
  const raw = JSON.parse(fs.readFileSync(SEED_FILE, 'utf8'));
  return Object.entries(raw).map(([id, data]) => {
    const doc = { ...data };
    // Les dates sont écrites en ISO dans le JSON ; Firestore attend un
    // Timestamp, faute de quoi `derniere_maj` remonterait en String côté
    // app et la fiche prestataire n'afficherait aucune date.
    if (doc.derniere_maj) {
      doc.derniere_maj = admin.firestore.Timestamp.fromDate(
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

  admin.initializeApp({ credential: admin.credential.applicationDefault() });
  const db = admin.firestore();

  const batch = db.batch();
  for (const { id, doc } of entries) {
    batch.set(db.collection('providers').doc(id), doc, { merge: true });
  }
  await batch.commit();

  console.log(`${entries.length} prestataire(s) écrit(s) dans providers.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
