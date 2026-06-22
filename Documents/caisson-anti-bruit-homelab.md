# Caisson anti-bruit Homelab — IKEA Bestå

> Mode d'emploi complet pour isoler acoustiquement le coin serveur.
> Objectif : réduire le bruit de l'Eaton Ellipse PRO 1600 (~29 dB) à quasi-inaudible (~10-14 dB).

---

## Contexte

L'UPS Eaton Ellipse PRO 1600 FR est équipé d'un ventilateur Sunon MF60152V2-100C-G99 (60×60×15mm, 24V) qui tourne en permanence à ~29 dB. C'est un choix de design Eaton : la technologie Line-Interactive avec AVR génère de la chaleur dans le transformateur même à faible charge. Le ventilateur ne peut pas être retiré (alarme "fan fault" + risque surchauffe transformateur AVR) ni facilement remplacé par un modèle silencieux (connecteur propriétaire Sanyo Denki, résistance 82Ω nécessaire, 24V au lieu de 12V).

La solution retenue : enfermer tout le matériel serveur dans un meuble IKEA Bestå isolé acoustiquement avec de la mousse alvéolée, avec ventilation passive par fentes sur le dessus (côté mur, invisibles de face).

---

## Configuration du coin serveur

- **Box internet** : fixée au mur gauche (reste en place, silencieuse).
- **Caisson Bestå** : au sol, contre le mur. Contient tout le reste.
- Un seul câble Cat6 relie la box au switch dans le caisson.

### Matériel dans le caisson

| Équipement | Dimensions | Niveau |
|---|---|---|
| Eaton Ellipse PRO 1600 | 39×8.2×27.5 cm (vertical) | Bas |
| NAS UGREEN DXP2800 | 23×11×18 cm | Bas |
| MINISFORUM UM880 Plus | 12.7×12.7×5 cm | Haut (sur tablette) |
| Switch TP-Link TL-SG105-M2 | 16×10×3 cm | Haut (sur tablette) |
| Boîtier ORICO | 13×8×3.5 cm | Haut (sur tablette) |

Charge thermique totale : ~103W (UM880 ~35W + NAS ~45W + switch ~8W + box ~15W au mur).

---

## Liste de courses

### IKEA Belgique (ikea.com/be/fr)

| Réf. IKEA | Article | Prix estimé |
|---|---|---|
| 302.458.50 | BESTÅ structure 60×40×64 cm, brun noir | ~30€ |
| 503.522.67 | BESTÅ tablette 56×36 cm, brun noir | ~5€ |
| 204.957.71 | LAPPVIKEN porte 60×64 cm, brun noir | ~15€ |
| 802.348.87 | BESTÅ charnières à fermeture douce × 2 | ~8€ |

### Amazon / magasin bricolage

| Article | Prix estimé |
|---|---|
| Mousse acoustique autocollante alvéolée 50×50cm × 4 plaques (ép. 20-25mm) | ~15-20€ |
| Scie sauteuse ou multitool oscillant (si pas déjà) | — |

**Budget total : ~75-80€**

---

## Schéma d'aménagement

### Vue de dessus — coin serveur

```
┌──────────────────────────────────────────────────────┐
│                    MUR GAUCHE                         │
│                                                       │
│   ┌────┐                                              │
│   │Box │  ←── fixée au mur                            │
│   │int.│                                              │
│   └──┬─┘                                              │
│      │ Cat6                                           │
│      │                                                │
│   ┌──┼────────────────────────────────────────┐       │
│   │  │     IKEA Bestå · 60 × 40 cm            │       │
│   │  │                                         │       │
│   │  │  ┌──────┐ ┌──────────┐ ┌───────┐       │       │
│   │  │  │Eaton │ │   NAS    │ │UM880  │       │       │
│   │  │  │1600  │ │  UGREEN  │ │ Plus  │       │       │
│   │  └──│      │ │          │ │       │       │       │
│   │     │39×8cm│ │ 23×18cm  │ │13×13cm│       │       │
│   │     │      │ │          │ ├───────┘       │       │
│   │     │      │ │          │ ┌───────┐┌─────┐│       │
│   │     │      │ │          │ │Switch ││ORICO││       │
│   │     │      │ │          │ │16×10cm││     ││       │
│   │     └──────┘ └──────────┘ └───────┘└─────┘│       │
│   │                                            │       │
│   │    ▓▓▓ fentes ventilation (côté mur) ▓▓▓   │       │
│   │    ░░░ trou câbles (bas arrière) ░░░       │       │
│   └────────────────────────────────────────────┘       │
│                                                       │
└──────────────────────────────────────────────────────┘
```

### Vue de face — coupe du Bestå

