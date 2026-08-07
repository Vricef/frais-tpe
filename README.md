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
npm install firebase-admin
node seed_providers.js --dry-run     # vérifier sans écrire
GOOGLE_APPLICATION_CREDENTIALS=./cle-service.json node seed_providers.js
```

L'écriture est idempotente (`merge`) : le script sert aussi bien à
initialiser la base qu'à mettre à jour un tarif qui a changé. Modifier le
JSON puis relancer suffit — inutile de publier une nouvelle version de
l'app.

La clé de service se télécharge depuis la console Firebase (Paramètres du
projet → Comptes de service). Ne la committez pas : `.gitignore` exclut
déjà les fichiers `.json` de credentials courants, mais vérifiez avant de
pousser.

## Développement

```
flutter pub get
flutter analyze
flutter test
flutter run
```
