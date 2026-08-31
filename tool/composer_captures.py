#!/usr/bin/env python3
"""Compose les captures des stores à partir des rendus bruts.

Chaque image reprend l'identité « Le Ticket » : fond papier, titre court
en encre avec l'accent terre cuite sur le mot qui porte le message, et
l'écran posé dessous sans cadre d'appareil.

Entrée  : les PNG produits par `tool/capturer_ecrans.py` (dossier brut/).
Sortie  : store/captures/ aux formats attendus par les deux boutiques.
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

RACINE = pathlib.Path(__file__).resolve().parent.parent
POLICE_GRASSE = RACINE / "assets/fonts/LiberationSans-Bold.ttf"
POLICE = RACINE / "assets/fonts/LiberationSans-Regular.ttf"

PAPIER = (239, 234, 225)
# Le fond est un cran plus soutenu que le papier de l'app : à couleur
# égale, l'écran se fondait dedans et la capture perdait son sujet.
FOND = (226, 219, 207)
ENCRE = (28, 26, 23)
TERRE = (184, 90, 50)

# Format iPhone 6.9" — les autres tailles en sont dérivées par l'App Store.
LARGEUR, HAUTEUR = 1290, 2796
LARGEUR_ECRAN = 1080          # l'écran posé sur le fond
MARGE_HAUT = 130
TAILLE_TITRE = 62

# Le mot entre crochets passe en terre cuite : c'est lui qui porte le message.
CAPTURES = [
    ("1-jauge",     "resultat.png",           "Voyez ce que vous payez [en trop]"),
    ("2-detail",    "detail-ecart.png",       "[Chaque euro] est expliqué"),
    ("3-saisie",    "saisie.png",             "Un [seul chiffre] à saisir"),
    ("4-tableau",   "tableau.png",            "[Toutes les offres], classées"),
    ("5-rapport",   "rapport-p1.png",         "Un [rapport] à garder"),
    ("6-sans-pub",  "accueil-sombre.png",     "Sans publicité. [Jamais.]"),
]


def morceaux(titre):
    """Découpe « a [b] c » en (texte, accentué?) mot par mot."""
    sortie = []
    for bloc in titre.replace("[", "\x00[").replace("]", "]\x00").split("\x00"):
        if not bloc:
            continue
        accent = bloc.startswith("[")
        for mot in bloc.strip("[]").split():
            sortie.append((mot, accent))
    return sortie


def dessiner_titre(img, titre, police):
    """Titre centré, au plus deux lignes, l'accent en terre cuite."""
    d = ImageDraw.Draw(img)
    mots = morceaux(titre)
    espace = d.textlength(" ", font=police)
    maxi = LARGEUR - 2 * 90

    lignes, courante, largeur = [], [], 0
    for mot, accent in mots:
        w = d.textlength(mot, font=police)
        if courante and largeur + espace + w > maxi:
            lignes.append(courante)
            courante, largeur = [], 0
        courante.append((mot, accent, w))
        largeur += (espace if largeur else 0) + w
    if courante:
        lignes.append(courante)

    y = MARGE_HAUT
    hauteur_ligne = int(TAILLE_TITRE * 1.22)
    for ligne in lignes:
        total = sum(w for _, _, w in ligne) + espace * (len(ligne) - 1)
        x = (LARGEUR - total) / 2
        for mot, accent, w in ligne:
            d.text((x, y), mot, font=police, fill=TERRE if accent else ENCRE)
            x += w + espace
        y += hauteur_ligne
    return y


def rogner_le_vide(img, marge=40):
    """Retire la zone unie sous le contenu.

    Plusieurs écrans laissent un grand vide en bas : conservé tel quel,
    il réduit d'autant la place du contenu utile dans la vignette du
    store, là où se joue le téléchargement.
    """
    rgb = img.convert("RGB")
    fond = rgb.getpixel((rgb.size[0] // 2, rgb.size[1] - 2))
    pixels = rgb.load()
    pas = 4
    dernier = rgb.size[1] - 1
    for y in range(rgb.size[1] - 1, -1, -1):
        ligne_unie = all(
            pixels[x, y] == fond for x in range(0, rgb.size[0], pas)
        )
        if not ligne_unie:
            dernier = y
            break
    bas = min(img.size[1], dernier + marge)
    # Sous un tiers de hauteur restante, c'est que la détection a dérapé.
    if bas < img.size[1] // 3:
        return img
    return img.crop((0, 0, img.size[0], bas))


def coins_arrondis(img, rayon):
    masque = Image.new("L", img.size, 0)
    ImageDraw.Draw(masque).rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1], rayon, fill=255)
    sortie = img.convert("RGBA")
    sortie.putalpha(masque)
    return sortie