```
         ◄─────────── 60 cm ──────────────►
    ┌──────────────────────────────────────────┐ ▲
    │▒▒▒▒▒▒ mousse dessus ▒▒▒▒▒▒  ▓▓▓ fentes │ │
    │░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│ │
    │░                                        ░│ │
    │░   NIVEAU HAUT (tablette)               ░│ │
    │░                                        ░│ │
    │░  ┌────────┐  ┌─────────┐  ┌──────┐    ░│ │
    │░  │UM880   │  │ Switch  │  │ORICO │    ░│ │
    │░  │ Plus   │  │ TP-Link │  │      │    ░│ │
    │░  └────────┘  └─────────┘  └──────┘    ░│ │
    │░                                        ░│ │
    │░     (espace libre · câbles · air)      ░│ 64 cm
    │░                                        ░│ │
    │░────────────────────────────────────────░│ │
    │░   NIVEAU BAS (sol du meuble)           ░│ │
    │░                                        ░│ │
    │░  ┌──────┐  ┌──────────┐               ░│ │
    │░  │Eaton │  │   NAS    │    ┌────────┐ ░│ │
    │░  │1600  │  │  UGREEN  │    │Câbles  │ ░│ │
    │░  │(vert)│  │          │    │        │ ░│ │
    │░  └──────┘  └──────────┘    └────────┘ ░│ │
    │░                          ░░░ trou ░░░  ░│ │
    │░░░░░░░░░░▒▒▒ mousse fond ▒▒▒░░░░░░░░░░░│ ▼
    └──────────────────────────────────────────┘
    ◄► porte LAPPVIKEN + mousse intérieure

    LÉGENDE :
    ▒▒▒ = mousse acoustique (20-25mm)
    ░░░ = parois du meuble
    ▓▓▓ = fentes ventilation (sortie air chaud)

    FLUX D'AIR :
    ↑ Air chaud sort par les fentes (dessus, côté mur)
    ↓ Air frais entre par le trou câbles (bas, arrière)
```

### Détail du panneau supérieur — position des fentes

```
    ◄─────────── 60 cm ──────────────►
    ┌──────────────────────────────────┐ ▲
    │                                  │ │
    │   mousse acoustique              │ │
    │                                  │ │
    │                                  │ 40 cm
    │                                  │ │
    │   ┌──┐  ┌──┐  ┌──┐              │ │
    │   │  │  │  │  │  │  ← 3 fentes  │ │
    │   │  │  │  │  │  │    2×15 cm   │ │
    └───┴──┴──┴──┴──┴──┴──────────────┘ ▼
         ▲
         │
     côté mur (arrière)
     invisible de face
```

---

## Mode d'emploi — étape par étape

### Étape 1 — Monter le Bestå

1. Assembler la structure BESTÅ 60×40×64 cm selon les instructions IKEA.
2. **Ne pas installer la tablette tout de suite** — on la positionne après la mousse.
3. **Ne pas fixer la porte** — on la colle de mousse d'abord.

### Étape 2 — Découper les fentes de ventilation (dessus)

Les fentes sont positionnées côté mur (les 5 derniers cm de profondeur du panneau du dessus). De face, elles sont invisibles.

1. Retourner le panneau du dessus (ou le faire avant assemblage final, plus facile).
2. Tracer 3 fentes parallèles : chacune 2 cm × 15 cm, espacées de 3 cm entre elles.
3. Les positionner à 2 cm du bord arrière.
4. Découper avec une scie sauteuse ou un multitool oscillant.
5. Poncer les bords pour un rendu propre.

> **Astuce** : percer un trou de départ à chaque extrémité de fente avec une mèche de 8mm, puis relier les trous à la scie sauteuse. Plus propre qu'un départ en plein panneau.

### Étape 3 — Découper le trou de passage câbles (arrière bas)

