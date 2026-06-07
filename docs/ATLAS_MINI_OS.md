# SevenOS Atlas Mini OS

Atlas is the SevenOS knowledge mini OS. It owns documents, scans, OCR, maps,
references, archives and calm research workflows.

## Boundary

Atlas should not become a cultural or storytelling environment. Baobab owns
African cultures, oral memory, heritage packs and community transmission.
Atlas owns general knowledge handling:

- PDFs, ebooks, office files and annotations.
- Scan intake and OCR.
- Local document search.
- Maps, GPX, routes and geographic exploration.
- Research folders, references and exports.

## Public Contract

The user-facing entry point is:

```bash
seven atlas
```

It reports:

- required and optional package readiness;
- private rootfs state;
- Atlas workspace state;
- app readiness;
- next safe actions.

The stable workspace is:

```text
~/Atlas/
├── Documents
├── Scans
├── Maps
├── References
├── Research
└── Exports
```

Create it with:

```bash
seven atlas workspace
```

## Workflows

Open the center:

```bash
seven atlas open
```

Open folders:

```bash
seven atlas documents
seven atlas scans
seven atlas maps
seven atlas references
seven atlas research
seven atlas exports
```

Search locally:

```bash
seven atlas search
seven atlas search "invoice june"
```

Run OCR:

```bash
seven atlas ocr
seven atlas ocr ~/Atlas/Scans/document.pdf
```

## Installation Policy

Required packages form the stable Atlas baseline:

```bash
seven atlas install --yes
```

Optional packages stay explicit because some Atlas workflows can become heavy:

```bash
seven atlas optional
```

Examples of optional scope:

- Zeal or Kiwix for offline knowledge.
- QGIS, JOSM or Viking for advanced map workflows.
- OCRmyPDF for searchable PDF generation.

## SevenAI And Spotlight

Atlas actions are registered in `scripts/actions.sh`, so SevenAI and Spotlight
can suggest document, map, search and OCR workflows without guessing.

Atlas should prefer previewable, reversible actions. OCR writes generated files
to `~/Atlas/Exports`; it should not overwrite originals by default.
