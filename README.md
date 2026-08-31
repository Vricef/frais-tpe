# Frais TPE

Application mobile (Flutter + Firebase) permettant aux indépendants et petits
commerces de comparer les frais de terminal de paiement (CB) entre
différents prestataires, et d'estimer leur coût réel annuel selon leur
volume d'activité.

## Stack

- Flutter (Dart)
- Firebase / Cloud Firestore — grilles tarifaires des prestataires,
  modifiables à distance sans passer par la review des stores
- Génération PDF par templates pré-écrits (pas d'IA)

## Structure

```
lib/
  models/     Classes de données (ex. TpeProvider — collection Firestore `providers`)
  services/   Accès Firestore, génération PDF, achats in-app, etc.
  screens/    Écrans de l'app (parcours utilisateur)
  widgets/    Composants UI réutilisables
```

## Configuration Firebase

Le projet ne contient pas de projet Firebase préconfiguré. Avant de lancer
l'app :

1. Créer un projet Firebase (console.firebase.google.com) et y activer
   Firestore.
2. Installer la CLI FlutterFire (`dart pub global activate flutterfire_cli`)
   puis lancer `flutterfire configure` à la racine du projet — cela génère
   `lib/firebase_options.dart` et les fichiers de config natifs
   (`google-services.json`, `GoogleService-Info.plist`), volontairement
   exclus du dépôt (`.gitignore`) car spécifiques à chaque environnement.

   Vérifier ensuite que le plugin Google Services a bien été ajouté à
   `android/app/build.gradle.kts` :

   ```kotlin
   plugins {
       id("com.android.application")
       id("com.google.gms.google-services")   // ← ajouté par flutterfire
       id("dev.flutter.flutter-gradle-plugin")
   }
   ```

   et déclaré dans `android/settings.gradle.kts` :

   ```kotlin
   id("com.google.gms.google-services") version "4.4.2" apply false
   ```

   Sans lui, `google-services.json` n'est pas lu : Firebase ne s'initialise
   pas sur Android. L'app démarre quand même — elle affiche un écran
   d'explication — mais aucune grille tarifaire ne se charge.
3. Importer les grilles tarifaires dans la collection `providers` (voir
   ci-dessous).

## Grilles tarifaires

Les tarifs vivent dans Firestore et non dans le code, pour être corrigés à
distance sans repasser par la review des stores. `firestore/` contient les
données et l'outil d'import :

```
firestore/providers.seed.json   Les grilles tarifaires (source de vérité)
firestore/seed_providers.js     Import / mise à jour vers Firestore
```

```bash
cd firestore
npm install
npm run seed:dry                     # vérifier sans écrire
npm run seed                         # écrire dans Firestore
```

L'écriture est idempotente (`merge`) : le script sert aussi bien à
initialiser la base qu'à mettre à jour un tarif qui a changé. Modifier le
JSON puis relancer suffit — inutile de publier une nouvelle version de
l'app.

### Clé de service

Elle se télécharge depuis la console Firebase (Paramètres du projet →
Comptes de service → Générer une nouvelle clé privée). Le script la
cherche dans cet ordre :

1. l'option `--key=CHEMIN` ;
2. la variable `GOOGLE_APPLICATION_CREDENTIALS` ;
3. `firestore/cle-service.json`, puis `cle-service.json` à la racine.

Poser le fichier à l'emplacement 3 évite d'avoir à le redire : une
variable d'environnement ne survit pas à la fermeture du terminal, ce qui
faisait échouer le script à chaque nouvelle session sur
« Unable to detect a Project Id ». Ces deux chemins sont exclus par
`.gitignore`.

Cette clé donne un **accès administrateur complet** au projet et
**contourne les règles de sécurité déployées** : elle reste hors du dépôt
et ne se partage pas. Une clé qui se retrouve dans l'historique Git doit
être considérée comme compromise et régénérée, même retirée depuis.

Contre l'émulateur local, aucune clé n'est nécessaire :

```bash
firebase emulators:start --only firestore   # dans un autre terminal
npm run seed:emulateur
```

## Développement

```
flutter pub get
flutter analyze
flutter test
flutter run
```
