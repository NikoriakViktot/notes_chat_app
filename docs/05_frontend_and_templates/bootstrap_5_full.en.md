# Bootstrap 5 — Architecture and Components

> Bootstrap is an abstraction layer that turns web design from "writing raw CSS"
> into "composing ready-made architectural blocks".
> For a backend developer, Bootstrap is the same thing as Django Admin:
> a ready-made, proven tool so you don't have to build from scratch.

---

---

- 🧠 Mental model: **Bootstrap** is a ready-made LEGO set. Without it, you sculpt the pieces out of clay (raw CSS). With it, you snap ready-made blocks together.
- 📚 Why it exists: **Before Bootstrap (2011)** every team built its own grid, its own buttons, its own modal windows — all slightly different, all buggy. Twitter Bootstrap appeared to standardize UI development.
- 🌐 What Bootstrap does under the hood: **Bootstrap** is one big CSS file (~190KB before minification) with thousands of ready-made classes + one JS file that adds behavior to components (Modal, Dropdown, Tooltip, etc.). You simply include them and use the classes.
- ❌ Common beginner mistake: **Thinking that Bootstrap is "just styles"**. Bootstrap also provides JavaScript behavior (hamburger menu, modal windows, tabs), a grid system and accessibility out of the box.
 
---

**Context for Django developers:** You write Python/Django views — your strength is the backend. Bootstrap lets you build a professional UI without being a CSS expert. Instead of spending 10 hours writing responsive navigation, you write 20 lines of HTML with Bootstrap classes and get a finished result.

**Historical context:** Before 2011 every web team built CSS from scratch. Buttons looked different on every site. Internet Explorer 6, 7 and 8 had different bugs — and every developer wrote their own compatibility "hacks". Bootstrap solved this problem: one stable, tested CSS that works everywhere.

## 0. Why CSS frameworks exist

### The fundamental problem without Bootstrap

```
Every project → its own CSS for buttons, cards, navigation
              → cross-browser bugs
              → non-standardized UI
              → new team — has to learn the structure all over again
```

### What Bootstrap solves

| Problem | Bootstrap's solution |
|----------|-------------------|
| Writing CSS for every button | Ready-made classes: `.btn`, `.btn-primary` |
| Cross-browser bugs | `Reboot` — style normalization for all browsers |
| Responsiveness — separate versions | 12-column grid + breakpoints |
| Non-standard UI | A unified design system through classes |
| Modal/Dropdown logic from scratch | Data API: `data-bs-toggle="modal"` |

### Bootstrap vs Tailwind — the philosophical difference

| | Bootstrap | Tailwind |
|-|-----------|----------|
| **Approach** | Component-First | Utility-First |
| **Ready-made components** | Yes (Navbar, Card, Modal) | No (you build them yourself) |
| **Customization** | Sass variables, override | Atomic utilities |
| **Speed of getting started** | Very high | Medium |
| **Custom design** | Takes effort | Native |
| **For Django** | Ideal | Needs a build tool |

> **Bootstrap mental model:** A LEGO construction set for UI.
> You don't manufacture the pieces (raw CSS) — you assemble from ready-made ones.

---

---
- **🧠 Mental model:** A CDN is like music streaming (the file is on a server, you listen to it). Local is like downloading a track (the file is yours, always available). CDN is faster for getting started, Local is more reliable for production.
- **📚 Why it exists:** Including Bootstrap via a CDN lets you start working in 30 seconds with no setup. For learning projects this is ideal. In production, npm + a bundler are often used to include only the parts of Bootstrap that are actually needed.
- **🌐 What Bootstrap does under the hood:** When Bootstrap's CSS loads, the browser parses ~10,000 CSS rules and builds the CSSOM (CSS Object Model). This happens while blocking rendering — that's why CSS goes in `<head>` and JS goes before `</body>`.
- **❌ Common beginner mistake:** Including Bootstrap JS before Bootstrap CSS, or including your own styles BEFORE Bootstrap CSS. The order is critically important.
---

**CDN vs Local — when to use which:**

CDN (Content Delivery Network) means the Bootstrap file lives on a remote server (cdn.jsdelivr.net). The browser downloads it from there. Advantages: fast, simple, nothing to install. Drawback: you need internet access, and you depend on an external server.

Local means you download Bootstrap and serve it from your own server. Advantages: works offline, you don't depend on external services. Drawback: it needs to be set up.

**Include order — why it matters:**

Bootstrap CSS MUST come before your own CSS — then your styles can override Bootstrap. Bootstrap JS MUST go before `</body>` — because JS manipulates the DOM, and the DOM must already be built. JS in `<head>` blocks page rendering.

**The `integrity` attribute — security through cryptography:**

`integrity="sha384-..."` is the SHA-384 hash of the file. The browser downloads the file, computes its hash and compares it with the given one. If the CDN server was hacked and the file was swapped — the hash will not match and the browser will REFUSE to execute the script. This protects against supply chain attacks.

## 1. Including Bootstrap 5

### CDN (the fastest way — for learning)

