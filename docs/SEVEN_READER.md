# Seven Reader

Seven Reader is the native SevenOS reading surface. It is designed as a calm,
immersive library and reader for PDF, EPUB, Markdown, text and CBZ documents.

## Product Role

Seven Reader is not only a file viewer. It is the reading, study and document
continuity layer for SevenOS:

- Library-first access to books and documents.
- Reader mode for distraction-free reading.
- Double Page and Book modes for a physical-book layout.
- Flipbook mode as the first SevenOS page-turning experience.
- Inspect mode for high-resolution page examination.
- Document search, outline, bookmarks and notes.
- SevenAI Reading Companion for summaries, explanations and study prompts.

## Current Native Foundation

The current implementation is a GTK native app:

- Command: `seven-reader`
- Seven command: `seven reader`
- Desktop entry: `seven-reader.desktop`
- Icon: `seven-reader`
- State: `~/.local/share/sevenos/reader`
- Cache: `~/.cache/sevenos/reader`
- Annotations: `~/.local/share/sevenos/reader/annotations.json`

Supported formats:

- PDF via Poppler tools: `pdfinfo`, `pdftoppm`
- EPUB via local ZIP/XHTML text extraction
- Markdown and text via native pagination
- CBZ via local image archive extraction

Professional reading features:

- In-document search with page results.
- Reading sidebar for outline, search results, bookmarks and notes.
- Persistent bookmarks and page notes per document.
- Centered book navigation with first, previous, next and last page controls.
- Spread-aware page labels such as `2 - 3 / 14` in Book and Flipbook modes.
- Progress slider, page memory, Fit Page, Actual Size and zoom controls.
- Fit-visible page sizing at `100%` in Book and Flipbook modes.
- Adaptive reading: Book and Flipbook keep a two-page spread on wide windows,
  then fall back to a single visible page on compact windows.
- Real two-page spread styling with page sides, spine shadow and blank end page.
- Multi-phase page curl animation for a clearer page-turning effect.
- Native page turning from the document surface: click page edges or scroll to
  move through pages without aiming at toolbar controls.
- Focus mode with `F11`.
- Keyboard shortcuts: `Ctrl+F` search, `Ctrl+B` bookmark, `Ctrl+N` note.
- Lightweight PDF preloading for nearby pages and text extraction.

## SevenOS Integration

Seven Reader is installed as a normal SevenOS command and application. It is
registered for document MIME types through `scripts/apply-theme.sh` and can be
opened from Seven Files with:

```bash
seven-files read ./book.pdf
seven reader ./book.epub
seven reader --json
```

## Future GPU Flipbook Engine

The GTK implementation is the product foundation. The future engine should move
the physical page simulation into a dedicated rendering layer:

- Rust core.
- GTK4/Libadwaita or Qt6/QML shell.
- MuPDF page rasterization.
- WGPU/OpenGL page mesh deformation.
- Paper texture and dynamic lighting shaders.
- Spring physics for page turn gestures.
- Tile cache for deep Inspect mode.

The expected end state is a true Wayland-native book object: double page spread,
spine shadow, page thickness, paper material, sound feedback and local SevenAI
study assistance.
