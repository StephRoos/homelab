---
date: 2026-07-07
type: handoff
tags: [homelab, google-exit, migration, immich, infomaniak, nextcloud, backup]
status: in-progress
project: google-exit
audience: AI agent / future self — self-contained handoff
---

# Google Exit — Handoff complet (2026-07-07)

> Document de **reprise autoportant**. Objectif : permettre à un autre agent IA (ou à moi-même
> depuis une autre machine) de reprendre la sortie de Google sans contexte préalable.
> Plan directeur historique : `plan-deconstruire-google.md`. Ce document est l'**état réel au 2026-07-07**.

## 0. Principe de travail (NON négociable)

**Vérifier avant de détruire.** Aucune suppression irréversible (Google Photos, Gmail, Drive, comptes)
sans : (1) backup vérifié bout-en-bout, (2) validation visuelle humaine. Gap analysis systématique.
On garde toujours une 2ᵉ copie tant que la 1ʳᵉ n'est pas prouvée complète.

## 1. Infrastructure de référence

| Élément | Valeur |
|---|---|
| **UM880** (serveur principal) | `192.168.129.10`, alias SSH `homelab` (user `steph`), Ubuntu 24.04, Docker |
| **NAS Ugreen** | `192.168.129.21`, user SSH `Steph`, exporte NFS vers l'UM880 |
| Montages NFS sur UM880 | `/mnt/nas/{nextcloud,appdata,backups,timemachine,nextcloud-personal}` |
| **Immich** (lib LOCALE, pas NFS) | `/mnt/nas/immich` (disque local UM880), 111 Go |
| Backups → Backblaze B2 | remote rclone `b2:`, bucket `homelab-backup-anthemion`, cron `/etc/cron.d/b2-backup` 04:00 |
| Cloudflare | DNS de `stephaneroos.com` ET `anthemion.dev` (NS kenia/sid.ns.cloudflare.com) |

### Domaines & services
- `photos.stephaneroos.com` → Immich (Caddy → host :2283)
- `cloud.stephaneroos.com` → Nextcloud **perso** (stack non-AIO, host :11002, conteneur `nextcloud-personal`, user Nextcloud `steph`, data `/mnt/nas/nextcloud-personal`)
- `cloud.anthemion.dev` → Nextcloud **AIO** (instance SÉPARÉE, ne pas confondre ; sert du courrier/fichiers pro)
- Mail pro `anthemion.dev` → **OVH** (ladtc.be) — NE PAS TOUCHER pour l'instant
- Mail perso `stephaneroos.com` → **Infomaniak** (voir §3)

## 2. Migration Photos Google → Immich — ✅ TERMINÉE

- **État final Immich : 25 624 assets** (23 243 images + 2 381 vidéos), 0 erreur, 0 pending.
- Source : 2 Takeout frais (`takeout-20260629T201901Z-3-001.zip` 50 Go + `-002.zip` 38 Go).
- Import : **immich-go 0.32** en 2 passages (le 2ᵉ avec `--include-unmatched` pour 438 fichiers sans JSON).
  - Commande type (HOME dédié pour éviter la perte au reboot de `/tmp`) :
    ```bash
    ssh homelab
    cd /home/steph/google-takeout && export HOME=/home/steph/google-takeout/igo-home
    immich-go upload from-google-photos -s http://localhost:2283 -k <API_KEY> [--include-unmatched] <zip1> <zip2>
    ```
  - **Clé API Immich** : régénérée dans l'UI (profil → API Keys). L'ancienne vivait dans `/tmp` → perdue au reboot. Ne PAS la stocker dans `/tmp`.
- **Gap analysis** (méthode, à réutiliser) : comparer comptage par année Takeout vs DB Immich.
  - DB Immich : conteneur `immich-postgres`, base `immich`, **table `asset`** (singulier, PAS `assets`), user `immich` (trust local, pas de mot de passe). Colonne date = `localDateTime`, `type` IN (IMAGE, VIDEO), filtrer `deletedAt IS NULL`.
  - Le comptage par année diverge (Live Photos = Google compte 2 fichiers / Immich stacke ; date EXIF vs dossier Google). **L'autorité = le rapport immich-go (matching par HASH), pas le comptage par date.** `Pending: 0` = tout Google couvert.
