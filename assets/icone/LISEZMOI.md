# Sources des icônes

| Fichier | Rôle | Contraintes |
|---|---|---|
| `logo.png` | iOS et Android hérité | 1024×1024, carré plein, **sans coins arrondis** ni transparence — les stores appliquent eux-mêmes le masque |
| `logo-avant-plan.png` | Calque avant-plan des icônes adaptatives Android | 1024×1024, **fond transparent**, motif contenu dans le cercle central de 66 % — Android rogne le reste selon le masque du fabricant |

Le fond des icônes adaptatives est la couleur terre cuite `#B85A32`,
définie dans `flutter_launcher_icons.yaml` — pas une image.

Régénérer après toute modification :

```bash
dart run flutter_launcher_icons
```

La commande réécrit `android/app/src/main/res/mipmap-*` et
`ios/Runner/Assets.xcassets/AppIcon.appiconset`, qui sont versionnés.

## Deux corrections à refaire après chaque génération

`flutter_launcher_icons` écrase `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`
dans `ios/Runner.xcodeproj/project.pbxproj` en y écrivant `AppIcon`, alors
que cette clé attend `YES` ou `NO`. Vérifier après chaque exécution :

```bash
grep GENERATE_SWIFT_ASSET ios/Runner.xcodeproj/project.pbxproj
```

Et l'outil enveloppe l'avant-plan Android dans un `<inset>` de 16 %.
`tool/preparer_icones.py` en tient compte : le motif y est produit plus
grand que la zone sûre, pour y atterrir exactement une fois l'inset
appliqué. Ne pas « corriger » cette taille en la trouvant trop grande.
