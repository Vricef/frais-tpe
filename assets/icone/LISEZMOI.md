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