- **Archive froide** : les 2 zips (88 Go) sont sur NAS `/mnt/nas/backups/google-photos-takeout-2026-06/` (→ B2). Originaux UM880 supprimés.
- **Reste à faire** : spot-check visuel humain (ouvrir 2008 et 2016 dans Immich). Historiquement 2008 était absent, 2016 partiel — désormais comblés (2008 : 0→50, 2016 : 64→583).

## 3. Migration Email perso → Infomaniak — ✅ TERMINÉE

- Nouvelle adresse : **`steph@stephaneroos.com`** (Infomaniak kSuite gratuit, ~15 Go — suffit car le mail Gmail ne fait que **~100 Mo** ; le "39 Go" affiché par Google = stockage MUTUALISÉ Gmail+Drive+Photos).
- **DNS posés dans Cloudflare** (zone `stephaneroos.com`, id `33e43f98ab27a478849eb3de8bc8771b`) :
  | Type | Name | Valeur | Note |
  |---|---|---|---|
  | MX | `@` | `mta-gw.infomaniak.ch` (prio 5) | |
  | TXT (SPF) | `@` | `v=spf1 include:spf.infomaniak.ch -all` | remplace l'ancien `a:my.stephaneroos.com` (Cloudron mort) |
  | TXT (DKIM) | `20260630._domainkey` | `v=DKIM1; t=s; p=MIIB…AQAB` | |
  | CNAME | `autoconfig` / `autodiscover` | `infomaniak.com` | **DNS only (nuage gris)** |
  | TXT (DMARC) | `_dmarc` | `v=DMARC1; p=reject; pct=100` | déjà présent, conservé |
  - Mail legacy sur sous-domaines **non touché** : Mailgun (`mail.stephaneroos.com`), Cloudron (`my.stephaneroos.com`, IP Hetzner).
- **Import historique** : fait via **OAuth Google** (pas IMAP/app-password) — un **one-shot** "Completed", NE synchronise PAS en continu.
- **Courrier futur** : **transfert automatique côté Gmail** (Paramètres → Transfert et POP/IMAP → "Transférer une copie" + Enregistrer). ✅ **actif et testé** (mail de test arrivé dans Infomaniak). Rattrapage des mails du 30/06→07/07 = relancer un import ponctuel Infomaniak (dédup par message-id).
- **Contacts** : 347 importés (CardDAV/vCard). Archive : NAS `/mnt/nas/backups/google-contacts-2026-06/contacts.vcf`.
- **Agenda** : repart **vierge** (choix utilisateur, pas de migration CalDAV).
- **Archive mail froide** : Takeout Mail (`.mbox` 204 Mo) sur NAS `/mnt/nas/backups/google-mail-takeout-2026-06/`.

