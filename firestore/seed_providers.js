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
 *   --dry-run     affiche ce qui serait écrit, sans rien écrire
 *   --key=CHEMIN  clé de service à utiliser, sans passer par une variable
 *                 d'environnement (qui ne survit pas au terminal)
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
const RACINE = path.join(__dirname, '..');

/** Chemins essayés quand aucune clé n'est indiquée. Tous ignorés par Git. */
const CLES_PAR_DEFAUT = [
  path.join(__dirname, 'cle-service.json'),
  path.join(RACINE, 'cle-service.json'),
];

/**
 * Identifiant du projet, lu dans `.firebaserc` plutôt que déduit de la
 * clé : une clé sans champ `project_id` faisait échouer le script sur
 * « Unable to detect a Project Id », un message qui ne dit pas quoi faire.
 */
function projetFirebase() {
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  try {
    const rc = JSON.parse(
      fs.readFileSync(path.join(RACINE, '.firebaserc'), 'utf8')
    );
    return rc.projects && rc.projects.default;
  } catch {
    return undefined;
  }
}

/**
 * Localise la clé de service, sans jamais en afficher le contenu : ce
 * fichier donne un accès administrateur complet au projet et contourne
 * les règles de sécurité déployées.
 */
function cheminCle() {
  const argument = process.argv.find((a) => a.startsWith('--key='));
  if (argument) return argument.slice('--key='.length);
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return process.env.GOOGLE_APPLICATION_CREDENTIALS;
  }
  return CLES_PAR_DEFAUT.find((c) => fs.existsSync(c));
}

/** Message d'aide, à la place d'une trace de pile illisible. */
function abandon(lignes) {
  console.error(['', ...lignes, ''].join('\n'));
  process.exit(1);
}

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

  const projectId = projetFirebase();
  if (!projectId) {
    abandon([
      "Projet Firebase introuvable : ni GCLOUD_PROJECT, ni un `.firebaserc`",
      'lisible à la racine du dépôt.',
    ]);
  }

  if (EMULATEUR) {
    // L'émulateur n'authentifie pas : chercher une clé de service ferait
    // échouer le script là où il n'en a pas besoin.
    initializeApp({ projectId });
  } else {
    const cle = cheminCle();
    if (!cle) {
      abandon([
        'Aucune clé de service trouvée.',
        '',
        'Console Firebase → Paramètres du projet → Comptes de service →',
        '« Générer une nouvelle clé privée ». Puis, au choix :',
        '',
        '  node seed_providers.js --key=C:\\secrets\\frais-tpe-key.json',
        '',
        '  ou, pour ne plus avoir à le répéter, placez le fichier ici :',
        `  ${CLES_PAR_DEFAUT[0]}`,
        '',
        "Cette clé donne un accès administrateur complet au projet : elle",
        'reste hors du dépôt et ne se partage pas.',
      ]);
    }
    if (!fs.existsSync(cle)) {
      abandon([
        `Clé de service introuvable : ${cle}`,
        '',
        "Le chemin est-il correct ? Sous Windows, les téléchargements",
        'peuvent être redirigés vers OneDrive.',
      ]);
    }
    // `projectId` est passé explicitement : une clé qui ne le porte pas
    // laisserait le SDK échouer plus loin, sans indiquer la cause.
    process.env.GOOGLE_APPLICATION_CREDENTIALS = cle;
    initializeApp({ credential: applicationDefault(), projectId });
    console.log(`Clé : ${cle}`);
  }
  const db = getFirestore();

  const batch = db.batch();
  for (const { id, doc } of entries) {
    batch.set(db.collection('providers').doc(id), doc, { merge: true });
  }
  await batch.commit();

  const cible = EMULATEUR
    ? `l'émulateur (${process.env.FIRESTORE_EMULATOR_HOST})`
    : `Firestore (projet ${projectId})`;
  console.log(`${entries.length} prestataire(s) écrit(s) dans ${cible}.`);
}

main().catch((err) => {
  // Les échecs d'authentification remontent en trace de pile illisible :
  // on nomme la cause probable avant de laisser le détail.
  if (/Project Id|credential|authenticat/i.test(String(err && err.message))) {
    console.error(
      '\nÉchec d\'authentification auprès de Firestore. La clé de service ' +
        'est-elle celle du bon projet ?\n'
    );
  }
  console.error(err);
  process.exit(1);
});
