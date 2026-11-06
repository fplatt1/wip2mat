# wip2mat

MATLAB function that exports WITec Project files (`.wip`) to `.mat` files
(plus PNG previews and the measurement information as text), so the data can
be used in Python, MATLAB or any other analysis tool without the WITec software.

Works for spectral maps and single spectra (Raman, photoluminescence) as well
as images and bitmaps stored in the project.

## Requirements

- MATLAB (developed with R2026a on Fedora Linux)
- [WITio](https://github.com/jtholmi/WITio) by Joonas T. Holmi (BSD 3-Clause).
  Not included in this repository, install it separately.

## Usage

```matlab
wip2mat
```

1. On the first run you are asked for the WITio folder (remembered afterwards).
2. Select a `.wip` file.
3. WITio may open its Project Manager. Select **all** objects you want to
   export before closing it, only selected objects are returned.
4. For each spectral map you confirm the unit of the spectral axis
   (nm / eV / rel. 1/cm) and optionally enter the laser wavelength in nm.

The output is written next to the `.wip` file into `<name>_export/`.

## Output

| Object type | Files |
|---|---|
| `TDGraph` (spectra) | `.mat` with `spectra`, `axisRaw`, `axisUnit`, `wavelength_nm`, `energy_eV`, `raman_shift`, `laser_nm`, `info` |
| `TDImage`, `TDBitmap` | `.mat` with `img`, `info`, and a `.png` preview |
| `TDText` | `.txt` with the measurement information (laser, grating, scan size, ...) |

Files are numbered and named after the object, so several measurements in one
project do not overwrite each other. `.mat` files are saved with `-v7`.

`info` only contains simple metadata (numbers, text, structs); WITio objects
are not saved because they cannot be loaded without WITio.

`raman_shift` is only filled if the laser wavelength is given (or the axis is
already in rel. 1/cm). For photoluminescence data leave the laser field empty
and use `wavelength_nm` or `energy_eV`.

## Loading in Python

```python
from scipy.io import loadmat

d = loadmat("01_TDGraph_....mat")
spectra = d["spectra"]                      # e.g. (80, 80, 1024)
x = d["wavelength_nm"].squeeze()            # or "raman_shift"
X = spectra.reshape(-1, spectra.shape[-1])  # (n_spectra, n_points)
```

## Known limitations

- `WITio.obj.wid/interpret_Graph` returns the axis values without a unit, so
  the unit is guessed from the value range and has to be confirmed in a dialog.
- The pixel order of `spectra` (rows/columns) should be checked against a
  WITec image of the same map before further analysis.
- Developed against one WITio version, other versions may use different
  function names.
- On Wayland, MATLAB may need `QT_QPA_PLATFORM=xcb matlab`.
- File dialogs require the MATLAB desktop (no `-nodesktop`).

## License

MIT, see `LICENSE`. WITio is licensed separately (BSD 3-Clause).
