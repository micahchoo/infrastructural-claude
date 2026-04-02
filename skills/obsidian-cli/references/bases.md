# Obsidian Bases Reference

Bases are database-like views over vault notes, stored as `.base` files in YAML format. They can display any files in the vault as tables, cards, lists, or maps.

## .base File Structure

A `.base` file has five top-level keys:

```yaml
filters:     # Global filters (apply to all views)
formulas:    # Computed properties
properties:  # Display configuration (e.g., displayName)
summaries:   # Custom aggregate formulas
views:       # List of view definitions
```

All keys are optional. A minimal `.base` file can contain just a `views:` list.

---

## Filters

By default, a base includes **every file in the vault** — there is no `from` or `source` clause like SQL. Filters narrow the set.

- **Global `filters:`** — apply to all views in the base.
- **Per-view `filters:`** — apply to one view only, combined with global filters via AND.

### Syntax

Filters use a recursive structure with `and:`, `or:`, `not:` containing lists of filter strings or nested filter objects.

```yaml
filters:
  or:
    - file.hasTag("tag")
    - and:
        - file.hasTag("book")
        - file.hasLink("Textbook")
    - not:
        - file.hasTag("book")
        - file.inFolder("Required Reading")
```

Filter strings are comparisons or function calls:

```yaml
filters:
  and:
    - 'status == "active"'
    - "age > 5"
    - file.inFolder("Projects")
    - file.hasTag("work")
```

When `filters:` contains a bare list (no `and:`/`or:`/`not:` wrapper), it is treated as AND:

```yaml
filters:
  - file.inFolder("Books")
  - 'rating >= 4'
```

---

## Formulas

Named computed properties defined at the base level, available across all views.

```yaml
formulas:
  formatted_price: 'if(price, price.toFixed(2) + " dollars")'
  ppu: "(price / age).toFixed(2)"
```

### Property References in Formulas

- **Note properties** (frontmatter): `note.price` or just `price` (shorthand)
- **File properties**: `file.size`, `file.ext`, `file.name`, etc.
- **Formula properties**: `formula.formatted_price`
- Cross-formula references are allowed (no circular references).

Formulas are always stored as YAML strings. The output type is determined by the data and functions used.

---

## Properties Section

Display configuration per property. This controls how columns/fields appear in views.

```yaml
properties:
  status:
    displayName: Status
  formula.formatted_price:
    displayName: "Price"
  file.mtime:
    displayName: "Last Modified"
```

**Important**: Display names are cosmetic only. They are NOT used in filters or formulas — always use the actual property name (`note.status`, `formula.formatted_price`, etc.) in expressions.

---

## Summaries

Custom aggregate formulas using the `values` keyword, which represents the list of all values for a property in the current view.

```yaml
summaries:
  customAvg: 'values.mean().round(3)'
  totalWords: 'values.reduce(acc + value, 0)'
```

### Default Built-in Summaries

These can be assigned to properties in view definitions by name:

| Type    | Available Summaries                                         |
| ------- | ----------------------------------------------------------- |
| Number  | Average, Min, Max, Sum, Range, Median, Stddev               |
| Date    | Earliest, Latest, Range                                      |
| Boolean | Checked, Unchecked                                           |
| Any     | Empty, Filled, Unique                                        |

---

## Views

Each view is an entry in the `views:` list.

```yaml
views:
  - type: table          # table, cards, list, map
    name: "My table"
    limit: 10
    groupBy:
      property: note.age
      direction: DESC
    filters:             # View-specific filters (same syntax as global)
      and:
        - 'status != "done"'
    order:               # Column/field order
      - file.name
      - note.age
      - formula.ppu
    summaries:           # Assign summary formulas to properties
      formula.ppu: Average
      note.price: Sum
```

### View Types

| Type    | Description                                      |
| ------- | ------------------------------------------------ |
| `table` | Spreadsheet-like rows and columns                |
| `cards` | Card grid layout                                 |
| `list`  | Simple list of items                             |
| `map`   | Geographic map (requires location properties)    |

### View Fields

| Field      | Description                                                |
| ---------- | ---------------------------------------------------------- |
| `type`     | One of `table`, `cards`, `list`, `map`                     |
| `name`     | Display name for the view tab                              |
| `limit`    | Maximum number of results to show                          |
| `groupBy`  | Object with `property` and optional `direction` (ASC/DESC) |
| `filters`  | View-specific filters (same syntax as global filters)      |
| `order`    | List of property names defining column/field order         |
| `summaries`| Map of property names to summary names or custom formulas  |

---

## Property Types

Three kinds of properties are available:

### 1. Note Properties (`note.*`)

From frontmatter. Only available for markdown files. Referenced as `note.author` or shorthand `author`.

### 2. File Properties (`file.*`)

Available for ALL file types in the vault:

| Property           | Type   | Description                                    |
| ------------------ | ------ | ---------------------------------------------- |
| `file.name`        | String | Full filename with extension                   |
| `file.basename`    | String | Filename without extension                     |
| `file.path`        | String | Full vault-relative path                       |
| `file.folder`      | String | Parent folder path                             |
| `file.ext`         | String | File extension                                 |
| `file.size`        | Number | File size in bytes                             |
| `file.ctime`       | Date   | Creation time                                  |
| `file.mtime`       | Date   | Last modified time                             |
| `file.tags`        | List   | All tags in the file                           |
| `file.links`       | List   | All outgoing links                             |
| `file.embeds`      | List   | All embedded files                             |
| `file.backlinks`   | List   | All incoming links (performance-heavy, doesn't auto-refresh) |
| `file.properties`  | Object | All frontmatter properties (doesn't auto-refresh) |
| `file.file`        | File   | The File object itself                         |

### 3. Formula Properties (`formula.*`)

Defined in the `formulas:` section of the base file. Referenced as `formula.name`.

---

## The `this` Keyword

`this` refers to different things depending on how the base is opened:

| Context                      | `this` refers to              |
| ---------------------------- | ----------------------------- |
| Base opened normally         | The base file itself          |
| Base embedded in a note      | The embedding note            |
| Base opened in sidebar       | The active file in main area  |

Example — replicate a backlinks pane:

```yaml
filters:
  - file.hasLink(this.file)
```

---

## Operators

### Arithmetic

`+`, `-`, `*`, `/`, `%`, `()` for grouping.

### Comparison

`==`, `!=`, `>`, `<`, `>=`, `<=`

### Boolean

`!` (not), `&&` (and), `||` (or)

### Date Arithmetic

Duration units:

| Short | Long                      |
| ----- | ------------------------- |
| `y`   | `year` / `years`          |
| `M`   | `month` / `months`        |
| `w`   | `week` / `weeks`          |
| `d`   | `day` / `days`            |
| `h`   | `hour` / `hours`          |
| `m`   | `minute` / `minutes`      |
| `s`   | `second` / `seconds`      |

Operations:

- Add duration: `date + "1M"` (add one month)
- Subtract duration: `date - "2h"` (subtract two hours)
- Subtract two dates: returns milliseconds
- `today()` — current date with time set to 0
- `now()` — current datetime
- `datetime.date()` — strip time component
- `datetime.format("YYYY-MM-DD")` — format as string

---

## Functions Reference

### Global Functions

| Function                              | Description                                                  |
| ------------------------------------- | ------------------------------------------------------------ |
| `if(condition, trueResult, falseResult?)` | Conditional expression                                   |
| `now()`                               | Current datetime                                             |
| `today()`                             | Current date (time = 0)                                      |
| `date("YYYY-MM-DD HH:mm:ss")`        | Parse date from string                                       |
| `duration("1d")`                      | Parse duration (needed for arithmetic: `duration('5h') * 2`) |
| `link(path, display?)`               | Create a link to a note                                      |
| `list(element)`                       | Wrap in list if not already a list                           |
| `file(path)`                          | Get file object by path                                      |
| `image(path)`                         | Render image in view                                         |
| `icon("lucide-name")`                | Render a Lucide icon                                         |
| `html(string)`                        | Render raw HTML in view                                      |
| `escapeHTML(string)`                  | Escape HTML characters                                       |
| `max(n1, n2, ...)`                   | Maximum of arguments                                         |
| `min(n1, n2, ...)`                   | Minimum of arguments                                         |
| `number(any)`                         | Coerce value to number                                       |

### Any Type Methods

| Method                | Description                |
| --------------------- | -------------------------- |
| `.isTruthy()`         | Check if value is truthy   |
| `.isType("string")`   | Check type                 |
| `.toString()`         | Convert to string          |

### String Methods

| Method / Field                      | Description                                    |
| ----------------------------------- | ---------------------------------------------- |
| `.length`                           | String length (field, not method)              |
| `.contains(s)`                      | Check if contains substring                    |
| `.containsAll(s1, s2)`             | Check if contains all substrings               |
| `.containsAny(s1, s2)`             | Check if contains any substring                |
| `.startsWith(s)`                    | Check prefix                                   |
| `.endsWith(s)`                      | Check suffix                                   |
| `.isEmpty()`                        | Check if empty                                 |
| `.lower()`                          | Convert to lowercase                           |
| `.title()`                          | Convert to title case                          |
| `.trim()`                           | Strip whitespace                               |
| `.replace(pattern, replacement)`    | Replace (string or regex pattern)              |
| `.repeat(n)`                        | Repeat n times                                 |
| `.reverse()`                        | Reverse characters                             |
| `.slice(start, end?)`              | Extract substring                              |
| `.split(sep, n?)`                  | Split into list                                |

### Number Methods

| Method               | Description                          |
| -------------------- | ------------------------------------ |
| `.abs()`             | Absolute value                       |
| `.ceil()`            | Round up                             |
| `.floor()`           | Round down                           |
| `.round(digits?)`    | Round (optional decimal places)      |
| `.toFixed(precision)` | Format to fixed decimal places      |
| `.isEmpty()`         | Check if empty/null                  |

### Date Methods

| Method / Field   | Description                        |
| ---------------- | ---------------------------------- |
| `.year`          | Year component                     |
| `.month`         | Month component                    |
| `.day`           | Day component                      |
| `.hour`          | Hour component                     |
| `.minute`        | Minute component                   |
| `.second`        | Second component                   |
| `.millisecond`   | Millisecond component              |
| `.date()`        | Strip time, keep date              |
| `.time()`        | Get time as string                 |
| `.format("...")`  | Format using Moment.js tokens (e.g., `"YYYY-MM-DD"`) |
| `.relative()`    | Human-readable relative time (e.g., "3 days ago") |
| `.isEmpty()`     | Check if empty/null                |

### List Methods

| Method / Field                       | Description                                              |
| ------------------------------------ | -------------------------------------------------------- |
| `.length`                            | List length (field, not method)                          |
| `.contains(v)`                       | Check if list contains value                             |
| `.containsAll(v1, v2)`              | Check if list contains all values                        |
| `.containsAny(v1, v2)`              | Check if list contains any value                         |
| `.filter(value > 2)`                | Filter items; uses `value` and `index` variables         |
| `.map(value + 1)`                   | Transform items; uses `value` and `index` variables      |
| `.reduce(acc + value, 0)`           | Reduce to single value; uses `value`, `index`, `acc`     |
| `.sort()`                            | Sort ascending                                           |
| `.reverse()`                         | Reverse order                                            |
| `.unique()`                          | Remove duplicates                                        |
| `.flat()`                            | Flatten nested lists                                     |
| `.slice(start, end?)`               | Extract sublist                                          |
| `.join(sep)`                         | Join into string                                         |
| `.isEmpty()`                         | Check if empty                                           |

### Link Methods

| Method              | Description                    |
| ------------------- | ------------------------------ |
| `.asFile()`         | Get the linked File object     |
| `.linksTo(file)`    | Check if links to a file       |

### File Methods

| Method / Field    | Description                                          |
| ----------------- | ---------------------------------------------------- |
| `.name`           | Full filename with extension                         |
| `.basename`       | Filename without extension                           |
| `.path`           | Full vault-relative path                             |
| `.folder`         | Parent folder path                                   |
| `.ext`            | File extension                                       |
| `.size`           | File size in bytes                                   |
| `.ctime`          | Creation time                                        |
| `.mtime`          | Last modified time                                   |
| `.properties`     | All frontmatter properties                           |
| `.tags`           | All tags                                             |
| `.links`          | All outgoing links                                   |
| `.asLink(display?)` | Create a link to this file                         |
| `.hasLink(file)`  | Check if file has a link to target                   |
| `.hasTag(tag1, tag2, ...)` | Check if file has tag(s); includes nested tags |
| `.hasProperty(name)` | Check if property exists                          |
| `.inFolder(folder)` | Check if in folder (includes subfolders)           |

### Object Methods

| Method      | Description              |
| ----------- | ------------------------ |
| `.isEmpty()` | Check if object is empty |
| `.keys()`   | Get list of keys         |
| `.values()` | Get list of values       |

### Regular Expression

| Method              | Description          |
| ------------------- | -------------------- |
| `/pattern/.matches(string)` | Test if pattern matches string |

---

## Complete Examples

### Book Tracker

```yaml
filters:
  and:
    - file.inFolder("Books")
    - file.hasTag("book")

formulas:
  days_since_read: '(now() - finished).toFixed(0) / 86400000'
  status_icon: 'if(status == "read", icon("lucide-check"), icon("lucide-book-open"))'

properties:
  formula.status_icon:
    displayName: ""
  note.rating:
    displayName: "Rating"

summaries:
  avgRating: 'values.mean().round(1)'

views:
  - type: table
    name: "All Books"
    order:
      - formula.status_icon
      - file.name
      - note.author
      - note.rating
      - note.status
    summaries:
      note.rating: avgRating
    groupBy:
      property: note.status
      direction: ASC
```

### Dynamic Backlinks (Using `this`)

```yaml
filters:
  - file.hasLink(this.file)

views:
  - type: list
    name: "Backlinks"
    order:
      - file.name
      - file.mtime
```

### Project Dashboard with Multiple Views

```yaml
filters:
  - file.inFolder("Projects")

formulas:
  overdue: 'if(deadline < today() && status != "done", "OVERDUE", "")'
  days_left: 'if(deadline, ((deadline - today()) / 86400000).round(0), "")'

views:
  - type: table
    name: "Active"
    filters:
      and:
        - 'status != "done"'
        - 'status != "cancelled"'
    order:
      - file.name
      - note.status
      - note.deadline
      - formula.days_left
      - formula.overdue
    summaries:
      file.name: Filled

  - type: cards
    name: "Completed"
    filters:
      - 'status == "done"'
    order:
      - file.name
      - note.completed_date
