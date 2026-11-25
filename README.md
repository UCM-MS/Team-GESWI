# Hľadá sa Gabriel (Godot 4.7)

**Príbeh:** V mestečku sa konajú Dni mesta. Pes Gabriel sa zľakol ohňostroja a utiekol. Marek (14) ho ide hľadať sám. Obyvatelia mu povedia, čo videli, ale až keď im pomôže s počtami. Matematika pokrýva výkonový štandard **Kladné a záporné čísla (8. ročník ZŠ)**: každá z 11 hlavných úloh preberá jeden čiastkový cieľ.

## Spustenie
Godot 4.7 → Import → vyber `project.godot` → F5.

| Kláves | Akcia |
|---|---|
| šípky / WASD | chôdza po políčkach |
| E / medzerník | rozprávať, ďalej, vybrať odpoveď |
| Enter | odoslať odpoveď |
| 1 – 4 | rýchly výber možnosti |
| N / Tab | zápisník (←→ prepína na Knihu stôp) |
| Esc | zavrieť (rozpracovaná úloha sa zapamätá) |

Do budovy sa vchádza chôdzou do dverí (alebo E pred dverami), von sa ide cez rohožku dole.
Hra sa ukladá automaticky (`user://ulozenie.json`) po každej úlohe a pri vstupe do budovy/z budovy. Na titulke: Enter = pokračovať, N = nová hra.

## Mestečko
Mapa 64 × 56 dlaždíc (1024 × 896 px), mriežka 4 × 4 oblastí, okolo les. 19 budov: **11 so vstupom** (žltý prah pred dverami) a 8 ozdobných.
Námestie s fontánou, zastávka s parkom, jazero s prístavom a mólom, člnáreň a záhradná chatka. Jediná cesta von vedie na západ k zastávke, ostatné sú zatarasené.

Trasa hlavných úloh (poradie je záväzné):
`Dom → 1 Potraviny → 2 Pekáreň → 3 Škola → 4 Knižnica → 5 Pošta → 6 Záhradníctvo → 7 Kaviareň → 8 Radnica → 9 Dielňa → 10 Zastávka → 11 Prístav → Člnáreň → Chatka (Gabriel)`

Vedľajšie úlohy (10): Dedko Jozef na námestí, Babka Anna, Fero, Tomáš, Zuzana, Kováčová, Pavol, Ondrej, 8 skrytých kostí, mačka Micka. Odomknú sa po hlavnej úlohe danej postavy. Odmeny: píšťalka a koláč (zmenia finále), bicykel (rýchlejšia chôdza), nápoveda navyše, Kniha stôp, čiapka, rybárske tipy.

## Kde čo upravovať

| Čo | Kde |
|---|---|
| **Texty a čísla úloh**, postavy, budovy, interiéry | `data/ulohy.json` (bez zásahu do kódu) |
| Mapa mesta | `scripts/level.gd` → textová mapa `MAPA` s legendou znakov |
| Logika úloh, uloženie, prechody scén | `scripts/game.gd` (autoload `Game`) |
| Dialógy, otázky, zápisník, HUD | `scripts/dialog.gd`, číselná os `scripts/number_line.gd` |

### Formát úlohy v `ulohy.json`
Každá úloha má `uvod`, zoznam `kroky` a `stopa` (indícia). Typy krokov:
- `"text"` – hráč napíše číslo. Viac čísel oddelí `;` (`"odpoved": "6;-6"`, pri `"poradie": false` na poradí nezáleží). Rozumie desatinnej čiarke aj znaku −.
- `"volba"` – výber z `moznosti`, `odpoved` je index (od 0).
- `"os"` – hráč posúva bod na číselnej osi (`min`, `max`, `krok`).

Každý krok má `napoveda`, ktorá sa ukáže po zlej odpovedi. Hráč skúša znova bez straty postupu.

### Interiéry
V `ulohy.json → interiery` je pre každý typ miestnosti mapa 20 × 12 znakov. Legenda je na začiatku `scripts/interior.gd`. Špeciálne znaky: `1` obyvateľ, `3` skrytá kosť, `4` mačka, `@` kde hráč vojde, `E` východ.

## Štruktúra
| Priečinok | Čo tam je |
|---|---|
| `art/` | pôvodné zdrojové **.aseprite** súbory (Godot ich ignoruje) |
| `assets/budovy/` | 19 budov (každá ako jeden obrázok, výška 4 dlaždice) |
| `assets/sprites/` | postavy 16×32 px (riadok = animácia), `predmety.png` = kosť, loptička, mačka |
| `assets/tiles/tileset.png` | dlaždice 16×16, atlas 16 × 8 (pôvodných 8 × 6 + mesto + interiéry) |
| `resources/` | `*_frames.tres` (SpriteFrames), `tileset.tres` (kolízie, animovaná voda) |
| `scenes/` | `intro.tscn`, `main.tscn` (mesto), `interior.tscn`, `player.tscn`, `npc.tscn`, `pes.tscn` |

**Pozor:** `art/tileset.aseprite` zodpovedá len pôvodnej časti atlasu (ľavý horný roh 8 × 6). Nové dlaždice a budovy sú zatiaľ len v PNG. Ak budete tileset kresliť v Aseprite, rozšírte plátno na 256 × 128 px a nové dlaždice nechajte na rovnakých miestach (súradnice sú v `scripts/tile_ids.gd`).

## Export
Úlohy sa načítajú cez `load("res://data/ulohy.json")`, takže by sa mali exportovať automaticky. Ak by exportovaná hra nenašla úlohy, pridajte v Export → Resources → *Filters to export non-resource files* hodnotu `*.json`.
