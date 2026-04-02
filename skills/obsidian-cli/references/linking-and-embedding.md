# Linking and Embedding

## Internal Links

Two equivalent formats (Obsidian defaults to wikilinks):

| Format | Syntax |
|--------|--------|
| Wikilink | `[[Note Name]]` or `[[Note Name.md]]` |
| Markdown | `[Note Name](Note%20Name)` (URL-encoded spaces) |

Toggle via Settings > Files and Links > Use `[[Wikilinks]]`.

### File Links

```
[[Example]]
[[Figure 1.png]]    # non-markdown files require extension
```

### Heading Links (Anchors)

```
[[#Heading Name]]              # same note
[[Note#Heading Name]]          # other note
[[Note#Heading#Subheading]]    # subheading chain
```

Search helpers: type `[[##` or `[[## search term]]` to find headings.

### Block Links

```
[[Note#^block-id]]             # reference a block
[[^^search term]]              # search for blocks
```

Define a block ID by appending ` ^block-id` at the end of a paragraph (space before `^`).

For structured blocks (lists, blockquotes, callouts, tables), place `^id` on its own line with blank lines before and after.

Block IDs allow only Latin letters, numbers, and dashes. Cannot link to specific parts within callouts, quotes, or tables.

### Display Text (Aliases)

```
[[Note|Custom Display]]        # wikilink
[Custom Display](Note.md)      # markdown
```

Use YAML `aliases` frontmatter for reusable alternate names.

### Invalid Characters in Links

`# | ^ : %% [[ ]]` -- these cannot appear in link targets.

---

## Embedding

Prefix `!` before any internal link to embed content inline.

### Notes, Headings, Blocks

```
![[Note]]                      # full note
![[Note#Heading]]              # heading section
![[Note#^block-id]]            # single block
![[Note#^list-id]]             # list block
```

### Images

```
![[image.jpg]]                 # default size
![[image.jpg|100x145]]         # width x height
![[image.jpg|100]]             # width only, auto height
![250](https://example.com/img.png)  # external with width
```

Supported formats: png, jpg, jpeg, gif, bmp, svg, webp.

### Audio

```
![[recording.ogg]]
```

Supported formats: mp3, webm, wav, m4a, ogg, 3gp, flac.

### PDF

```
![[document.pdf]]              # embed full PDF
![[document.pdf#page=3]]       # specific page
![[document.pdf#height=400]]   # custom height in pixels
```

### Video

```
![[video.mp4]]
```

Supported formats: mp4, webm, ogv.