This HTML template is the minimum required for Bootstrap to work. Pay attention to `<meta name="viewport">` — without it, mobile browsers render the page as a desktop page and scale it down, breaking responsiveness. Bootstrap CSS goes in `<head>` (needed before rendering), JS goes before `</body>` (doesn't block display).

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bootstrap 5</title>

    <!-- Bootstrap CSS — in <head> (blocks rendering until it loads) -->
    <link
        href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
        rel="stylesheet"
        integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH"
        crossorigin="anonymous"
    >
</head>
<body>
    <!-- Content -->

    <!-- Bootstrap JS + Popper — before </body> (doesn't block rendering) -->
    <script
        src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"
        integrity="sha384-YvpcrYf0tY3lHB60NNkmXc4s9bIOgUxi8T/jzmxfkOHv9y4m/sPyFG5p5TtVQOS"
        crossorigin="anonymous"
    ></script>
</body>
</html>
```

### In Django Templates

In a Django project, Bootstrap is included in `base.html` — the base template that all others inherit from. Note the `{% block extra_css %}` and `{% block extra_js %}` blocks — they let child templates add page-specific styles and scripts without duplicating the base structure. Your own styles (`custom.css`) are included AFTER Bootstrap — this lets you override Bootstrap styles.

```html
{# base.html #}
{% load static %}
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Site{% endblock %}</title>

    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          rel="stylesheet">

    <!-- Your own styles — AFTER Bootstrap (they override it) -->
    <link rel="stylesheet" href="{% static 'css/custom.css' %}">

    {% block extra_css %}{% endblock %}
</head>
<body>

    {% block content %}{% endblock %}

    <!-- Bootstrap JS Bundle (includes Popper.js) -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>

    {% block extra_js %}{% endblock %}
</body>
</html>
```

### Using django-bootstrap5

`django-bootstrap5` is a package that provides Django template tags for Bootstrap. The `{% bootstrap_form form %}` tag automatically renders all fields of a Django form with the correct Bootstrap classes (`form-control`, `form-label`, `invalid-feedback`). This saves dozens of lines of HTML for every form.

```python
# settings.py
INSTALLED_APPS = [
    ...
    'django_bootstrap5',
]
```

```html
{# In a template #}
{% load django_bootstrap5 %}
{% bootstrap_css %}
{% bootstrap_javascript %}

<form method="post">
    {% csrf_token %}
    {% bootstrap_form form %}
    {% bootstrap_button "Save" button_type="submit" button_class="btn-primary" %}
</form>
```

---

---
- **🧠 Mental model:** The Grid is a three-level matryoshka doll. The container is the outer doll (sets the maximum width). The Row is the middle one (a flex container). The Col is the inner one (the actual content with padding).
- **📚 Why it exists:** Before grid systems, developers used tables (`<table>`) for page layout — and it was awful. Bootstrap Grid solved the problem of responsive layout with flexbox and 12-column math.
- **🌐 What Bootstrap does under the hood:** Bootstrap generates CSS with `flex: 0 0 X%` for each column, where X = (N/12)*100. `col-6` → `flex: 0 0 50%; max-width: 50%`. The Row gets `display: flex; flex-wrap: wrap; margin: 0 -12px` to compensate for the container's padding.
- **❌ Common beginner mistake:** Writing content directly in `.row` without `.col`, or nesting `.container` inside `.container`. Both break the spacing math.
---

**Understanding the Grid deeply before the code:**

Bootstrap Grid is built on 3 nested concepts:

```
Container  → sets max-width and centers everything
  └── Row  → creates a flex container, uses a negative margin to compensate for the gutter
       └── Col → each column has padding (that same "gutter")
```

**Why exactly 12 columns?** 12 is divisible by 1, 2, 3, 4, 6, 12 — maximum flexibility. You don't need to write fractions — you just say "3 columns" (col-4 × 3 = 12) or "4 columns" (col-3 × 4 = 12).

**Grid math — in detail:**

```
Container: max-width: 960px
  padding: 0 12px ← compensates for the Row's negative margin
    ↓
  Row: margin: 0 -12px  ← "eats" the container's padding
    display: flex; flex-wrap: wrap;
    ↓
    Col-6: flex: 0 0 50%; padding: 0 12px ← "gutter" (the gap between columns)
    Col-6: flex: 0 0 50%; padding: 0 12px

Result: two equal columns with a 24px total gap between them
(12px padding to the right of the first + 12px padding to the left of the second)
```

The negative margin on the Row is not a bug, it's a math trick: without it, the first and last columns would have a double indent from the edges of the container.

## 2. Grid System — Grid architecture

### Hierarchy: Container → Row → Column → Content

The next block shows the CORRECT and INCORRECT Grid hierarchy. Remember: content always goes inside `.col`, never directly into `.row`. Nested containers are also forbidden — they double the padding and break the math.

```
❌ WRONG:
<div class="row">
    <p>Content directly in row</p>   ← breaks the margin/padding math
</div>

❌ WRONG:
<div class="container">
    <div class="container">       ← nested containers
        ...
    </div>
</div>

✅ CORRECT:
<div class="container">
    <div class="row">
        <div class="col-12 col-md-6">Content</div>
        <div class="col-12 col-md-6">Content</div>
    </div>
</div>
```

### Grid math diagram

This diagram shows how Bootstrap Grid works from the inside. Note the `margin: 0 -12px` on the Row — this is the key trick that aligns the columns with the container's edges. The padding on Col is the "gutter" (the gap between columns).

```
Container (.container)
│ max-width: 960px (at lg)
│ padding: 0 12px  ← compensates for the row's negative margin
│
└── Row (.row)
    │ display: flex; flex-wrap: wrap;
    │ margin: 0 -12px  ← the negative margin "takes back" the container's padding
    │
    ├── Column (.col-md-6)
    │   │ flex: 0 0 50%; max-width: 50%
    │   │ padding: 0 12px  ← gutter (the distance between columns)
    │   │
    │   └── [Content here]  ← padding protects from the edges
    │
    └── Column (.col-md-6)
        │ padding: 0 12px
        └── [Content here]
```

**Why a negative margin?**
The Row gets `margin: 0 -12px` to compensate for the container's padding.
This guarantees that the first and last columns are aligned with the container's edges.

### Container types

The choice of container type depends on the design. `.container` — for most pages (content doesn't stretch to the edges on large screens). `.container-fluid` — for full-screen sections (hero, maps, dashboards). `.container-md` — a hybrid: full width on mobile, fixed width on tablets and up.

```html
<!-- Fixed maximum width at each breakpoint -->
<div class="container">...</div>

<!-- Always 100% of the viewport width -->
<div class="container-fluid">...</div>

<!-- 100% up to md, then fixed -->
<div class="container-md">...</div>

<!-- 100% up to lg, then fixed -->
<div class="container-lg">...</div>
```

| Class | xs | sm | md | lg | xl | xxl |
|------|----|----|----|----|----|----|
| `.container` | 100% | 540px | 720px | 960px | 1140px | 1320px |
| `.container-fluid` | 100% | 100% | 100% | 100% | 100% | 100% |
| `.container-md` | 100% | 100% | 720px | 960px | 1140px | 1320px |

### Columns — the math of 12 units

These examples show different ways to set column widths. `.col` (without a number) automatically distributes the available space equally among all columns. Explicit numbers give precise control. If the sum is > 12 — flex-wrap moves the columns to the next line.

```html
<!-- Equal columns -->
<div class="row">
    <div class="col">Auto</div>     <!-- 1/N of the available width -->
    <div class="col">Auto</div>
    <div class="col">Auto</div>
</div>

<!-- Explicit width (sum in a row = 12) -->
<div class="row">
    <div class="col-8">8/12 = 66.7%</div>
    <div class="col-4">4/12 = 33.3%</div>
</div>

<!-- If the sum > 12 → flex-wrap moves it to a new line -->
<div class="row">
    <div class="col-7">7/12</div>
    <div class="col-7">7/12 → wraps (7+7=14 > 12)</div>
</div>

<!-- Vertical alignment -->
<div class="row align-items-center">    <!-- center | start | end | stretch -->
    <div class="col">...</div>
</div>

<!-- Horizontal alignment -->
<div class="row justify-content-center"> <!-- start | end | center | between | around -->
    <div class="col-6">Centered column</div>
</div>
```

### Nested grids

Nested grids are a powerful pattern for complex layouts. Each column can contain its own Row with 12-column math. Important: the inner 12 is 12 of the parent column's width, not of the whole container.

```html
<!-- A column can be split into its own 12-column grid -->
<div class="row">
    <div class="col-8">
        Main column (8/12)
        <!-- Nested grid — new math from scratch -->
        <div class="row">
            <div class="col-6">Nested 1 (6/12 of col-8)</div>
            <div class="col-6">Nested 2</div>
        </div>
    </div>
    <div class="col-4">Side column (4/12)</div>
</div>
```

---

---
- **🧠 Mental model:** Breakpoints are "thresholds" — the MOMENT when the layout switches from phone to tablet. Imagine a thermostat: below 20° — heating, above 20° — air conditioning. Breakpoints are your temperature.
- **📚 Why it exists:** The same HTML code has to look good on screens from 320px (a small phone) to 2560px (a large monitor). Breakpoints let you define different grid behavior for different sizes without duplicating HTML.
- **🌐 What Bootstrap does under the hood:** Bootstrap CSS is written with `min-width` media queries. `col-md-6` generates: `@media (min-width: 768px) { .col-md-6 { flex: 0 0 50%; } }`. Rules for larger screens are declared later in the file, so they win in the CSS cascade.
- **❌ Common beginner mistake:** Thinking that `col-md-6` means "only on md". It actually means "from md and up". Bootstrap is Mobile First — rules layer on top of each other from top to bottom rather than replacing each other.
---

**Mobile First — why Bootstrap is built this way:**

Bootstrap uses `min-width` media queries. This means: first you describe the smallest screen, then you add rules for larger ones. This is the "Mobile First" approach.

Cascade mechanics:
- `col-12` — applies from 0px (no media query, always active)
- `col-md-6` — applies from 768px (has `@media (min-width: 768px)`)
- On an 800px screen BOTH rules are active, but `col-md-6` is declared LATER in the file → it wins

Why later? The CSS cascade: with equal specificity, the rule that appears lower in the file wins. Bootstrap orders its media queries from smaller to larger — so a larger breakpoint always beats a smaller one.

## 3. Breakpoints and Mobile First

### Bootstrap 5 breakpoint table

Memorize this table — it is the foundation of all responsive layout in Bootstrap. The prefix (`sm`, `md`, `lg`, etc.) is added to any utility class to make it depend on the screen size.

| Prefix | Name | min-width | Typical device |
|--------|-------|-----------|------------------|
| *(none)* | Extra small | 0 | Phone (portrait) |
| `sm` | Small | 576px | Phone (landscape) |
| `md` | Medium | 768px | Tablet |
| `lg` | Large | 992px | Desktop |
| `xl` | X-Large | 1200px | Large monitor |
| `xxl` | XX-Large | 1400px | Very large screen |

### How to read a class: Mobile First = left → right

This code shows how one element changes its behavior at 4 different screen sizes. Read the classes from left to right — from the smallest screen to the largest. The first class without a prefix is the base (mobile) one, and each following one adds a rule for a larger screen.

```html
<div class="col-12 col-sm-6 col-md-4 col-lg-3">Item</div>
```

```
0px    → col-12    → 12/12 = 100%   (1 per row)
576px  → col-sm-6  →  6/12 = 50%   (2 per row)
768px  → col-md-4  →  4/12 = 33%   (3 per row)
992px  → col-lg-3  →  3/12 = 25%   (4 per row)
```

**Mechanics:** Each following prefix has a higher `min-width` → the CSS rule with the larger `min-width`
is declared later in the file → it wins in the cascade.

### Prediction Quiz — the answer

Check your understanding: how many blocks will be in a row on different screens? Count: for each viewport only ONE class is active (the largest one that still applies). The sum of the columns in a row determines the number of items.

```html
<div class="row">
    <div class="col-12 col-md-6 col-lg-4">Block</div>  × 3
</div>
```

| Viewport | Active class | Width | Blocks per row |
|----------|--------------|--------|----------------|
| 480px | `col-12` | 100% | 1 |
| 800px | `col-md-6` | 50% | **2** (6+6=12) |
| 1200px | `col-lg-4` | 33% | **3** (4+4+4=12) |

**Answer:** mobile (480px): 1 block, tablet (800px): 2 blocks, monitor (1200px): 3 blocks.

---

---
- **🧠 Mental model:** Bootstrap utilities are like Tailwind, but less granular. `mt-3` = `margin-top: 1rem` (16px). Instead of writing CSS, you compose from classes right in the HTML. This is the atomic CSS approach.
- **📚 Why it exists:** Instead of opening a CSS file for every small margin, Bootstrap lets you write `mb-3` right in the HTML. This speeds up development and keeps "small" styles next to the HTML structure, where they belong.
- **🌐 What Bootstrap does under the hood:** `mt-3` generates `margin-top: 1rem !important`. Note the `!important` — it guarantees that the utility class beats any other CSS. This is intentional: utilities have the highest priority.
- **❌ Common beginner mistake:** Writing your own CSS `style="margin-top: 16px"` instead of using `mt-3`. Or not knowing that `mx-auto` centers a block element (margin: 0 auto).
---

**The spacing scale — memorize it once and for all:**

Bootstrap uses a scale where the base unit = `$spacer = 1rem = 16px`. Each level multiplies or divides the base unit:
- `mt-1` = 4px (0.25rem)
- `mt-2` = 8px (0.5rem)
- `mt-3` = 16px (1rem) ← base unit
- `mt-4` = 24px (1.5rem)
- `mt-5` = 48px (3rem)

Learn this scale and you'll never write `margin-top: 16px` by hand again.

**Responsive utilities — a very common pattern:**

`d-none d-md-block` = hidden on mobile, visible on tablets+. This is one of the most frequent patterns in Bootstrap. The opposite: `d-block d-md-none` = visible only on mobile.

## 4. Bootstrap utilities

### Spacing — spacing scale

Bootstrap uses a scale from 0 to 5 derived from `$spacer` (1rem = 16px). The scale is not linear: `1` = `$spacer * .25`, `2` = `* .5`, `3` = `* 1`, `4` = `* 1.5`, `5` = `* 3`:

| Class | Value |
|------|---------|
| `*-0` | 0 |
| `*-1` | 4px (0.25rem) |
| `*-2` | 8px (0.5rem) |
| `*-3` | 16px (1rem) |
| `*-4` | 24px (1.5rem) |
| `*-5` | 48px (3rem) |
| `*-auto` | auto |

The following code demonstrates the whole shorthand system for spacing. `m` = margin, `p` = padding. Directions: `t` (top), `b` (bottom), `s` (start/left), `e` (end/right), `x` (horizontal), `y` (vertical). Responsive variants let you set different spacing for different screens.

```html
<!-- Margin: m = margin, p = padding -->
<!-- t=top, b=bottom, s=start(left), e=end(right), x=horizontal, y=vertical -->

<div class="mt-3">margin-top: 16px</div>
<div class="mb-2">margin-bottom: 8px</div>
<div class="mx-auto">margin-left: auto; margin-right: auto (centering)</div>
<div class="p-4">padding: 24px on all sides</div>
<div class="py-2 px-4">padding vertical 8px, horizontal 24px</div>

<!-- Responsive spacing -->
<div class="mt-3 mt-md-0">margin-top: 16px on mobile, 0 on tablets+</div>
<div class="p-2 p-lg-5">padding: 8px on mobile, 48px on large screens</div>
```

### Colors and themes

Bootstrap provides a semantic color system through themes: `primary`, `secondary`, `success`, `danger`, `warning`, `info`, `light`, `dark`. The same theme (`success`) applies to text (`text-success`), backgrounds (`bg-success`), buttons (`btn-success`) and alerts (`alert-success`) — a consistent system.

```html
<!-- Text -->
<p class="text-primary">Blue (primary)</p>
<p class="text-secondary">Gray (secondary)</p>
<p class="text-success">Green (success)</p>
<p class="text-danger">Red (danger)</p>
<p class="text-warning">Yellow (warning)</p>
<p class="text-info">Light blue (info)</p>
<p class="text-light">Light</p>
<p class="text-dark">Dark</p>
<p class="text-muted">Gray (muted)</p>
<p class="text-white bg-dark">White text on a dark background</p>

<!-- Background -->
<div class="bg-primary text-white">Blue background</div>
<div class="bg-light">Light gray background</div>
<div class="bg-transparent">Transparent background</div>

<!-- Buttons with themes -->
<button class="btn btn-primary">Primary</button>
<button class="btn btn-outline-secondary">Outline Secondary</button>
<button class="btn btn-danger btn-sm">Small red</button>
<button class="btn btn-success btn-lg">Large green</button>
```

### Display and Flexbox utilities

Display utilities let you control the visibility and display type of elements right in the HTML. Responsive variants (`d-none d-md-block`) are one of the most common patterns in Bootstrap. Flex utilities (`justify-content-between`, `align-items-center`) mirror CSS flexbox properties as classes.

```html
<!-- Display -->
<div class="d-none">Hidden</div>
<div class="d-block">Block</div>
<div class="d-inline">Inline</div>
<div class="d-inline-block">Inline-block</div>
<div class="d-flex">Flex container</div>
<div class="d-grid">Grid container</div>

<!-- Responsive display -->
<div class="d-none d-md-block">Only from tablet up</div>
<div class="d-block d-md-none">Mobile only</div>
<div class="d-none d-lg-block d-xl-none">Only lg</div>

<!-- Flex utilities (on a flex container) -->
<div class="d-flex justify-content-between align-items-center">
    <span>Left</span>
    <span>Right</span>
</div>

<div class="d-flex flex-column flex-md-row gap-3">
    <!-- Vertical on mobile, horizontal on tablets -->
    <div>Item 1</div>
    <div>Item 2</div>
</div>

<!-- flex-wrap: wrap for wrapping -->
<div class="d-flex flex-wrap gap-2">
    <div class="p-2 bg-light">Tag 1</div>
    <div class="p-2 bg-light">Tag 2</div>
    <div class="p-2 bg-light">Tag 3</div>
</div>
```

### Typography utilities

Bootstrap provides typography utilities for text size, alignment, transformation and weight. `display-1` to `display-6` are large decorative headings. `lead` is an enlarged introductory paragraph. `text-truncate` cuts text off with "..." (requires a fixed width).

```html
<h1 class="display-1">Large heading (72px)</h1>
<h2 class="display-4">Smaller display (36px)</h2>

<p class="lead">Introductory paragraph (larger font)</p>

<p class="text-center">Centered</p>
<p class="text-start">Left</p>
<p class="text-end">Right</p>
<p class="text-md-center">Centered from md+</p>

<p class="text-uppercase">Uppercase letters</p>
<p class="text-lowercase">lowercase letters</p>
<p class="text-capitalize">First Letter Capitalized</p>

<p class="fw-bold">Bold</p>
<p class="fw-normal">Normal</p>
<p class="fst-italic">Italic</p>

<p class="text-truncate" style="max-width: 200px">Long text gets truncated...</p>

<!-- Unstyled lists -->
<ul class="list-unstyled">
    <li>No bullet</li>
    <li>No indent</li>
</ul>

<!-- Inline list -->
<ul class="list-inline">
    <li class="list-inline-item">Tag 1</li>
    <li class="list-inline-item">Tag 2</li>
</ul>
```

### Borders and Shadows

Border and shadow utilities let you add borders, rounded corners and shadows without writing CSS. `rounded-pill` is popular for tags and badges. `shadow-sm` is a barely visible shadow, often used on cards. `rounded-circle` together with a fixed size is the pattern for avatars.

```html
<!-- Borders -->
<div class="border">All sides</div>
<div class="border-top border-primary">Blue top border</div>
<div class="border-0">No border</div>

<!-- Rounded corners -->
<div class="rounded">4px radius</div>
<div class="rounded-3">Larger (8px)</div>
<div class="rounded-pill">Pill (50rem)</div>
<div class="rounded-circle">Circle</div>
<img class="rounded-circle" src="..." style="width: 100px">

<!-- Shadows -->
<div class="shadow-sm">Small shadow</div>
<div class="shadow">Medium</div>
<div class="shadow-lg">Large</div>
<div class="shadow-none">No shadow</div>
```

---

---
- **🧠 Mental model:** A Navbar is a responsive flex container with built-in collapse behavior. On large screens — a horizontal menu. On small ones — a hamburger button that expands a vertical menu.
- **📚 Why it exists:** Responsive navigation is one of the hardest tasks in CSS. Bootstrap Navbar solves it with one component: it tracks the screen size, hides/shows elements, animates the collapse and adds ARIA attributes.
- **🌐 What Bootstrap does under the hood:** `navbar-expand-lg` generates `@media (min-width: 992px) { .navbar-expand-lg .navbar-collapse { display: flex !important; } }`. On small screens `.collapse` = `display: none`. Bootstrap JS adds/removes the `show` class when the hamburger is clicked.
- **❌ Common beginner mistake:** Forgetting `data-bs-target="#navbarMenu"` on the button or `id="navbarMenu"` on the collapse div — they MUST match, otherwise the hamburger doesn't work.
---

**What `navbar-expand-lg` means:**

"Expand (show the full menu) on LG screens and larger. Collapse (hamburger) below LG." In other words, you choose the TRANSITION POINT between the mobile and desktop look of the navigation. You can replace it with `navbar-expand-md` or `navbar-expand-sm`.

**The hamburger mechanism — step by step:**

```
On mobile: .collapse div → display: none (menu hidden)
Click on hamburger → Bootstrap JS reads data-bs-target="#navbarMenu"
                   → Finds #navbarMenu in the DOM
                   → Adds the "show" class → CSS: display: block → animation
                   → At the same time: aria-expanded changes from "false" to "true"
```

**Why ARIA attributes on the hamburger button:** Screen reader users can't "see" that the menu has opened. `aria-expanded="false/true"` lets the screen reader ANNOUNCE the button's state. `aria-controls="navbarMenu"` indicates WHICH element it controls.

## 5. Components — Navbar

### Basic Navbar structure

This code is a complete responsive navigation for a Django project. Note the 3 key parts: 1) `navbar-brand` — the site logo/name. 2) `navbar-toggler` — the hamburger button for mobile (appears only on small screens). 3) `collapse navbar-collapse` — the menu block that is hidden on mobile. All three must be present for it to work correctly.

```html
<nav class="navbar navbar-expand-lg navbar-dark bg-dark">
    <div class="container">

        <!-- Logo/Name -->
        <a class="navbar-brand" href="{% url 'notes_app:index' %}">
            MySite
        </a>

        <!-- Hamburger button (for mobile) -->
        <button
            class="navbar-toggler"
            type="button"
            data-bs-toggle="collapse"
            data-bs-target="#navbarMenu"
            aria-controls="navbarMenu"
            aria-expanded="false"
            aria-label="Toggle navigation"
        >
            <span class="navbar-toggler-icon"></span>
        </button>

        <!-- Menu (collapsed on mobile) -->
        <div class="collapse navbar-collapse" id="navbarMenu">
            <ul class="navbar-nav me-auto mb-2 mb-lg-0">
                <li class="nav-item">
                    <a class="nav-link active" aria-current="page"
                       href="{% url 'notes_app:index' %}">
                        Home
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link"
                       href="{% url 'notes_app:note_list' %}">
                        Notes
                    </a>
                </li>
                <!-- Dropdown -->
                <li class="nav-item dropdown">
                    <a class="nav-link dropdown-toggle" href="#"
                       data-bs-toggle="dropdown" aria-expanded="false">
                        More
                    </a>
                    <ul class="dropdown-menu">
                        <li><a class="dropdown-item" href="#">About us</a></li>
                        <li><hr class="dropdown-divider"></li>
                        <li><a class="dropdown-item" href="#">Contacts</a></li>
                    </ul>
                </li>
            </ul>

            <!-- Right side: search or buttons -->
            <div class="d-flex gap-2">
                {% if user.is_authenticated %}
                    <span class="navbar-text">{{ user.username }}</span>
                    <a href="{% url 'logout' %}" class="btn btn-outline-light btn-sm">
                        Log out
                    </a>
                {% else %}
                    <a href="{% url 'login' %}" class="btn btn-outline-light btn-sm">
                        Log in
                    </a>
                {% endif %}
            </div>
        </div>
    </div>
</nav>
```

### Navbar themes

Navbar themes are controlled by two classes: `navbar-dark/navbar-light` (the color of the text and icons inside) and `bg-*` (the background color). A transparent navbar for hero sections needs `position: absolute` to "float" over the content — but then the content beneath it has to be shifted down.

```html
<!-- Dark theme -->
<nav class="navbar navbar-dark bg-dark">

<!-- Light theme -->
<nav class="navbar navbar-light bg-light">

<!-- Colored -->
<nav class="navbar navbar-dark bg-primary">
<nav class="navbar navbar-dark bg-success">

<!-- Transparent (for hero sections) -->
<nav class="navbar navbar-dark" style="background: transparent; position: absolute; width: 100%;">
```

---

---
- **🧠 Mental model:** A Card is a rectangular box with an optional header, body and footer. Think of it as a physical card with information — it is self-contained and can stand next to others.
- **📚 Why it exists:** The Card is the most versatile UI pattern. Products in a shop, blog posts, user profiles, notes — they are all naturally displayed as cards.
- **🌐 What Bootstrap does under the hood:** `.card` = `position: relative; display: flex; flex-direction: column; background-color: #fff; border: 1px solid rgba(0,0,0,.125); border-radius: .375rem`. Flexbox inside the card lets `.card-footer` always stay at the bottom via `margin-top: auto`.
- **❌ Common beginner mistake:** Not adding `h-100` to cards in a grid. Without it, cards with different content have different heights — the grid looks "ragged". ALWAYS use `h-100` in card grids.
---

**Why `h-100` is mandatory in card grids:**

In a card grid (`row-cols-3`), each card in a row has its own height, which depends on its content. A card with short text will be short, one with long text will be tall. This looks chaotic.

`h-100` = `height: 100%` makes each card as tall as its column. And the column automatically has the height of the tallest card in the row (flexbox align-items: stretch). Result: all cards have the same height.

**The `g-4` class — the gutter between cards:**

`g-4` = `gap: 24px` between cards in the grid. Bootstrap uses CSS `gap` on the flex/grid container. Without `g-4`, the cards touch each other — there's no breathing room. `g-0` = no gaps, `g-5` = a large gap.

## 6. Components — Card

### Anatomy of a Card

This structure shows all the possible elements of a card. Most of them are optional: you can have just `card-body`. Note `.card-img-top` — it doesn't need `border-radius`; Bootstrap automatically rounds the top corners of the image so they match the card's `border-radius`.

```html
<div class="card">                          <!-- wrapper -->
    <img src="..." class="card-img-top" alt="...">  <!-- image on top -->
    <div class="card-header">Header</div>            <!-- header (optional) -->
    <div class="card-body">                 <!-- main content + padding -->
        <h5 class="card-title">Title</h5>
        <h6 class="card-subtitle mb-2 text-muted">Subtitle</h6>
        <p class="card-text">Card description...</p>
        <a href="#" class="btn btn-primary">Read more</a>
    </div>
    <div class="card-footer text-muted">   <!-- footer (optional) -->
        <small>Updated: 21.05.2026</small>
    </div>
</div>
```

### Card grid — row-cols

`row-cols-*` is a simplified way to set how many cards there are per row. `row-cols-1 row-cols-md-2 row-cols-lg-3` = 1 card on mobile, 2 on a tablet, 3 on a desktop. The Django template tag `{% empty %}` handles the case when the list is empty — always add it to Django templates with lists.

```html
<!-- row-cols-* → how many cards per row -->
<div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
    {% for note in notes %}
    <div class="col">
        <div class="card h-100">    <!-- h-100 — equal height for all cards -->
            <div class="card-body">
                <h5 class="card-title">{{ note.title }}</h5>
                <p class="card-text">{{ note.content|truncatewords:20 }}</p>
            </div>
            <div class="card-footer">
                <small class="text-muted">
                    {{ note.created_at|date:"d.m.Y" }}
                </small>
            </div>
        </div>
    </div>
    {% empty %}
    <div class="col-12">
        <div class="alert alert-info">No notes yet.</div>
    </div>
    {% endfor %}
</div>
```

**`g-4` → gap: 24px** between cards (gutter). `g-0`, `g-1`, ..., `g-5`.

### Card + Hover effect

A hover effect for cards is a popular pattern that gives a sense of interactivity. CSS `transition` provides a smooth animation. `translateY(-4px)` lifts the card 4px up. `box-shadow` strengthens the "lift" effect. Note: the `card-hover` class is written in your own CSS (`custom.css`), not with Bootstrap utilities — this is the right approach for custom effects.

```html
<style>
.card-hover {
    transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.card-hover:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 24px rgba(0,0,0,0.15);
}
</style>

<div class="card card-hover border-0 shadow-sm">...</div>
```

---

----
- **🧠 Mental model:** Bootstrap form classes style HTML inputs — they don't change HOW forms work, only HOW they look. Form logic (validation, saving) still lives in Django.
- **📚 Why it exists:** Native HTML inputs without styles look different in every browser. `form-control` unifies the look: the same padding, border, border-radius and focus ring in all browsers.
- **🌐 What Bootstrap does under the hood:** `form-control` generates: `display: block; width: 100%; padding: .375rem .75rem; border: 1px solid #ced4da; border-radius: .375rem; transition: border-color .15s ease-in-out, box-shadow .15s ease-in-out`. On focus, a blue shadow is added via `box-shadow`.
- **❌ Common beginner mistake:** Relying ONLY on the browser's client-side validation (`required`, `type="email"`). It can be bypassed. Django validation in `views.py` or `forms.py` is the ONLY reliable validation.
---

**Client-side vs server-side validation — critically important:**

```
Client-side (browser): fast, instant feedback, but CAN BE BYPASSED
  (anyone can disable JS or send a request via curl/Postman)

Server-side (Django): always runs, IMPOSSIBLE to bypass — this is the REAL validation
  form.is_valid() in views.py checks all Django validators

Bootstrap's .is-invalid class: only VISUALLY shows Django validation errors
  Django passes the errors in form.errors → the template renders them with Bootstrap styles
```

Rule: always validate on the server (Django). Client-side validation is just a UX improvement.

## 7. Components — Forms

### Bootstrap Forms with django-bootstrap5

This template shows a complete Bootstrap form with all field types. Note `needs-validation` and `novalidate` — this enables custom Bootstrap validation instead of the browser's native one. `.valid-feedback` and `.invalid-feedback` are shown only when the form has the `was-validated` class (added via JS). For Django projects it is often simpler to use the `django-bootstrap5` package.

```html
<!-- Standard setup -->
<form method="post" class="needs-validation" novalidate>
    {% csrf_token %}

    <!-- Field group -->
    <div class="mb-3">
        <label for="id_title" class="form-label">Title <span class="text-danger">*</span></label>
        <input
            type="text"
            class="form-control"
            id="id_title"
            name="title"
            placeholder="Enter a title"
            required
        >
        <div class="valid-feedback">Great!</div>
        <div class="invalid-feedback">Please fill in this field.</div>
    </div>

    <!-- Textarea -->
    <div class="mb-3">
        <label for="id_content" class="form-label">Text</label>
        <textarea
            class="form-control"
            id="id_content"
            name="content"
            rows="5"
            placeholder="Note text..."
        ></textarea>
        <div class="form-text">Optional field.</div>
    </div>

    <!-- Select -->
    <div class="mb-3">
        <label for="id_category" class="form-label">Category</label>
        <select class="form-select" id="id_category" name="category">
            <option value="">Choose...</option>
            <option value="work">Work</option>
            <option value="personal">Personal</option>
        </select>
    </div>

    <!-- Checkbox -->
    <div class="mb-3 form-check">
        <input type="checkbox" class="form-check-input" id="id_public" name="public">
        <label class="form-check-label" for="id_public">Public note</label>
    </div>

    <!-- Inline form -->
    <div class="row g-2 align-items-center">
        <div class="col-auto">
            <input type="text" class="form-control" placeholder="Search...">
        </div>
        <div class="col-auto">
            <button type="submit" class="btn btn-primary">Find</button>
        </div>
    </div>

    <!-- Buttons -->
    <div class="d-flex gap-2 mt-4">
        <button type="submit" class="btn btn-primary">Save</button>
        <a href="{% url 'notes_app:note_list' %}" class="btn btn-outline-secondary">
            Cancel
        </a>
    </div>
</form>
```

### Rendering a Django form with django-bootstrap5

`django-bootstrap5` is the simplest way to connect Bootstrap to Django forms. `NoteForm.Meta.widgets` lets you add Bootstrap classes to native Django widgets. The alternative: use `{% bootstrap_form form %}` and the package will automatically add all the required classes.

```python
# views.py
from django import forms
from .models import Note

class NoteForm(forms.ModelForm):
    class Meta:
        model = Note
        fields = ['title', 'content']
        widgets = {
            'title': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Note title'
            }),
            'content': forms.Textarea(attrs={
                'class': 'form-control',
                'rows': 5
            }),
        }
```

The `{% bootstrap_form form %}` tag automatically renders all fields with the correct Bootstrap classes, including validation errors. This saves dozens of lines of hand-written HTML for every form.

```html
{# Template with django-bootstrap5 #}
{% load django_bootstrap5 %}

<form method="post">
    {% csrf_token %}
    {% bootstrap_form form %}
    {% bootstrap_button "Save" button_type="submit" button_class="btn-primary" %}
</form>
```

---

---
- **🧠 Mental model:** An Alert is a temporary message that tells the user what just happened. Green = good. Red = bad. Yellow = attention. Blue = information.
- **📚 Why it exists:** Users need feedback after their actions. Saved a note? Say "Saved!". An error occurred? Say "Something went wrong". Without alerts, users don't know whether their action worked.
- **🌐 What Bootstrap does under the hood:** `alert-success` = a green background via Bootstrap CSS variables. `alert-dismissible` adds padding on the right for the close button. `fade show` — CSS transition: opacity 0.15s. The `show` class = opacity: 1. Without it, the alert is invisible (opacity: 0).
- **❌ Common beginner mistake:** Not configuring `MESSAGE_TAGS` in `settings.py`. By default Django uses the `error` tag, but Bootstrap expects `danger`. Without the mapping, `alert-error` is not a valid Bootstrap class.
---

**Django Messages → Bootstrap Alerts — how it works:**

```
Python view: messages.success(request, 'Saved!')
     ↓ The Django Messages Framework stores it in the session (cookie or DB)
Template: {% for message in messages %}
     ↓ The Django Messages Framework reads it from the session and passes it to the template
HTML: <div class="alert alert-success">Saved!</div>
     ↓ The browser renders it
The user sees: a green banner with the text "Saved!"
     ↓ After being read, messages are removed from the session (one-time flash)
```

Key point: messages are one-time messages. After being displayed, they disappear. If you refresh the page, the banner won't appear again.

## 8. Components — Alerts and Flash messages

### Django messages → Bootstrap alerts

The following Python code shows how to add a flash message in a Django view. `messages.success()`, `messages.error()`, etc. store the message in the session. They are displayed in base.html after the redirect — the classic "Post-Redirect-Get" pattern.

```python
# views.py
from django.contrib import messages

def note_create(request):
    if form.is_valid():
        form.save()
        messages.success(request, 'Note saved successfully!')
        return redirect('notes_app:note_list')
    messages.error(request, 'Error. Please check the form.')
```

This HTML fragment shows how to render Django messages with Bootstrap styles. `alert-{{ message.tags }}` substitutes the Django tag as a Bootstrap class (`alert-success`, `alert-danger`, etc.). `alert-dismissible` + `btn-close` let the user close the message with a click. `fade show` — a smooth appearance animation.

```html
{# base.html — displaying flash messages #}
{% if messages %}
<div class="container mt-2">
    {% for message in messages %}
    <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
        {{ message }}
        <button type="button" class="btn-close"
                data-bs-dismiss="alert"
                aria-label="Close">
        </button>
    </div>
    {% endfor %}
</div>
{% endif %}
```

**Mapping Django tags → Bootstrap classes:**

`MESSAGE_TAGS` in `settings.py` translates Django tags into Bootstrap classes. Without this setting, `messages.error()` generates the `error` tag, but Bootstrap expects the `alert-danger` class — and the alert won't have the right style.

```python
# settings.py
from django.contrib.messages import constants as messages
MESSAGE_TAGS = {
    messages.DEBUG:   'secondary',
    messages.INFO:    'info',
    messages.SUCCESS: 'success',
    messages.WARNING: 'warning',
    messages.ERROR:   'danger',
}
```

### Static alerts

Static alerts are for permanent messages (not flash). `role="alert"` is an important ARIA attribute: it signals to the screen reader that the content is important and should be announced immediately. `alert-link` is a special class for links inside alerts.

```html
<div class="alert alert-primary" role="alert">Information</div>
<div class="alert alert-success" role="alert">Success!</div>
<div class="alert alert-warning" role="alert">Warning!</div>
<div class="alert alert-danger" role="alert">Error!</div>

<!-- With a link -->
<div class="alert alert-info">
    Couldn't find a note?
    <a href="#" class="alert-link">Try searching</a>
</div>
```

---

---
- **🧠 Mental model:** A Modal is a dialog window that appears ON TOP of the page. The page becomes unclickable (backdrop). The user focuses on one task — confirming, filling in a form, viewing details.
- **📚 Why it exists:** Modal windows let you perform an action without navigating to a new page. "Are you sure you want to delete?" — you don't need a separate confirmation page, a modal is enough.
- **🌐 What Bootstrap does under the hood:** Bootstrap JS adds a modal-backdrop (a dark overlay) directly into `<body>`, sets `overflow: hidden` on `<body>` (the scrollbar disappears), manages z-index so the modal is always on top of everything, and tracks clicks outside the modal to close it.
- **❌ Common beginner mistake:** Placing a Modal inside a `.card` or an element with `transform`, `filter` or its own z-index stacking context. The Modal may end up under the backdrop or be positioned relative to the parent. Bootstrap recommends placing a Modal as close to the top level of the DOM as possible: in Django, at the end of `{% block content %}` outside any cards, or in a separate block before `</body>`.
---

**Why a Modal is best kept at the top level of the DOM:**

```
.modal has position: fixed, so overflow: hidden or position: relative
on an ordinary parent usually does NOT clip it. Other parents cause trouble:
a parent with transform / filter (e.g. .card-hover:hover) → the Modal is positioned relative to the parent, not the viewport, and can get clipped!
a parent with its own z-index (stacking context) → the Modal appears UNDER the backdrop or BEHIND other elements!

Solution: place the Modal as close to <body> as possible — outside .card and wrappers with transform
(in Django: the end of {% block content %} or a separate block before </body>)
```

**Modal lifecycle — from click to display:**

```
data-bs-toggle="modal" clicked
     ↓
Bootstrap JS finds data-bs-target="#deleteModal"
     ↓
The show.bs.modal event fires (can be cancelled with e.preventDefault())
     ↓
Bootstrap adds the 'show' class → the CSS transition starts (opacity: 0 → 1)
     ↓
Bootstrap adds modal-backdrop to <body>
     ↓
Bootstrap sets body { overflow: hidden } (the scrollbar disappears)
     ↓
Bootstrap fires the shown.bs.modal event (transition FINISHED)
     ↓
The user sees the modal, the page is covered by a semi-transparent backdrop
```

## 9. Components — Modal

### Modal architecture

A Modal is made of 3 layers: `modal` (the outer wrapper, positioning), `modal-dialog` (centering, size), `modal-content` (the actual look — a white rectangle). This 3-level structure is required for correct centering and animation.

```
A Modal is placed as close to the top level of the DOM as possible (Bootstrap's advice)
→ avoids z-index conflicts and transform/filter on parents
→ Bootstrap supports only ONE active modal at a time
→ When opened: body gets overflow: hidden (the scrollbar disappears)
```

The following code shows the complete Modal structure with a header, body and footer. Note `data-bs-toggle="modal"` and `data-bs-target="#deleteModal"` on the button — they must exactly match `id="deleteModal"` on the Modal wrapper.

```html
<!-- Button that opens the modal -->
<button
    type="button"
    class="btn btn-danger"
    data-bs-toggle="modal"
    data-bs-target="#deleteModal"
>
    Delete note
</button>

<!-- Modal — outside cards, as close to the top level of the DOM as possible -->
<div
    class="modal fade"
    id="deleteModal"
    tabindex="-1"
    aria-labelledby="deleteModalLabel"
    aria-hidden="true"
>
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">

            <!-- Header -->
            <div class="modal-header">
                <h5 class="modal-title" id="deleteModalLabel">
                    Confirm deletion
                </h5>
                <button type="button" class="btn-close"
                        data-bs-dismiss="modal"
                        aria-label="Close">
                </button>
            </div>

            <!-- Body -->
            <div class="modal-body">
                <p>Are you sure you want to delete the note
                   <strong id="noteTitle"></strong>?
                </p>
                <p class="text-muted">This action cannot be undone.</p>
            </div>

            <!-- Footer -->
            <div class="modal-footer">
                <button type="button"
                        class="btn btn-secondary"
                        data-bs-dismiss="modal">
                    Cancel
                </button>
                <form method="post" id="deleteForm">
                    {% csrf_token %}
                    <button type="submit" class="btn btn-danger">
                        Yes, delete
                    </button>
                </form>
            </div>

        </div>
    </div>
</div>
```

### Modal with dynamic data via JS

One Modal for many items is a common pattern. Instead of creating a separate Modal for each note, we have one Modal and fill it with data dynamically via JavaScript. The `show.bs.modal` event provides `event.relatedTarget` — the button that opened the Modal — and we read the `data-*` attributes from it.

```javascript
// Pass data from the button into the modal
const deleteModal = document.getElementById('deleteModal');
deleteModal.addEventListener('show.bs.modal', function(event) {
    // event.relatedTarget — the button that opened the modal
    const button = event.relatedTarget;
    const noteId = button.getAttribute('data-note-id');
    const noteTitle = button.getAttribute('data-note-title');

    // Update the modal's content
    document.getElementById('noteTitle').textContent = noteTitle;
    document.getElementById('deleteForm').action = `/notes/${noteId}/delete/`;
});
```

The buttons store the note's ID and title in `data-*` attributes. When any button opens the Modal, JavaScript reads this data and fills the Modal with the correct information.

```html
<!-- Buttons in the list of notes -->
{% for note in notes %}
<button
    type="button"
    class="btn btn-danger btn-sm"
    data-bs-toggle="modal"
    data-bs-target="#deleteModal"
    data-note-id="{{ note.pk }}"
    data-note-title="{{ note.title }}"
>
    Delete
</button>
{% endfor %}
```

### Modal sizes

Bootstrap provides 7 Modal sizes and 2 behavior modifiers. `modal-dialog-centered` — vertical centering (without it, the Modal is attached to the top). `modal-dialog-scrollable` — useful when the Modal's content may be long (scrolling inside the Modal rather than the page).

```html
<div class="modal-dialog modal-sm">        <!-- Small -->
<div class="modal-dialog">                 <!-- Standard -->
<div class="modal-dialog modal-lg">        <!-- Large -->
<div class="modal-dialog modal-xl">        <!-- Extra large -->
<div class="modal-dialog modal-fullscreen"> <!-- Full screen -->
<div class="modal-dialog modal-dialog-centered">  <!-- Vertically centered -->
<div class="modal-dialog modal-dialog-scrollable"> <!-- Scrolling inside -->
```

---

---
- **🧠 Mental model:** Bootstrap JS has TWO APIs — a declarative one (HTML attributes) and a programmatic one (JavaScript). Declarative = "describe what you want in HTML". Programmatic = "control behavior through code".
- **📚 Why it exists:** The declarative API (data-bs-*) is for simple cases without JS. The programmatic JS API is for dynamic scenarios where behavior has to be controlled from code (open a Modal after an AJAX load, close it after a successful submit, etc.).
- **🌐 What Bootstrap does under the hood:** When the page loads, Bootstrap JS reads the whole DOM and automatically initializes components with `data-bs-*` attributes. This happens through a `DOMContentLoaded` listener. Tooltip and Popover are the exception: they require explicit initialization via JS.
- **❌ Common beginner mistake:** Using `data-bs-toggle="tooltip"` without JavaScript initialization. Unlike Modal and Collapse, Tooltip and Popover REQUIRE a call to `new bootstrap.Tooltip(element)`.
---

**Data API = the HTML-driven approach:**

Write HTML attributes, and Bootstrap JS reads them and automatically adds behavior. You don't need to write JS. This is the "convention over configuration" approach: Bootstrap knows the standard patterns and does all the work for you.

**JS API = the programmatic approach:**

Create instances and call methods programmatically. Needed when:
- Behavior depends on the application state (open a Modal after an AJAX request)
- You need to react to lifecycle events (`shown.bs.modal`)
- You need to destroy an instance and avoid memory leaks (`modal.dispose()`)

## 10. Bootstrap JavaScript — Data API and Event Lifecycle

### The declarative approach — Data API

Bootstrap is controlled right in the HTML through `data-bs-*` attributes — **without writing JS**:

The next block shows all the main `data-bs-*` attributes. Note: Tooltip and Popover are marked as "requiring JS initialization" — this is the only exception to the rule "data attributes are initialized automatically".

```html
<!-- Modal -->
<button data-bs-toggle="modal" data-bs-target="#myModal">Open</button>

<!-- Collapse (accordion) -->
<button data-bs-toggle="collapse" data-bs-target="#collapseContent">Expand</button>
<div class="collapse" id="collapseContent">Hidden content</div>

<!-- Dropdown -->
<button class="btn dropdown-toggle" data-bs-toggle="dropdown">Menu ▼</button>

<!-- Dismiss (close an alert/modal) -->
<button data-bs-dismiss="alert" class="btn-close"></button>

<!-- Tooltip (requires JS initialization!) -->
<button data-bs-toggle="tooltip" data-bs-placement="top" title="Hint">
    Hover me
</button>

<!-- Popover (requires JS initialization!) -->
<button data-bs-toggle="popover" data-bs-content="Popover content">
    Click
</button>

<!-- Carousel autoplay -->
<div id="myCarousel" class="carousel slide" data-bs-ride="carousel">
```

### The programmatic approach — JS API

The programmatic API gives you full control over Bootstrap components from JavaScript. `new bootstrap.Modal(el)` creates an instance. `.show()`, `.hide()`, `.toggle()` are control methods. `.dispose()` — you MUST call it when you remove an element from the DOM, to avoid a memory leak.

```javascript
// Initialization (required for Tooltip and Popover)
const tooltips = document.querySelectorAll('[data-bs-toggle="tooltip"]');
tooltips.forEach(el => new bootstrap.Tooltip(el));

const popovers = document.querySelectorAll('[data-bs-toggle="popover"]');
popovers.forEach(el => new bootstrap.Popover(el));

// Controlling a modal programmatically
const modal = new bootstrap.Modal(document.getElementById('myModal'));
modal.show();
modal.hide();
modal.toggle();
modal.dispose(); // clean up the DOM, avoid a memory leak

// Controlling collapse
const collapse = new bootstrap.Collapse(document.getElementById('myCollapse'));
collapse.show();
collapse.hide();
```

### Event Lifecycle — event hooks

Bootstrap components fire events at every step of their lifecycle. This lets you hook into any moment and run custom logic. `show.bs.modal` (without "n") = before, `shown.bs.modal` (with "n") = after. The difference is critical: if you need to focus an input inside the Modal, do it in `shown`, not in `show` (the DOM isn't visible yet).

```javascript
const modalEl = document.getElementById('myModal');

// show.bs.modal → fires immediately when .show() is called
modalEl.addEventListener('show.bs.modal', function(e) {
    console.log('Modal is starting to open');
    // e.preventDefault() → cancels the opening
});

// shown.bs.modal → fires AFTER the animation finishes
modalEl.addEventListener('shown.bs.modal', function(e) {
    console.log('Modal is fully open, animation finished');
    // Here it's safe to focus an input inside the modal
    document.getElementById('myInput').focus();
});

// hide.bs.modal → before closing
modalEl.addEventListener('hide.bs.modal', function(e) {
    console.log('Modal is starting to close');
});

// hidden.bs.modal → after closing
modalEl.addEventListener('hidden.bs.modal', function(e) {
    console.log('Modal is closed');
    // Clear the form inside
    document.getElementById('myForm').reset();
});
```

**Event table for all components:**

| Component | Prefix | Events |
|-----------|--------|-------|
| Modal | `modal` | `show`, `shown`, `hide`, `hidden`, `hidePrevented` |
| Collapse | `collapse` | `show`, `shown`, `hide`, `hidden` |
| Dropdown | `dropdown` | `show`, `shown`, `hide`, `hidden` |
| Tooltip | `tooltip` | `show`, `shown`, `hide`, `hidden`, `inserted` |
| Tab | `tab` | `show`, `shown`, `hide`, `hidden` |
| Carousel | `carousel` | `slide`, `slid` |
| Toast | `toast` | `show`, `shown`, `hide`, `hidden` |

### Popper.js — dynamic positioning

Bootstrap uses **Popper.js** for Dropdown, Tooltip, Popover:

```
Without Popper: the dropdown opens downward → goes off the edge of the screen
With Popper: automatically calculates where to "open" so it fits in the viewport
```

Popper.js is already included in `bootstrap.bundle.min.js`. If you include Bootstrap separately, you need to add Popper separately before Bootstrap JS.

```html
<!-- bootstrap.bundle.min.js already includes Popper.js -->
<script src="bootstrap.bundle.min.js"></script>

<!-- OR separately: -->
<script src="popper.min.js"></script>
<script src="bootstrap.min.js"></script>
```

**Note:** For a Dropdown inside `.navbar`, Popper is **not used**.
Static positioning is sufficient inside a navbar.

---

---
- **🧠 Mental model:** ARIA (Accessible Rich Internet Applications) is a "hidden layer" of HTML, invisible to the eye but understandable to screen readers. Imagine that a screen reader is a blind but very smart reader: it reads the text and the ARIA hints to describe the structure of the page.
- **📚 Why it exists:** Websites must be accessible to people with disabilities (about 15% of the population). Laws in many countries require web accessibility (the WCAG standard). Bootstrap helps you meet these requirements out of the box.
- **🌐 What Bootstrap does under the hood:** Bootstrap JS automatically manages ARIA attributes on dynamic components. For example, when a Dropdown opens, Bootstrap JS changes `aria-expanded` from `false` to `true`. You describe the initial state, and Bootstrap keeps it up to date.
- **❌ Common beginner mistake:** Thinking it's enough to just make it look good. A button with an icon and no text (`<button><svg/></button>`) is silence for a screen reader. ALWAYS add an `aria-label` or `visually-hidden` text.
---

**Why Bootstrap includes ARIA:**

It's not enough for a site to LOOK accessible. Screen readers need SEMANTIC hints:
- `aria-current="page"` — which page is currently active
- `aria-expanded="true/false"` — whether a dropdown/collapse is open
- `aria-labelledby="id"` — what is the heading of this block
- `aria-hidden="true"` — this element is decorative, ignore it

**The `visually-hidden` pattern — invisible to the eye, visible to screen readers:**

CSS positions the element outside the viewport (1×1 pixel, clipped) — it is in the DOM and available to screen readers, but invisible to users. This is the standard pattern for adding context to icon buttons.

## 11. Accessibility in Bootstrap

### ARIA standards — required attributes

The next block shows all the key ARIA attributes in Bootstrap components. Remember the rule: every interactive element (button, link, form) must have a clear text description for screen readers — either visible, or via `aria-label`/`visually-hidden`.

```html
<!-- Navbar: aria-current for the active page -->
<a class="nav-link active" aria-current="page" href="/">Home</a>
<!-- The .active class alone isn't enough — the screen reader won't see it -->

<!-- Modal: aria-labelledby + aria-hidden -->
<div class="modal" aria-labelledby="modalTitle" aria-hidden="true">
    <h5 id="modalTitle">Modal title</h5>
</div>
<!-- aria-hidden="true" hides it from the screen reader when closed -->

<!-- Dropdown: aria-expanded -->
<button data-bs-toggle="dropdown" aria-expanded="false">Menu</button>
<!-- Bootstrap automatically changes aria-expanded to true when opened -->

<!-- Icon button: aria-label -->
<button class="btn-close" aria-label="Close"></button>
<button class="btn btn-primary">
    <i class="bi bi-heart" aria-hidden="true"></i>  <!-- the icon is decorative -->
    <span class="visually-hidden">Add to favorites</span>  <!-- text for the screen reader -->
</button>

<!-- Pagination: nav + aria-label -->
<nav aria-label="Pagination">
    <ul class="pagination">
        <li class="page-item"><a class="page-link" href="#">1</a></li>
        <li class="page-item active">
            <a class="page-link" href="#" aria-current="page">2</a>
        </li>
    </ul>
</nav>

<!-- Alert: role="alert" for an aria-live announcement -->
<div class="alert alert-danger" role="alert">
    Save error!
</div>
```

### visually-hidden — text only for screen readers

The `visually-hidden` class is the standard way to add context for screen readers without changing the appearance. The key trick: `position: absolute; width: 1px; height: 1px` — the element takes up space in the DOM but isn't visible on screen. `clip: rect(0,0,0,0)` additionally clips any possible rendering artifacts.

```html
<!-- An icon button with no visible text -->
<button class="btn btn-danger">
    <svg aria-hidden="true">...</svg>
    <span class="visually-hidden">Delete note</span>
</button>

<!-- A section heading that isn't needed visually -->
<h2 class="visually-hidden">List of notes</h2>

<!-- The CSS behind visually-hidden:
     position: absolute; width: 1px; height: 1px;
     padding: 0; margin: -1px; overflow: hidden;
     clip: rect(0,0,0,0); white-space: nowrap; border: 0; -->
```

---

## 12. Anti-patterns — Common mistakes

### Grid Anti-patterns

These anti-patterns break Bootstrap Grid. Read carefully — these are the most common mistakes found in beginners' projects.

```html
<!-- ❌ Content directly in .row -->
<div class="row">
    <p>Text directly in row</p>  ← breaks the negative margin math
</div>

<!-- ❌ Nested containers -->
<div class="container">
    <div class="container">    ← double padding
    </div>
</div>

<!-- ❌ Duplicating HTML for mobile/desktop -->
<div class="d-block d-md-none"> <!-- mobile version -->
    <div class="card">...</div>
</div>
<div class="d-none d-md-block"> <!-- desktop version -->
    <div class="card">...</div>
</div>
<!-- ✅ Correct: one HTML, responsive classes -->
<div class="col-12 col-md-6">...</div>

<!-- ❌ Horizontal scroll caused by a missing .container -->
<div class="row">  ← row without a container → the negative margin goes off screen
    <div class="col-6">...</div>
</div>
<!-- ✅ Always wrap .row in a .container -->
```

### Modal Anti-patterns

These anti-patterns are specific to Modal. The most important rule: a Modal always goes before `</body>`. The second common bug: two Modals open at the same time — Bootstrap doesn't support this and the behavior is unpredictable.

```html
<!-- ❌ Modal inside a flex/overflow container -->
<div style="overflow: hidden">
    <div class="modal">...</div>  ← the modal will be clipped!
</div>

<!-- ✅ Modal before </body> -->
<body>
    <div class="container">...</div>
    <!-- Modals always go here: -->
    <div class="modal" id="myModal">...</div>
    <script src="bootstrap.bundle.min.js"></script>
</body>

<!-- ❌ Two active modals at the same time — Bootstrap doesn't support it -->
<!-- ❌ A Modal inside a Modal — UX and the backdrop break -->
```

### JavaScript Anti-patterns

Memory leaks and incorrect initialization are the most common JS mistakes with Bootstrap.

```javascript
// ❌ Modal instance not destroyed → memory leak
const modal = new bootstrap.Modal(el);
modal.show();
// ... removed el from the DOM but didn't call modal.dispose()

// ✅ Proper destruction
modal.dispose();

// ❌ Tooltip/Popover without initialization
// data-bs-toggle="tooltip" won't work without:
// new bootstrap.Tooltip(element)

// ❌ Dropdown in a responsive table
// overflow-y: hidden from .table-responsive will clip the dropdown menu!
```

---

---
- **🧠 Mental model:** This complete example is like an assembly line: `base.html` = the factory frame (navigation, flash messages, footer), `note_list.html` = a specific product (a Grid of cards + a Modal). Every part you've learned — Grid, Navbar, Card, Modal, Flash Messages — comes together here.
- **📚 Why it exists:** Learning examples often show components separately. This example shows how they all interact in a real Django project: template inheritance, passing JS through blocks, one Modal for many items.
- **🌐 What Bootstrap does under the hood:** `d-flex flex-column min-vh-100` on `<body>` + `flex-grow-1` on `<main>` = the "sticky footer" pattern. The footer is always at the bottom of the viewport even if there's little content. `sticky-top` on the navbar = the navbar stays attached to the top while scrolling.
- **❌ Common beginner mistake:** Not understanding that `{% block extra_js %}{% endblock %}` in base.html lets child templates add page-specific JavaScript. Without this block, the JavaScript for the Modal in `note_list.html` won't be included in `base.html`.
---

**How to read this example:**

1. Start with `base.html` — it defines the overall structure: the navbar at the top, flash messages, the main content in the middle, the footer at the bottom
2. `note_list.html` extends (`{% extends %}`) `base.html` and fills `{% block content %}` with its own content
3. Note `{% block extra_js %}` at the end of `note_list.html` — this is where page-specific JavaScript is passed into the base template
4. The Modal sits at the end of `{% block content %}`, outside the cards. This works because `.modal` has `position: fixed`, and the `<main>` and `.container` wrappers in this `base.html` have no `transform` or z-index stacking context of their own. If such wrappers appear, move the Modal into a separate block before `</body>`

## 13. Complete example — Django + Bootstrap 5

### Project structure

```
notes_chat_app/
├── notes_project/
│   ├── settings.py    ← crispy_forms + crispy_bootstrap5 in INSTALLED_APPS
│   └── urls.py
├── templates/
│   └── base.html      ← Bootstrap navbar + structure (Bootstrap CSS/JS from a CDN)
└── notes_app/
    ├── views.py
    ├── urls.py
    ├── models.py
    └── templates/
        └── notes_app/
            ├── note_list.html     ← Grid of cards
            ├── note_detail.html   ← A single note
            └── note_form.html     ← Form with Bootstrap
```

### base.html

`base.html` is the foundation of the whole Django project. Note: 1) `d-flex flex-column min-vh-100` on body + `flex-grow-1` on main = the footer is always at the bottom. 2) `sticky-top` on the navbar = the navbar stays attached while scrolling. 3) Flash messages between the navbar and main — they're always visible right after an action. 4) `{% block extra_js %}` before `</body>` — for page-specific JS.

```html
{% load static %}
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Notes{% endblock %}</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css"
          rel="stylesheet">
    <link rel="stylesheet" href="{% static 'css/custom.css' %}">
</head>
<body class="d-flex flex-column min-vh-100">

    <!-- Navbar -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark sticky-top">
        <div class="container">
            <a class="navbar-brand fw-bold" href="{% url 'notes_app:index' %}">
                📝 Notes
            </a>
            <button class="navbar-toggler" type="button"
                    data-bs-toggle="collapse" data-bs-target="#navMenu">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navMenu">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link {% if request.resolver_match.url_name == 'index' %}active{% endif %}"
                           href="{% url 'notes_app:index' %}">Home</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link {% if request.resolver_match.url_name == 'note_list' %}active{% endif %}"
                           href="{% url 'notes_app:note_list' %}">Notes</a>
                    </li>
                </ul>
                <a href="{% url 'notes_app:note_create' %}" class="btn btn-outline-light btn-sm">
                    + New note
                </a>
            </div>
        </div>
    </nav>

    <!-- Flash Messages -->
    {% if messages %}
    <div class="container mt-3">
        {% for message in messages %}
        <div class="alert alert-{{ message.tags }} alert-dismissible fade show">
            {{ message }}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
        {% endfor %}
    </div>
    {% endif %}

    <!-- Main content (flex: 1 → footer at the bottom) -->
    <main class="container py-4 flex-grow-1">
        {% block content %}{% endblock %}
    </main>

    <!-- Footer -->
    <footer class="bg-dark text-light py-3 mt-auto">
        <div class="container text-center">
            <small>© 2026 Notes | Django + Bootstrap 5</small>
        </div>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
```

### note_list.html

`note_list.html` is a child template that extends `base.html`. Note: 1) A Grid of cards with `row-cols-*` and `h-100`. 2) `{% empty %}` — the empty state. 3) A Modal for delete confirmation — with dynamic data via JS. 4) `{% block extra_js %}` with JavaScript that listens for `show.bs.modal` and fills the Modal with data from the button.

