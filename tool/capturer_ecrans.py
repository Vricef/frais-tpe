#!/usr/bin/env python3
"""Photographie les écrans de l'app dans un navigateur.

Enchaînement complet :

    python3 tool/generer_preview.py
    flutter build web -t lib/_preview.dart --no-web-resources-cdn \\
        --pwa-strategy=none --release
    (cd build/web && python3 -m http.server 8000 &)
    python3 tool/capturer_ecrans.py brut/
    python3 tool/composer_captures.py brut/

`--pwa-strategy=none` n'est pas cosmétique : avec le service worker, le
changement de paramètre d'URL resservait la page en cache et deux écrans
différents sortaient identiques.
"""
import asyncio
import os
import sys

from playwright.async_api import async_playwright

SORTIE = sys.argv[1] if len(sys.argv) > 1 else "brut"
CHROMIUM = os.environ.get(
    "CHROMIUM", "/opt/pw-browsers/chromium-1194/chrome-linux/chrome")

# iPhone 6.9" : 1290 x 2796 px, soit 430 x 932 points à densité 3.
L, H, DPR = 430, 932, 3

# (fichier, écran, thème, défilement en points)
ECRANS = [
    ("resultat",           "resultat",           "clair",  0),
    ("saisie",             "saisie",             "clair",  0),
    ("tableau",            "tableau",            "clair",  0),
    ("tableau-verrouille", "tableau-verrouille", "clair",  0),
    ("accueil-sombre",     "accueil",            "sombre", 0),
]


async def attendre_rendu(page, limite=90):
    """Attend que Flutter ait réellement peint.

    Un délai fixe ne suffit pas : le moteur met une quinzaine de secondes
    à démarrer à froid, et les captures sortaient blanches. La balise
    `flt-glass-pane` n'apparaît qu'une fois la scène montée.
    """
    for _ in range(limite * 2):
        if await page.evaluate(
                "() => !!document.querySelector('flt-glass-pane')"):
            await page.wait_for_timeout(3000)   # laisse finir les animations
            return
        await page.wait_for_timeout(500)
    raise RuntimeError("le moteur Flutter n'a rien peint")


async def main():
    os.makedirs(SORTIE, exist_ok=True)
    async with async_playwright() as pw:
        nav = await pw.chromium.launch(
            executable_path=CHROMIUM, args=["--no-sandbox", "--hide-scrollbars"])
        # Contexte partagé pour garder le cache chaud, mais page neuve par
        # écran : réutiliser la page laissait le rendu précédent
        # transparaître derrière le nouveau.
        ctx = await nav.new_context(viewport={"width": L, "height": H},
                                    device_scale_factor=DPR)
        for nom, ecran, theme, defil in ECRANS:
            page = await ctx.new_page()
            soucis = []
            page.on("pageerror", lambda e: soucis.append(str(e)))
            # `networkidle` ne retombe jamais : le moteur garde des
            # requêtes ouvertes.
            await page.goto(
                f"http://127.0.0.1:8000/?ecran={ecran}&theme={theme}",
                wait_until="load", timeout=90000)
            await attendre_rendu(page)
            if defil:
                await page.mouse.move(L // 2, H // 2)
                await page.mouse.wheel(0, defil)
                await page.wait_for_timeout(2000)
            await page.screenshot(path=os.path.join(SORTIE, nom + ".png"))
            print(f"  {nom}" + ("" if not soucis else f"  SOUCIS {soucis[:2]}"))
            await page.close()
        await nav.close()


if __name__ == "__main__":
    asyncio.run(main())
