# README — Iba1 60X Volume Analysis

## Description

Cette macro ImageJ/Fiji automatise l'analyse volumétrique 3D de cellules microgliales marquées à l'**Iba1** à partir d'images confocales au grossissement 60×. Elle traite en lot tous les fichiers `.oif` (format Olympus) présents dans un dossier, applique un prétraitement d'image, détecte les objets 3D et exporte les mesures dans des fichiers CSV.

La macro est **générique** : le canal contenant Iba1 est sélectionné par l'utilisateur au démarrage, ce qui la rend compatible avec différentes configurations d'acquisition multicanaux.

---

## Prérequis

### Logiciel
- [Fiji / ImageJ](https://fiji.sc/) (version récente recommandée)

### Plugins requis
| Plugin | Utilisation |
|---|---|
| **Bio-Formats Importer** | Ouverture des fichiers `.oif` |
| **3D Objects Counter on GPU (CLIJx, Experimental)** | Comptage d'objets 3D accéléré GPU |
| **3D Objects Counter** (classique) | Méthode de fallback si GPU insuffisant |
| **3D Manager** (`mcib3d-plugins`) | Gestion, mesure et export des ROIs 3D |
| **Results to Excel** | Export des résultats directement en fichier `.xlsx` depuis Fiji |

---

## Installation des plugins

Tous les plugins s'installent via le gestionnaire de mises à jour de Fiji :

1. Aller dans **Help → Update Fiji**
2. Cliquer sur **Manage Update Sites**
3. Cocher les update sites suivants dans la liste :
   - **Bio-Formats** *(inclus par défaut dans Fiji, à activer si absent)*
   - **clij** et **clij2** *(les deux sont nécessaires pour le GPU)*
   - **3D ImageJ Suite** *(pour le 3D Manager)*
   - **ResultsToExcel**
4. Cliquer **Close** puis **Apply Changes**
5. Redémarrer Fiji

> ⚠️ CLIJx nécessite une carte graphique compatible OpenCL. En cas de problème, utiliser le fallback classique (l'option "No" dans le dialogue de la macro).

---

## Format de données attendu

- Fichiers **`.oif`** (Olympus Image Format) regroupés dans un seul dossier
- Images multicanaux (nombre de canaux et position d'Iba1 variables, configurables au démarrage)

---

## Structure des sorties

La macro crée automatiquement un dossier de résultats dans le répertoire sélectionné, nommé selon la convention :

```
YYYY_MM_DD_analysis_<NomDuDossier>/
├── Images/
│   ├── <fichier>_EnhancedStack.tif      # Stack avec contraste amélioré (LUT rouge)
│   ├── <fichier>_Preprocessed.tif       # Stack prétraité (8-bit, flou gaussien)
│   └── <fichier>_ObjectsMapRaw.tif      # Carte des objets détectés
├── ROI/
│   └── <fichier>_Microglia_ROIs.zip     # ROIs 3D (format 3D Manager)
└── Measurements/
    ├── <fichier>_ResultsMeasure.csv     # Mesures morphologiques (volume, surface…)
    └── <fichier>_ResultsQuantif.csv     # Quantification d'intensité par objet
```

---

## Pipeline d'analyse (étape par étape)

### 1. Sélection du dossier
L'utilisateur choisit le dossier contenant les fichiers `.oif`. Ce même dossier recevra les résultats.

### 2. Configuration des canaux
Un dialogue s'affiche **une seule fois** avant le début du traitement :

| Champ | Description | Exemple |
|---|---|---|
| Nombre total de canaux | Nombre de canaux dans les images | `3` |
| Numéro du canal Iba1 | Position du canal Iba1 (C1, C2, C3…) | `2` |

Tous les canaux autres que celui sélectionné sont fermés automatiquement après l'ouverture de chaque fichier.

### 3. Ouverture et prétraitement (par fichier)
- Ouverture via **Bio-Formats** sans mise à l'échelle automatique
- Calibration spatiale : **4.8309 pixels = 1 µm**
- Fermeture automatique de tous les canaux sauf le canal Iba1
- Application de la LUT rouge sur le canal Iba1
- **Despeckle** (réduction du bruit) sur le stack entier
- Amélioration du contraste (0,35 % de pixels saturés)
- Conversion en **8-bit**
- **Flou gaussien** (σ = 1) sur le stack

### 4. Détection des objets 3D
- Lancement de **3D Objects Counter GPU (CLIJx)** en premier
- ⚠️ **Pause interactive** : l'utilisateur examine la carte d'objets et valide ou rejette les résultats GPU
  - Si **accepté** → on continue avec la carte GPU
  - Si **rejeté** → la macro relance le **3D Objects Counter classique** en remplacement

### 5. Gestion des ROIs avec le 3D Manager
- Chargement des objets détectés dans le **3D Manager**
- ⚠️ **Pause interactive** : l'utilisateur peut vérifier et modifier les ROIs manuellement
- Attribution du label `"Microglia"` à tous les objets
- Sauvegarde des ROIs en `.zip`

### 6. Export des mesures
- **`Manager3D_Measure()`** → morphologie 3D (volume, surface, compacité, etc.)
- **`Manager3D_Quantif()`** → quantification d'intensité par objet
- Export en `.csv` dans le dossier `Measurements/`

### 7. Nettoyage et itération
- Réinitialisation du 3D Manager
- Fermeture de toutes les fenêtres d'images
- Garbage collection mémoire
- Passage au fichier `.oif` suivant

---

## Interactions utilisateur

Cette macro est **semi-automatique** et nécessite les interventions suivantes :

| Moment | Fréquence | Action requise |
|---|---|---|
| Au démarrage | Une seule fois | Sélectionner le dossier, renseigner le nombre de canaux et le canal Iba1 |
| Après la détection GPU | Par fichier | Examiner la carte d'objets, puis choisir "Yes" (GPU) ou "No" (classique) |
| Après l'initialisation du 3D Manager | Par fichier | Vérifier/corriger les ROIs, puis cliquer OK |

---

## Paramètres à vérifier/adapter

| Paramètre | Ligne | Valeur actuelle | À modifier si… |
|---|---|---|---|
| Calibration spatiale | 42 | `4.8309 px = 1 µm` | Objectif ou caméra différents |
| Sigma du flou gaussien | 74 | `1` | Niveau de bruit différent |
| Saturation contraste | 66 | `0.35%` | Images sous/sur-exposées |

---

## Notes

- La macro ne traite que les fichiers `.oif` à la racine du dossier sélectionné (pas de sous-dossiers).
- En cas d'erreur GPU, s'assurer que les plugins **CLIJ/CLIJx** sont bien installés et que la carte graphique est compatible.