```html
{% extends 'notes_app/base.html' %}

{% block title %}My notes{% endblock %}

{% block content %}
<div class="d-flex justify-content-between align-items-center mb-4">
    <h1 class="h3 mb-0">My notes</h1>
    <a href="{% url 'notes_app:note_create' %}" class="btn btn-primary">
        + New note
    </a>
</div>

{% if notes %}
<div class="row row-cols-1 row-cols-md-2 row-cols-lg-3 g-4">
    {% for note in notes %}
    <div class="col">
        <div class="card h-100 border-0 shadow-sm">
            <div class="card-body">
                <h5 class="card-title">
                    <a href="{% url 'notes_app:note_detail' pk=note.pk %}"
                       class="text-decoration-none text-dark">
                        {{ note.title }}
                    </a>
                </h5>
                {% if note.content %}
                <p class="card-text text-muted">
                    {{ note.content|truncatewords:20 }}
                </p>
                {% endif %}
            </div>
            <div class="card-footer bg-transparent border-0 d-flex justify-content-between align-items-center">
                <small class="text-muted">
                    <i class="bi bi-clock"></i>
                    {{ note.created_at|date:"d.m.Y" }}
                </small>
                <div class="d-flex gap-1">
                    <a href="{% url 'notes_app:note_detail' pk=note.pk %}"
                       class="btn btn-outline-primary btn-sm">
                        Read
                    </a>
                    <button
                        type="button"
                        class="btn btn-outline-danger btn-sm"
                        data-bs-toggle="modal"
                        data-bs-target="#deleteModal"
                        data-note-id="{{ note.pk }}"
                        data-note-title="{{ note.title }}"
                    >
                        ✕
                    </button>
                </div>
            </div>
        </div>
    </div>
    {% endfor %}
</div>

{% else %}
<div class="text-center py-5">
    <p class="lead text-muted">No notes yet.</p>
    <a href="{% url 'notes_app:note_create' %}" class="btn btn-primary btn-lg">
        Create your first note
    </a>
</div>
{% endif %}

<!-- Delete Modal -->
<div class="modal fade" id="deleteModal" tabindex="-1"
     aria-labelledby="deleteModalLabel" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="deleteModalLabel">Delete note</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                Delete the note <strong id="modalNoteTitle"></strong>?
            </div>
            <div class="modal-footer">
                <button class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                <form method="post" id="deleteForm">
                    {% csrf_token %}
                    <button type="submit" class="btn btn-danger">Delete</button>
                </form>
            </div>
        </div>
    </div>
</div>
{% endblock %}

{% block extra_js %}
<script>
const deleteModal = document.getElementById('deleteModal');
deleteModal.addEventListener('show.bs.modal', function(e) {
    const btn = e.relatedTarget;
    document.getElementById('modalNoteTitle').textContent = btn.dataset.noteTitle;
    document.getElementById('deleteForm').action = `/notes/${btn.dataset.noteId}/delete/`;
});
</script>
{% endblock %}
```

