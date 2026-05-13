# USBGate - Personne 4 : Interface, Import, Rapport et Restauration

## Fonctions developpees (6)

### `print_risk(level, name)`
Affiche un fichier avec une couleur selon son niveau de risque.
- **SAFE** : vert `[SAFE   ] nom_fichier`
- **MEDIUM** : jaune `[MEDIUM ] nom_fichier`
- **HIGH** : rouge `[HIGH   ] nom_fichier`

### `show_summary()`
Tableau recapitulatif apres le scan.
- Affiche les compteurs `COUNT_SAFE`, `COUNT_MEDIUM`, `COUNT_HIGH`
- Enregistre le resume dans le log via `log_info()`
- Alignement automatique quel que soit le nombre de chiffres

### `interactive_menu()`
Menu interactif avec 3 choix :
1. **Copier les fichiers SAFE** → appelle `import_safe_files()`
2. **Generer un rapport** → appelle `generate_report()`
3. **Quitter** → retourne au programme principal (demontage automatique via `trap`)

### `import_safe_files()`
Copie les fichiers classes SAFE vers `~/Downloads/SecureImport/`.
- Cree le dossier de destination si necessaire (`mkdir -p`)
- Parcourt les fichiers de la cle avec `find -print0`
- Filtre avec `classify_file()` (P1)
- Copie avec `cp`

### `generate_report()`
Cree un rapport texte detaille compresse en `.gz`.
- Nom unique base sur la date : `/tmp/usbgate_report_AAAAMMJJ_HHMMSS.txt`
- Utilise `tee` pour ecrire simultanement terminal + fichier
- Liste tous les fichiers tries avec leur classification
- Compresse avec `gzip`

### `restore_defaults()`
Option `-r` : restaure les parametres par defaut.
- **Root uniquement** : verification via `id -u` (code erreur 106 si refuse)
- Demonte la cle USB
- Vide le fichier de log
- Supprime le dossier SecureImport
- Supprime les fichiers temporaires

## Concepts Shell utilises

| Concept | Fonction(s) |
|---|---|
| `cp`, `mkdir`, `rm`, `touch` | `import_safe_files()`, `restore_defaults()` |
| `find` | `import_safe_files()`, `generate_report()` |
| `gzip` | `generate_report()` |
| `tee`, `sort` | `generate_report()` |
| `id -u` | `restore_defaults()` |
| Boucle `while` | `import_safe_files()` |
| Condition `case` | `print_risk()`, `interactive_menu()` |
| Condition `if` | `import_safe_files()`, `restore_defaults()` |
| Variables d'environnement `$HOME` | `SAFE_DEST` |
| Couleurs ANSI | `print_risk()`, `show_summary()` |

## Dependances

- `classify_file()` : fonction de la Personne 1
- `log_info()`, `log_error()` : fonctions de la Personne 3
- `MOUNT_POINT`, `COUNT_*` : variables globales definies par P2/P3

## Fichiers

- `ui.functions.sh` : contient les 6 fonctions (230 lignes)
