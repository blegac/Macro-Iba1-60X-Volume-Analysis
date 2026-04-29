# Iba1 60X Volume Analysis

## Description

This ImageJ/Fiji macro automates the 3D volumetric analysis of microglial cells labeled with **Iba1** from confocal images acquired at 60× magnification. It batch-processes all `.oif` files (Olympus format) found in a selected folder, applies image preprocessing, detects 3D objects, and exports measurements to CSV files.

The macro is **generic**: the channel containing Iba1 is selected by the user at startup, making it compatible with different multichannel acquisition configurations.

---

## Requirements

### Software
- [Fiji / ImageJ](https://fiji.sc/) (latest version recommended)

### Required plugins
| Plugin | Purpose |
|---|---|
| **Bio-Formats Importer** | Opening `.oif` files |
| **3D Objects Counter on GPU (CLIJx, Experimental)** | GPU-accelerated 3D object detection |
| **3D Objects Counter** (classic) | Fallback method if GPU is unavailable |
| **3D Manager** (`mcib3d-plugins`) | 3D ROI management, measurement and export |
| **Results to Excel** | Export results directly to `.xlsx` from Fiji |

---

## Plugin Installation

All plugins are installed through Fiji's update manager:

1. Go to **Help → Update Fiji**
2. Click **Manage Update Sites**
3. Check the following update sites in the list:
   - **Bio-Formats** *(included by default in Fiji, enable if missing)*
   - **clij** and **clij2** *(both are required for GPU support)*
   - **3D ImageJ Suite** *(for the 3D Manager)*
   - **ResultsToExcel**
4. Click **Close** then **Apply Changes**
5. Restart Fiji

> ⚠️ CLIJx requires an OpenCL-compatible graphics card. If GPU detection fails, use the classic fallback (select "No" in the macro dialog).

---

## Expected Data Format

- **`.oif`** files (Olympus Image Format) gathered in a single folder
- Multichannel images (number of channels and Iba1 channel position are variable and configured at startup)

---

## Output Structure

The macro automatically creates a results folder inside the selected directory, named using the following convention:

```
YYYY_MM_DD_analysis_<FolderName>/
├── Images/
│   ├── <file>_EnhancedStack.tif      # Contrast-enhanced stack (red LUT)
│   ├── <file>_Preprocessed.tif       # Preprocessed stack (8-bit, Gaussian blur)
│   └── <file>_ObjectsMapRaw.tif      # Raw detected objects map
├── ROI/
│   └── <file>_Microglia_ROIs.zip     # 3D ROIs (3D Manager format)
└── Measurements/
    ├── <file>_ResultsMeasure.csv     # 3D morphological measurements (volume, surface…)
    └── <file>_ResultsQuantif.csv     # Intensity quantification per object
```

---

## Analysis Pipeline (step by step)

### 1. Folder selection
The user selects the folder containing the `.oif` files. Results will be saved in the same folder.

### 2. Channel configuration
A dialog appears **once** before processing begins:

| Field | Description | Example |
|---|---|---|
| Total number of channels | Number of channels in the images | `3` |
| Iba1 channel number | Position of the Iba1 channel (C1, C2, C3…) | `2` |

All channels other than the selected one are automatically closed after each file is opened.

### 3. Opening and preprocessing (per file)
- Opening via **Bio-Formats** without auto-scaling
- Spatial calibration: **4.8309 pixels = 1 µm**
- Automatic closing of all channels except the Iba1 channel
- Red LUT applied to the Iba1 channel
- **Despeckle** (noise reduction) on the entire stack
- Contrast enhancement (0.35% saturated pixels)
- Conversion to **8-bit**
- **Gaussian blur** (σ = 1) on the stack

### 4. 3D object detection
- **3D Objects Counter GPU (CLIJx)** is run first
- ⚠️ **Interactive pause**: the user reviews the objects map and accepts or rejects the GPU results
  - If **accepted** → processing continues with the GPU map
  - If **rejected** → the macro reruns the **classic 3D Objects Counter** as a replacement

### 5. ROI management with 3D Manager
- Detected objects are loaded into the **3D Manager**
- ⚠️ **Interactive pause**: the user can review and manually edit ROIs
  - To see the ROIs overlaid on the image, click **"Live ROIs: ON"**
  - Verify each ROI individually:
    - Delete irrelevant ROIs using the **"Delete"** button
    - Merge ROIs belonging to the same cell using the **"Merge"** button
  - Once done, click **"OK"** in the "Verify ROIs" pop-up window
- All objects are labeled `"Microglia"`
- ROIs are saved as a `.zip` file

### 6. Measurement export
- **`Manager3D_Measure()`** → 3D morphology (volume, surface area, compactness, etc.)
- **`Manager3D_Quantif()`** → intensity quantification per object
- Results exported as `.csv` files in the `Measurements/` folder

### 7. Cleanup and iteration
- 3D Manager is reset
- All image windows are closed
- Memory garbage collection
- Processing moves to the next `.oif` file

---

## User Interactions

This macro is **semi-automatic** and requires the following interactions:

| When | Frequency | Action required |
|---|---|---|
| At startup | Once | Select folder, enter number of channels and Iba1 channel |
| After GPU detection | Per file | Review objects map, then choose "Yes" (GPU) or "No" (classic) |
| After 3D Manager initialization | Per file | Verify/correct ROIs, then click OK |

---

## Parameters to Check / Adjust

| Parameter | Line | Current value | Change if… |
|---|---|---|---|
| Spatial calibration | 42 | `4.8309 px = 1 µm` | Different objective or camera |
| Gaussian blur sigma | 74 | `1` | Different noise level |
| Contrast saturation | 66 | `0.35%` | Under- or over-exposed images |

---

## Notes

- The macro only processes `.oif` files located at the root of the selected folder (subfolders are not scanned).
- If a GPU error occurs, make sure the **CLIJ/CLIJx** plugins are properly installed and that the graphics card is OpenCL-compatible.