---

## 14. Self-check questions

1. Why must `<div class="row">` always be inside a `.container`?
2. What does `col-12 col-md-6 col-lg-4` mean? Describe the behavior at 3 screen sizes.
3. Why is `.btn-danger` not enough for accessibility? What needs to be added?
4. Where in the DOM should `<div class="modal">` be placed? Why?
5. `data-bs-toggle="tooltip"` doesn't work. Why? What needs to be done?
6. What is the difference between `show.bs.modal` and `shown.bs.modal`?
7. Why does Bootstrap use a negative `margin` on `.row`?
8. When should you use `container-fluid` instead of `container`?
9. What is Layout Thrashing and how is it related to Bootstrap JS?
10. Why doesn't a Bootstrap Dropdown open on hover? What is the right way?

> Questions 9–10 go beyond this chapter. Hints: Layout Thrashing is interleaving reads of DOM geometry (`offsetHeight`, `getBoundingClientRect()`) with style writes, which forces the browser to recalculate layout synchronously; Bootstrap JS itself deliberately triggers one such reflow (it reads `offsetHeight`) to restart the CSS transition in Modal/Collapse. A Dropdown opens on click on purpose: hover doesn't work on touch screens and is awkward for keyboard users, so Bootstrap keeps click (and manages `aria-expanded`).
