# Minimi Web Calibrator (Local Static Tool)

`tools/minimi-calibrator/` contains a standalone browser tool to calibrate Minimi layer alignment.

## 5-step quick usage

1. Open terminal and move to the tool directory:
   ```bash
   cd /Users/kimhyunhomacmini/.openclaw/workspace/kid_econ_mvp/tools/minimi-calibrator
   ```
2. Start a local static server:
   ```bash
   python3 -m http.server 8081
   ```
3. Open the calibrator in your browser:
   ```
   http://localhost:8081/
   ```
4. Pick hair/top/accessory presets, then adjust by dragging each layer or using sliders (`hairY`, `topY`, `topScale`, `accessoryY`).
5. Copy JSON with **Copy JSON** or save it with **Download JSON**, then paste the values into app calibration config.

## Output JSON shape

The tool always outputs this exact key shape:

```json
{
  "hairY": 0,
  "topY": 0,
  "topScale": 1,
  "accessoryY": 0
}
```