### ⚠️ Réglages compte Infomaniak — À FAIRE
- L'**email de connexion/récupération** du compte Infomaniak est encore `stephaneroos@gmail.com`.
- **NE JAMAIS** le mettre à `steph@stephaneroos.com` (dépendance circulaire = lockout si perte d'accès).
- Recommandation : le passer à l'adresse pro **`@anthemion.dev`** (indépendante, non-Google) OU laisser gmail comme filet.

### Config Pixel 8 — état réel (2026-07-07)
- **Mail : ✅ réglé** via l'app **Infomaniak Mail** (Android). C'est l'essentiel du besoin quotidien.
- **Agenda + Contacts mobile : ⚠️ NON résolu, parké par choix utilisateur.** Constat honnête :
  - Il n'existe **pas** d'app Infomaniak « kSuite » unifiée ni de calendrier/contacts dans l'app Mail.
  - La **seule** synchro native agenda/contacts sur Android = **DAVx5** (CalDAV/CardDAV). Testé le 07/07, jugé trop peu ergonomique → **abandonné par Stéphane (déçu)**. Ne pas reproposer sans qu'il le redemande.
  - Détail technique si repris un jour : URL `https://sync.infomaniak.com`, **user = `stephaneroos@gmail.com`** (login COMPTE, propriétaire agenda+contacts — PAS la boîte `steph@`), mot de passe du compte. L'échec observé = collections CardDAV/CalDAV non listées (bouton ⟳ « rafraîchir » + cocher le carnet ; possible bridage du my kSuite gratuit).
- **Contours de repli** (non faits) : agenda vide → consultable sur `calendar.infomaniak.com` ; contacts pour le dialer → import du `contacts.vcf` (déjà sur NAS/Mac) dans un compte "local/de l'appareil".
- Identités Infomaniak à ne pas confondre : **login/compte = `stephaneroos@gmail.com`** ; **boîte mail = `steph@stephaneroos.com`**.

## 4. Google Drive — ✅ RAPATRIÉ (ciblé)

- Stratégie : **tri manuel ciblé**, le reste abandonné (beaucoup de contenu "dev" déjà dans SecondBrain).
- Récupéré : dossier `Backup Google Drive` (2457 fichiers, 604 Mo) = coffre `Documents de référence` (identité, CV, diplômes, fiscalité, maison, famille) + backup domotique `Domintell2`.
- **Archive froide** : NAS `/mnt/nas/backups/google-drive-2026-07/Backup Google Drive/` (→ B2). AppleDouble `._*` et `.DS_Store` nettoyés.
- **Copie vivante Nextcloud** : `Documents de référence` (1628 fichiers) poussé dans `cloud.stephaneroos.com` (user steph). `Domintell2` (AppImage 558 Mo) reste archive froide seulement.
  - ⚠️ **Piège NFD** : les noms macOS sont en Unicode **NFD** (accents décomposés) → Nextcloud rejette ("incompatible encoding"). **Normaliser en NFC avant `occ files:scan`**. Script utilisé (host, sudo) :
    ```python
    import os, sys, unicodedata
    root = sys.argv[1]
    for dp, dn, fn in os.walk(root, topdown=False):
        for name in fn + dn:
            nfc = unicodedata.normalize('NFC', name)
            if nfc != name: os.rename(os.path.join(dp,name), os.path.join(dp,nfc))
    ```
  - Puis : `sudo chown -R 33:33 <dir>` (www-data = uid 33) et `docker exec -u www-data nextcloud-personal php occ files:scan steph`.

## 5. Backup du homelab (Immich) — 🔄 EN COURS (prérequis suppression Google Photos)

**Problème résolu** : la lib Immich (111 Go) était sur un **disque local UM880 unique, SANS backup** (le B2 ne couvrait que nextcloud/appdata/backups). SPOF critique : Google Photos était encore la seule 2ᵉ copie.

**Solution déployée** (commit `3df9148`, script versionné `scripts/um880/b2-backup.sh`) :
- Dump PostgreSQL Immich → `/mnt/nas/backups/immich-db/` (rétention 7, ~30 Mo) = albums/dates/visages/stacks.
- rclone sync des **originaux** `/mnt/nas/immich/library` → `b2:homelab-backup-anthemion/immich-library`.
- **Exclusions** `thumbs/**` + `encoded-video/**` (dérivables régénérables, ~27 Go économisés). Volume backup ≈ 84 Go (`library/upload`).
- Intégré au cron existant `/etc/cron.d/b2-backup` (04:00 quotidien, root).

**✅ 1er run TERMINÉ et VÉRIFIÉ (2026-07-07 21:52)** : `immich-library` sur B2 = **83,57 Go / 50 049 fichiers = IDENTIQUE à la source locale** (hors dérivables). Dump DB présent (`immich-20260707-201840.sql.gz`, 30 Mo). Log `B2 backup complete` (durée 1h33). Le cron 04:00 rejoue en incrémental chaque nuit. **SPOF fermé.**
```bash
ssh homelab 'sudo rclone size b2:homelab-backup-anthemion/immich-library'   # ≈ 83.57 GiB
ssh homelab 'sudo tail -5 /var/log/rclone-b2-backup.log'                     # "B2 backup complete"
```

**Auto-upload mobile Immich : ✅ CONFIRMÉ (2026-07-07)** — test photo live remonté dans Immich (+ assets 04-05/07 présents). Le relais Immich fonctionne.

**Backup Google Photos (Pixel) : coupé le 2026-07-07** (réversible, non destructif). La bibliothèque Google Photos EXISTANTE reste intacte = filet de sécurité jusqu'au spot-check + décision de suppression.

## 6. CE QUI RESTE À FAIRE (ordonné)

1. **[bloquant] Attendre la fin + VÉRIFIER le 1er backup Immich** (§5). Confirmer `immich-library` ≈ 84 Go sur B2 et présence d'un dump dans `/mnt/nas/backups/immich-db/`.
2. ~~**Spot-check visuel Immich** 2008/2016~~ → ✅ **FAIT le 2026-07-07**. Migration photos **fonctionnellement complète**.
3. **Config Pixel 8** : Infomaniak Mail + DAVx5 (contacts/agenda). Voir §3.
4. **Compte Infomaniak** : changer l'email de récupération (→ `@anthemion.dev`, PAS la boîte perso). Voir §3.
5. **Rattrapage mails 30/06→07/07** : import ponctuel Infomaniak depuis Gmail.
6. **[destructif, seulement après 1+2 OK]** Couper le **backup Google Photos** sur le Pixel (garder l'historique en ligne d'abord). Valider le test d'auto-upload Immich en arrière-plan avant.
7. **[destructif, très encadré — EN RÉTENTION jusqu'à ~2026-08-07]** Supprimer la bibliothèque **Google Photos**. Décision (07/07) : NE PAS supprimer tout de suite malgré spot-check OK — garder Google ~1 mois comme 3ᵉ copie le temps que le nouveau setup (auto-upload Immich + backup B2 nocturne) fasse ses preuves. Coût de garder = 0 (backup déjà coupé, biblio figée) ; coût de supprimer trop tôt = irréversible. **Ne JAMAIS supprimer l'adresse Gmail** (boîte de transfert ; comptes legacy liés).
8. **Plus tard** : migration mail **`anthemion.dev` OVH → Infomaniak** (avec récup du courrier ladtc.be).

## 7. Pièges rencontrés (mémo)

- **NAS "unreachable" dans le monitoring ≠ panne** : une MAJ firmware **UGOS** efface la clé SSH de l'UM880 dans `~/.ssh/authorized_keys` du NAS. Fix : réinstaller la pubkey + `chmod 700 ~ ~/.ssh` sur le NAS.
- **Faux positifs température** dans `homelab-diagnostic.sh` : seuils rebasés (NVMe sur Composite/80°C, NAS sda USB 65°C).
- **rsync macOS = version antique 2.6.9** : pas de `--info`/`-s`. Pour transférer depuis le Mac, utiliser `tar cf - ... | ssh homelab 'tar xf -'` (gère les espaces/accents).
- **~/Downloads du Mac verrouillé (TCC)** pour l'outil : déposer les fichiers dans `~/gphotos-takeout` (accessible) via le Finder.
- **Stockage Google mutualisé** : ne pas confondre taille Gmail avec le quota global (Gmail+Drive+Photos).
- **Encodage NFD macOS** rejeté par Nextcloud → normaliser NFC (§4).

## 8. Mémoires liées (auto-memory de l'agent)
`migration-photos-immich`, `google-exit-status`, `email-migration-infomaniak`, `homelab-nextcloud-personal`, `homelab-routing-architecture`, `nas-ssh-key-wiped-ugos`, `feedback-verify-before-destroy`.
