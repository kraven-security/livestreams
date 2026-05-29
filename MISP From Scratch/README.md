# MISP Jupyter Notebook Example

Example Jupyter notebook accompanying the [**Kraven Security MISP YouTube livestream series**](https://www.youtube.com/playlist?list=PLtrYdFbyvu7xF2czFVtXOu8yMwQKP23FJ).

The notebook (`misp-api-livestream.ipynb`) walks through the full threat-intel lifecycle using **PyMISP** — the official Python wrapper for the MISP REST API:

- **Search & Read** — query events and attributes, export to pandas DataFrames
- **Write** — create structured events with attributes, objects, and galaxy tags
- **Export & Integrate** — render IOCs as Suricata rules, CSV, STIX2, and more in a single API call
- **Automate** — wrap the pipeline into a scheduled, unattended feed
- **Appendix** — raw `requests` calls showing exactly what PyMISP does under the hood

## Requirements

```bash
pip install pymisp pandas requests
```

A local MISP instance is required. Set your API key as an environment variable before launching Jupyter:

```bash
export MISP_KEY="your-api-key"   # macOS/Linux
# setx MISP_KEY "your-api-key"   # Windows (new terminal after)
jupyter notebook misp-api-livestream.ipynb
```
