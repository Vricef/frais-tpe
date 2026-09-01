#!/usr/bin/env python3
"""Fabrique les sources d'icônes à partir du logo carré.

Deux fichiers en sortie, aux exigences opposées :

  logo.png             1024x1024 opaque, pour iOS et l'Android hérité.
  logo-avant-plan.png  1024x1024 transparent hors du motif, pour les
                       icônes adaptatives d'Android.

Usage :  python3 tool/preparer_icones.py store/icone-play-512.png
"""
import pathlib
import sys

from PIL import Image, ImageDraw

RACINE = pathlib.Path(__file__).resolve().parent.parent
SORTIE = RACINE / "assets" / "icone"
COTE = 1024

# Zone sûre d'une icône adaptative : sur 108 dp, les 18 dp de chaque bord
# peuvent être rognés selon le masque du fabricant. Le motif doit tenir
# dans le cercle inscrit dans les 72 dp restants.
PART_SURE = 72 / 108

# flutter_launcher_icons enveloppe l'avant-plan dans un `<inset>` de 16 %
# par bord. Sans en tenir compte, la réduction s'appliquerait deux fois
# et le motif sortirait à 45 % de la toile au lieu de 67 %.
INSET_OUTIL = 0.16


def fond(img):
    """La couleur du fond, lue au coin — jamais devinée."""
    return img.convert("RGBA").getpixel((0, 0))


def detourer(img):
    """Rend transparent le fond, et lui seul.

    Un simple filtrage par couleur perforerait le motif : les traits du
    ticket sont de la même terre cuite que le fond. On part donc des
    quatre coins et on ne vide que ce qui leur est relié.
    """
    travail = img.convert("RGB")
    repere = (1, 2, 3)          # couleur improbable, servant de marqueur
    for coin in [(0, 0), (img.width - 1, 0),
                 (0, img.height - 1), (img.width - 1, img.height - 1)]:
        ImageDraw.floodfill(travail, coin, repere, thresh=30)

    sortie = img.convert("RGBA")
    pixels = sortie.load()
    reperes = travail.load()
    for y in range(sortie.height):
        for x in range(sortie.width):
            if reperes[x, y] == repere:
                pixels[x, y] = (0, 0, 0, 0)
    return sortie


def rayon_visible(motif):
    """Distance au centre du pixel opaque le plus éloigné."""
    alpha = motif.getchannel("A").load()
    cx, cy = (motif.width - 1) / 2, (motif.height - 1) / 2
    carre_max = 0.0
    for y in range(motif.height):
        for x in range(motif.width):
            if alpha[x, y] > 8:
                d = (x - cx) ** 2 + (y - cy) ** 2
                if d > carre_max:
                    carre_max = d
    return carre_max ** 0.5


def cadre_du_motif(img):
    boite = img.getbbox()       # sur l'alpha, une fois détouré
    if boite is None:
        raise SystemExit("motif introuvable : le détourage a tout effacé")
    return boite


def main():
    source = pathlib.Path(sys.argv[1] if len(sys.argv) > 1
                          else "store/icone-play-512.png")
    original = Image.open(RACINE / source).convert("RGBA")
    SORTIE.mkdir(parents=True, exist_ok=True)

    # --- 1. Le carré plein ---
    plein = original.resize((COTE, COTE), Image.LANCZOS)
    Image.alpha_composite(
        Image.new("RGBA", plein.size, fond(original)), plein
    ).convert("RGB").save(SORTIE / "logo.png")

    # --- 2. Le motif seul, centré dans la zone sûre ---
    detoure = detourer(original)
    motif = detoure.crop(cadre_du_motif(detoure))
    # Ce que l'inset de l'outil réduira ensuite est anticipé ici.
    rayon_sur = (COTE * PART_SURE / 2) / (1 - 2 * INSET_OUTIL)
    # Dimensionner sur la diagonale du cadre serait trop prudent : les
    # dentelures laissent les coins vides. On mesure le pixel visible le
    # plus éloigné du centre, ce qui remplit le cercle sans jamais rogner.
    facteur = rayon_sur / rayon_visible(motif)
    taille = (max(1, round(motif.width * facteur)),
              max(1, round(motif.height * facteur)))
    motif = motif.resize(taille, Image.LANCZOS)

    avant_plan = Image.new("RGBA", (COTE, COTE), (0, 0, 0, 0))
    avant_plan.paste(motif, ((COTE - taille[0]) // 2, (COTE - taille[1]) // 2))
    avant_plan.save(SORTIE / "logo-avant-plan.png")

    print(f"logo.png              {COTE}x{COTE}, opaque")
    apres_inset = round(rayon_sur * 2 * (1 - 2 * INSET_OUTIL))
    print(f"logo-avant-plan.png   motif {taille[0]}x{taille[1]} centré ; "
          f"après l'inset de l'outil, il tiendra dans un cercle de "
          f"{apres_inset} px sur {COTE}")


if __name__ == "__main__":
    main()
