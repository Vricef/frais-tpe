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
3. Créer la collection `providers` dans Firestore selon le modèle décrit
   dans le cahier des charges (§5).

## Développement

```
flutter pub get
flutter analyze
flutter test
flutter run
```