1. Sur le panneau de fond (l'arrière), tracer un rectangle de 8 × 15 cm dans le coin inférieur droit.
2. Découper à la scie sauteuse.
3. Ce trou sert à la fois au passage des câbles et à l'entrée d'air frais (convection).

**Câbles qui passent par ce trou :**
- Cat6 0,5m → box internet (mur gauche)
- Câble secteur → prise murale (Eaton)
- HDMI 0,9m → Dell U3223QE (KVM vidéo)
- USB-A→C 1m → Dell port upstream #8 (KVM clavier/souris)
- USB Eaton → UM880 Plus (NUT)

### Étape 4 — Coller la mousse acoustique

Coller la mousse acoustique autocollante alvéolée (20-25mm) sur les 5 surfaces intérieures :

1. **Paroi gauche** : une plaque 50×50 cm, découper aux dimensions internes (~58×62 cm approximativement, ajuster au réel).
2. **Paroi droite** : idem.
3. **Panneau de fond (arrière)** : coller autour du trou câbles, ne pas bloquer l'ouverture.
4. **Panneau du dessus** : coller entre les fentes et les bords. Ne pas recouvrir les fentes.
5. **Intérieur de la porte LAPPVIKEN** : coller une plaque découpée aux dimensions de la porte. C'est la surface qui fait face directement à l'UPS — la plus importante pour l'absorption.

> **Conseil** : la mousse se découpe facilement au cutter. Mesurer chaque paroi individuellement car les dimensions internes peuvent varier légèrement après assemblage.

### Étape 5 — Installer la tablette

1. Positionner la tablette BESTÅ à environ 30 cm du sol intérieur du meuble.
2. Elle crée deux niveaux : bas (Eaton + NAS) et haut (UM880 + switch + ORICO).
3. La tablette n'a pas besoin d'être hermétique — les espaces autour permettent la circulation d'air interne.

### Étape 6 — Placer le matériel

**Niveau bas (sol du meuble) :**
- **Eaton Ellipse PRO 1600** : debout (vertical), côté gauche. C'est le plus lourd (~11 kg) et le plus stable en position basse.
- **NAS UGREEN DXP2800** : à côté de l'Eaton, orienté pour que les baies de disques soient accessibles (face avant vers la porte).

**Niveau haut (sur la tablette) :**
- **UM880 Plus** : posé à plat, vers la gauche.
- **Switch TP-Link** : à côté du UM880.
- **Boîtier ORICO** : à côté du switch.
- **Espace restant** : pour le rangement des câbles excédentaires.

### Étape 7 — Câbler

1. **Câbles réseau** : Cat6 du switch vers le trou arrière → vers la box au mur gauche.
2. **Câble réseau interne** : Cat6 court entre le switch et le UM880 (dans le caisson). Cat6 court entre le switch et le NAS (dans le caisson).
3. **Câble USB NUT** : USB-A du UM880 → USB de l'Eaton (dans le caisson, pas besoin de sortir).
4. **Câble secteur Eaton** : sort par le trou arrière → prise murale.
5. **Câbles KVM** : HDMI + USB-A→C sortent par le trou arrière → Dell U3223QE.
6. **Organiser** les câbles avec des attaches velcro pour éviter qu'ils bloquent le flux d'air.

### Étape 8 — Fixer la porte LAPPVIKEN

1. Fixer les 2 charnières à fermeture douce sur la structure.
2. Accrocher la porte LAPPVIKEN (mousse déjà collée à l'intérieur).
3. Régler les charnières pour un alignement propre.
4. La fermeture douce empêche les claquements et assure un joint acoustique.

### Étape 9 — Vérification

1. **Fermer la porte** et écouter : le bruit de l'Eaton doit être considérablement réduit.
2. **Vérifier la ventilation** : poser la main au-dessus des fentes, un léger flux d'air chaud doit être perceptible.
3. **Vérifier la température** après 2-3 heures de fonctionnement :
   ```bash
   ssh homelab
   # Vérifier la température CPU
   sensors  # ou cat /sys/class/thermal/thermal_zone*/temp
   # Vérifier l'UPS
   upsc eaton | grep -i temp
   ```
4. Si la température monte au-dessus de 35°C dans le caisson : ajouter un ventilateur Noctua NF-S12A (120mm, ~17 dB, ~20€) en extraction sur une des fentes du dessus. Avec seulement 103W de charge, ça ne devrait pas être nécessaire.

---

## Résultat attendu

| Mesure | Sans caisson | Avec caisson |
|---|---|---|
| Bruit UPS perçu depuis le bureau | ~29 dB | ~10-14 dB (quasi-inaudible) |
| Température interne caisson | — | +5-8°C au-dessus de l'ambiance |
| Accès au matériel | Libre | Ouvrir la porte LAPPVIKEN |
| Esthétique | Matériel visible | Meuble discret brun noir |

---

## Masquer les fentes (optionnel)

Si les fentes sont visibles malgré leur position côté mur, poser un petit plateau, un livre ou un objet décoratif sur le dessus du Bestå avec 1-2 cm de surélévation (deux petites cales en feutre sous l'objet). L'air circule entre l'objet et le dessus du meuble, les fentes sont masquées et la ventilation fonctionne toujours.

---

## Entretien

- **Mensuel** : ouvrir la porte, vérifier qu'aucun câble ne bloque les fentes ou le trou de ventilation.
- **Trimestriel** : aspirer la poussière accumulée sur la mousse et les fentes.
- **Annuel** : vérifier l'état de la mousse (elle peut se dégrader au bout de 3-5 ans sous l'effet de la chaleur).