def poser(fond, ecran, y):
    """Pose l'écran avec une ombre douce — pas de cadre d'appareil."""
    ombre = Image.new("RGBA", fond.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ombre)
    x = (LARGEUR - ecran.size[0]) // 2
    d.rounded_rectangle(
        [x + 6, y + 14, x + ecran.size[0] - 6, y + ecran.size[1] + 6],
        44, fill=(28, 26, 23, 46))
    ombre = ombre.filter(ImageFilter.GaussianBlur(22))
    fond.alpha_composite(ombre)
    fond.alpha_composite(ecran, (x, y))


def composer(brut, sortie):
    police = ImageFont.truetype(str(POLICE_GRASSE), TAILLE_TITRE)
    sortie.mkdir(parents=True, exist_ok=True)

    for nom, fichier, titre in CAPTURES:
        source = brut / fichier
        if not source.exists():
            print(f"  absent, ignoré : {fichier}", file=sys.stderr)
            continue
        fond = Image.new("RGBA", (LARGEUR, HAUTEUR), FOND + (255,))
        bas_titre = dessiner_titre(fond, titre, police)

        ecran = rogner_le_vide(Image.open(source).convert("RGBA"))
        largeur = LARGEUR_ECRAN
        hauteur = round(ecran.size[1] * largeur / ecran.size[0])
        dispo = HAUTEUR - bas_titre - 150
        if hauteur > dispo:                     # jamais rogné, seulement réduit
            hauteur = dispo
            largeur = round(ecran.size[0] * hauteur / ecran.size[1])
        ecran = coins_arrondis(
            ecran.resize((largeur, hauteur), Image.LANCZOS), 40)

        # Centré dans l'espace restant, mais jamais très loin du titre :
        # une capture courte flottait au milieu de l'image.
        y = bas_titre + min(150, max(70, (HAUTEUR - bas_titre - hauteur - 60) // 2))
        poser(fond, ecran, y)
        chemin = sortie / f"{nom}.png"
        fond.convert("RGB").save(chemin, quality=95)
        print(f"  {chemin.name}  {fond.size[0]}x{fond.size[1]}")


def banniere(brut, sortie):
    """Feature graphic Google Play — 1024 x 500, obligatoire.

    Rien d'écrit en bas : Play y superpose parfois le bouton d'installation.
    """
    L, H = 1024, 500
    img = Image.new("RGBA", (L, H), FOND + (255,))
    d = ImageDraw.Draw(img)

    titre = ImageFont.truetype(str(POLICE_GRASSE), 56)
    sous = ImageFont.truetype(str(POLICE), 30)
    d.text((70, 168), "Frais TPE", font=titre, fill=ENCRE)
    d.text((70, 248), "vos frais de carte, au clair", font=sous, fill=TERRE)

    # La jauge découpée du vrai écran, pas redessinée pour l'occasion.
    source = brut / "resultat.png"
    if source.exists():
        ecran = Image.open(source).convert("RGBA")
        jauge = ecran.crop((100, 600, 1200, 950))
        larg = 420
        jauge = jauge.resize(
            (larg, round(jauge.size[1] * larg / jauge.size[0])), Image.LANCZOS)
        img.alpha_composite(coins_arrondis(jauge, 18),
                            (L - larg - 70, (H - jauge.size[1]) // 2))

    chemin = sortie / "play-banniere.png"
    img.convert("RGB").save(chemin, quality=95)
    print(f"  {chemin.name}  {L}x{H}")


def main():
    brut = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else RACINE / "brut"
    sortie = RACINE / "store" / "captures"
    print("Captures :")
    composer(brut, sortie)
    banniere(brut, sortie)


if __name__ == "__main__":
    main()
