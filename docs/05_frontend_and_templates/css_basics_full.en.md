# CSS — Cascading Style Sheets

> CSS (Cascading Style Sheets) defines **how HTML markup looks**.
> HTML is the skeleton, CSS is the clothes and makeup.
> Three ways to include it: inline, `<style>`, an external file (recommended).

---

> **🧠 Mental model:** CSS is NOT a programming language. It is a language of DECLARATIONS. You don't tell the browser "do this in step 1, then step 2". You say: "I WANT this element to look like this" — and the browser decides on its own how to achieve it. Like ordering in a restaurant: you say what you want to eat, and the chef decides how to cook it.
>
> **📚 Why it exists:** Before CSS, all styling was embedded directly into HTML via attributes (`<font color="red">`). That led to horrible duplication — to change the color of headings across the whole site, you had to edit thousands of tags. CSS separated "what to show" from "how to show it".
>
> **🌐 CSSOM — a tree parallel to the DOM:** Just as HTML builds the DOM (Document Object Model), the browser builds the CSSOM (CSS Object Model) — a parallel tree of style rules. Only when both trees are ready does the browser combine them into the Render Tree and paint the page. That is why `<link rel="stylesheet">` in `<head>` **blocks rendering** — the browser won't paint a single pixel until it has downloaded and parsed the CSS. Slow CSS = a white screen for the user.
>
> **❌ Common beginner mistake:** Thinking that CSS "executes" top to bottom like Python. In reality, the browser first collects ALL the rules, then applies them together, resolving conflicts through the cascade and specificity. Order matters only when specificity is equal.

---

## 0. Frontend Architecture and the Rendering Pipeline

### Separation of Concerns — just like in the backend

In the backend you are used to a clear separation of responsibilities:
- **Model** — data
- **View** — logic
- **Template** — presentation

The browser works the same way:

| Layer | Responsibility |
|-----|-----------------|
| **HTML** | Structure and semantics of the data |
| **CSS** | Visual presentation |
| **JavaScript** | Behavior and dynamic changes |

> CSS never changes the HTML — it changes **DOM nodes in memory**.

---

### Rendering Pipeline — from bytes to pixels

This diagram shows the full path from your Django template to the pixels on the screen. Notice that HTML and CSS are processed **in parallel** — this is one of the reasons why CSS in `<head>` is render-blocking: the browser wants the CSSOM to be ready at the same time as the DOM.

```
[Django Template] --> HTTP Response (HTML string)
                            |
                            ▼
                  ┌─── Browser Parser ───┐
                  │                      │
               [HTML]                 [CSS]
                  │                      │
                  ▼                      ▼
             (DOM Tree)            (CSSOM Tree)
                  │                      │
                  └──────────┬───────────┘
                             ▼
                       (Render Tree)
                       (visible elements only)
                             │
                             ▼
                    [Layout / Reflow]
                    (computing sizes and positions)
                             │
                             ▼
                        [Paint]
                    (pixels on the screen)
```

### Detailed stages

**1. DOM parsing**
The browser reads HTML from top to bottom and builds a tree of objects in memory.
Each tag → a node (Node). `<p>Текст</p>` → two nodes: Element + Text.

**2. CSSOM parsing**
In parallel, the CSS is read (from `<style>` or external `.css` files).
The CSS Object Model is built — a tree of rules with computed values.

**3. Render Tree**
DOM + CSSOM are combined. Elements with `display: none` and `<head>` are excluded.
Each visible node receives its style.

**4. Layout (Reflow)**
The browser computes the exact coordinates and sizes of every element.
Result: a rectangle (x, y, width, height) for each node.

**5. Paint**
Filling in the pixels: colors, backgrounds, borders, shadows, text.

---

### Layout Thrashing — a critical performance trap

Layout Thrashing happens when JavaScript alternately reads and writes DOM properties, forcing the browser to perform a synchronous reflow after every read. Analogy: imagine a waiter you ask "how many free tables are there?" → he counts → you take one → you ask again → he counts again → and so on in a loop. Much better: count all the free seats at once, then take several.

```javascript
// ❌ BAD — Layout Thrashing
// Every read of offsetHeight forces the browser to do a synchronous reflow
for (const el of elements) {
    const h = el.offsetHeight;         // the browser recalculates layout
    el.style.height = (h + 10) + 'px'; // then changes it again
}

// ✅ GOOD — batch read, then batch write
const heights = elements.map(el => el.offsetHeight);  // all reads
heights.forEach((h, i) => {
    elements[i].style.height = (h + 10) + 'px';       // all writes
});
```

**Properties that trigger reflow:** `offsetHeight`, `offsetWidth`, `getBoundingClientRect()`,
`scrollTop`, `clientWidth`, `getComputedStyle()`.

> **Rule:** For a backend developer, Layout Thrashing is the equivalent of N+1 in the ORM:
> hundreds of queries instead of one. Always group reads separately from writes.

---

## 1. Including CSS

There are three ways to include CSS. An external file is the best one, because it is cached by the browser: after the first download the CSS file is stored locally, and subsequent pages of the site load faster. `<style>` in `<head>` is useful for small critical styles. Inline — only for dynamic values from the Django context, because it has the highest specificity and is hard to override.

```html
<!-- 1. External file (the best way — cached by the browser) -->
<link rel="stylesheet" href="style.css">

<!-- 2. A <style> block in <head> (for small styles or components) -->
<style>
    body { font-family: Arial; }
</style>

<!-- 3. Inline style (only for dynamic values via the Django context) -->
<div style="background-color: {{ user.color }}; width: 100px;">...</div>
```

---

## 2. Anatomy of a CSS rule

Every CSS rule consists of three parts: the **selector** (whom to style), the **property** (what to change) and the **value** (what to change it to). A semicolon at the end of each declaration is mandatory — without it the browser "doesn't see" the next rule. Comments in CSS are written only with `/* */`, not with `//`.

```css
/* Selector { property: value; } */

h1 {
    color: #2c3e50;          /* text color */
    font-size: 2rem;         /* font size */
    font-weight: bold;       /* font weight */
    margin-bottom: 1rem;     /* bottom margin */
}
```

---

---
> **🧠 Mental model:** CSS selectors are like SQL WHERE for the DOM. `.card p` = "SELECT all `<p>` that are INSIDE an element with class `.card`". You don't define what to do — you define WHOM to touch.
>
> **📚 Why it exists:** Without selectors you would have to style every element separately with inline styles. Selectors let you write one rule that is automatically applied to hundreds of matching elements — and when you add more of them, the styles are picked up automatically.
>
> **🌐 How the browser handles it:** The browser reads compound selectors **from right to left** for efficiency. `.card p` → first finds all `<p>` on the page, then checks whether each of them has a `.card` ancestor. That is why you should avoid overly deep selectors — the browser checks every element.
>
> **❌ Common beginner mistake:** Confusing `.btn.active` (no space — both classes on ONE element) and `.btn .active` (with a space — `.active` INSIDE `.btn`). The space is the "descendant" combinator, and it completely changes the meaning of the selector.
---

## 3. Selectors — how to select elements

### Basic selectors

Basic selectors are the foundation. A tag selects all elements of that type (careful — very broad). A class (`.`) is the most common way; one element can have several classes. An ID (`#`) is unique on the page — use it for JS hooks or anchor links, not for styling. Attribute selectors let you filter elements by the content of their attributes — useful for forms.

```css
/* Tag — all elements of this type */
p { color: #333; }
h1, h2, h3 { font-family: Georgia; }   /* several, separated by commas */

/* Class — starts with . */
.card { border: 1px solid #ddd; }
.btn.btn-primary { background: blue; } /* two classes at once (no space) */

/* ID — starts with # — unique */
#header { background: #000; }

/* Attribute */
input[type="text"] { border: 2px solid blue; }
a[href^="https"] { color: green; }     /* href starts with https */
a[href$=".pdf"] { color: red; }        /* href ends with .pdf */
a[href*="google"] { font-weight: bold; } /* href contains google */
```

### Combinators (relationships between elements)

Combinators describe **relationships** between elements in the DOM tree. A space (descendant) is the broadest: it selects elements at any nesting depth. `>` (direct child) is stricter: only immediate children. `+` and `~` are for sibling elements. Know the difference: `.nav > li` won't affect `li` in a submenu, while `.nav li` will affect everything.

```css
/* Descendant (any nesting level) */
.card p { color: #666; }

/* Direct child */
nav > ul { padding: 0; }

/* Adjacent sibling (immediately after) */
h2 + p { font-size: 1.1rem; }

/* All following siblings */
h2 ~ p { color: #555; }
```

### Pseudo-classes

Pseudo-classes let you style elements depending on their **state** or **position** in the DOM. Link states (`:hover`, `:active`) react to user actions. `:focus` is critically important for accessibility (keyboard navigation). Structural pseudo-classes (`:nth-child`) are a powerful tool for zebra-striped tables and complex lists without JavaScript.

```css
/* Link states */
a:link    { color: blue; }     /* not visited */
a:visited { color: purple; }   /* visited */
a:hover   { color: red; }      /* on mouse hover */
a:active  { color: orange; }   /* while being clicked */

/* Focus (for keyboard navigation and forms) */
input:focus { outline: 2px solid blue; border-color: blue; }
button:focus-visible { outline: 3px solid orange; }

/* Structural */
li:first-child  { font-weight: bold; }
li:last-child   { border-bottom: none; }
li:nth-child(2) { background: #f0f0f0; }     /* 2nd element */
li:nth-child(odd)  { background: #fafafa; }  /* odd */
li:nth-child(even) { background: #f0f0f0; }  /* even */
li:nth-child(3n)   { color: red; }           /* every 3rd */

/* Empty/non-empty */
p:empty { display: none; }
input:not([disabled]) { cursor: pointer; }

/* Forms */
input:valid   { border-color: green; }
input:invalid { border-color: red; }
input:required::after { content: " *"; color: red; }
input:disabled { opacity: 0.5; cursor: not-allowed; }
input:checked + label { font-weight: bold; }
```

### Pseudo-elements

Pseudo-elements (with a double `::`) create "virtual" child elements that don't exist in the HTML but are rendered by the browser. `::before` and `::after` require the `content` property — even if it is empty (`content: ""`). They are useful for decorative elements (icons, counters), so you don't clutter the HTML.

```css
/* Content before/after the element */
.card::before { content: "★ "; color: gold; }
.required::after { content: " *"; color: red; }

/* First line / first letter */
p::first-line   { font-variant: small-caps; }
p::first-letter { font-size: 3rem; float: left; }

/* Selected text */
::selection { background: #ffd700; color: #000; }

/* Placeholder in an input */
input::placeholder { color: #aaa; font-style: italic; }
```

---

---
> **🧠 Mental model:** Specificity is a 4-digit number (a, b, c, d), where each digit corresponds to a selector level: (inline, ID, class/attr/pseudo-class, tag/pseudo-element). Compare them like numbers: `(0,1,0,0)` = 100, `(0,0,10,0)` = 100 too — but an ID always beats classes, because the comparison goes left to right, digit by digit. Ten classes won't beat one ID.
>
> **📚 Why it exists:** Without specificity, the browser wouldn't know which rule to apply when two rules conflict. Specificity is a deterministic conflict-resolution algorithm that guarantees a predictable result regardless of the order in which CSS files are included.
>
> **🌐 How the browser handles it:** The browser collects ALL rules for an element, computes the specificity of each, sorts them and applies the winner. With equal specificity, the rule declared later in the file (or in a file included later) wins.
>
> **❌ Common beginner mistake:** Using `!important` to "fix" a specificity conflict. It's like yelling at the waiter instead of understanding the menu. `!important` breaks the cascade and turns CSS into chaos: when everything is important, nothing is important. The right solution is to understand why the conflict occurs and fix the structure.
---

## 4. Specificity — the conflict-resolution algorithm

### How CSS resolves conflicts (Cascade Algorithm)

When several rules try to change the same property of an element, the browser goes through a hierarchy of priorities:

```
1. !important declarations            (highest)
2. Inline styles  (style="...")
3. ID selectors   (#header)
4. Classes / Attributes / Pseudo-classes  (.card, [type], :hover)
5. Tags / Pseudo-elements             (p, h1, ::before)
6. Styles inherited from parents      (lowest)
```

With equal specificity, the **rule declared last** in the file wins.

> Item 6 is a simplification: inheritance is not a separate level of the cascade. An inherited value is used only when no rule targets the element itself for that property (and only for inherited properties such as `color` or `font-size`). That is why even the weakest selector `*` beats an inherited value.

### The math of specificity

Here is how the browser calculates the "weight" of each selector. The first digit (inline) is always the strongest — even a single inline style beats a thousand CSS rules. An ID beats any number of classes. It is not just "more = better" — it is a hierarchy of levels.

```
Inline style    →  (1, 0, 0, 0)  = 1000   (the numbers on the right are only an illustration: the comparison is column by column, not as one decimal number)
#id             →  (0, 1, 0, 0)  = 0100
.class / [attr] →  (0, 0, 1, 0)  = 0010
tag             →  (0, 0, 0, 1)  = 0001
```

Below is a practical comparison: notice how combining selectors adds up their specificity. `p.text` = tag (0,0,0,1) + class (0,0,1,0) = (0,0,1,1). That is more than just `.text` (0,0,1,0), but less than `#intro` (0,1,0,0).

```css
p                   { color: black; }    /* (0,0,0,1) =    1 */
.text               { color: blue;  }    /* (0,0,1,0) =   10 */
p.text              { color: red;   }    /* (0,0,1,1) =   11 */
#intro              { color: red;   }    /* (0,1,0,0) =  100 */
p#intro             { font-size: 100%; } /* (0,1,0,1) =  101 */
p { font-size: 75%; }                    /* (0,0,0,1) =    1 */

/* !important — overrides the algorithm, avoid it */
p { color: pink !important; }           /* beats everything without !important */
```

### Prediction Exercise

This example is a classic test of your understanding of specificity. Try to work it out yourself BEFORE looking at the answer. Each property is resolved independently — `color` and `font-size` can come from different rules.

```html
<p id="intro" class="text">Text</p>
```

```css
/* Rule 1 */ p            { color: black;     font-size: 75%;  }
/* Rule 2 */ .text        { color: blue;                       }
/* Rule 3 */ #intro       { color: red;                        }
/* Rule 4 */ p#intro      { font-size: 100%;                   }
```

**Question:** What will the element finally look like?

**Answer (property by property):**

| Property | Winner | Why |
|-------------|------------|------|
| `color` | `#intro` → **red** | (0,1,0,0)=100 > .text (0,0,1,0)=10 > p (0,0,0,1)=1 |
| `font-size` | `p#intro` → **100%** | (0,1,0,1)=101 > p (0,0,0,1)=1 |

**Summary:** The `<p>` will be **red** with a size of **100%**.

> **DevTools tip:** if you don't understand why a style isn't applied →
> F12 → the **Styles** tab (crossed-out rules lost on specificity)
> or the **Computed** tab (the final value after the whole cascade is resolved).

---

---
> **🧠 Mental model:** Every HTML element is a BOX. Always. Even a line of text is a box. Even an invisible dot is a box. Flexbox and Grid are systems for positioning these boxes. The Box Model describes what EVERY box consists of: four layers from the center outward.
>
> **📚 Why it exists:** The Box Model standardized how browsers calculate element sizes. Before it, different browsers calculated sizes differently (the IE Wars). Today all browsers follow one standard, but there are two modes: `content-box` (the standard one) and `border-box` (the practical one).
>
> **🌐 How the browser handles it:** During the Layout phase the browser computes the rectangle of each element. If `box-sizing: content-box` → `width` = the content size, and padding + border are ADDED to it. If `box-sizing: border-box` → `width` = the size from edge to edge of the border; padding and border are INCLUDED in the width. Bootstrap sets `border-box` globally via `* { box-sizing: border-box; }`.
>
> **❌ Common beginner mistake:** Setting `width: 300px; padding: 20px;` and being surprised that the element is 340px wide (300 + 20 + 20). That is `content-box` behavior. With `border-box` the element will be exactly 300px — the padding "squeezes" the content inside. Always add `box-sizing: border-box` at the beginning of your CSS.
---

## 5. Box Model — the foundation of layout

Imagine a framed picture on a wall. `content` is the picture itself. `padding` is the mat (the white material between the picture and the frame). `border` is the frame itself. `margin` is the wall space around the frame, up to the neighboring pictures. The browser always calculates the physical size of an element as content + padding + border. Margin is the space OUTSIDE the element.

```
┌─────────────────────────────────────────┐
│                 margin                  │  ← outer spacing (transparent)
│   ┌─────────────────────────────────┐   │
│   │              border             │   │  ← frame
│   │   ┌─────────────────────────┐   │   │
│   │   │          padding        │   │   │  ← inner spacing
│   │   │   ┌─────────────────┐   │   │   │
│   │   │   │     content     │   │   │   │  ← content (width × height)
│   │   │   └─────────────────┘   │   │   │
│   │   └─────────────────────────┘   │   │
│   └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

Pay special attention to the `box-sizing: border-box` line — it is one of the most important practices. Bootstrap automatically adds it to all elements via its style reset. If you write CSS without Bootstrap, add it yourself. `margin: 0 auto` on a block element with a fixed width centers it horizontally.

```css
.box {
    /* Content size */
    width: 300px;
    height: 200px;

    /* Inner spacing (between the content and the border) */
    padding: 20px;             /* all 4 sides */
    padding: 10px 20px;        /* vertical horizontal */
    padding: 10px 20px 15px 5px; /* top right bottom left (clockwise) */
    padding-top: 10px;
    padding-bottom: 15px;

    /* Border */
    border: 1px solid #ddd;
    border-radius: 8px;        /* rounded corners */
    border-top: 3px solid blue;

    /* Outer spacing (from the element to its neighbors) */
    margin: 20px;
    margin: 0 auto;            /* center the block horizontally */
    margin-bottom: 16px;
}

/* Important: box-sizing */
* {
    box-sizing: border-box;    /* width includes padding and border (Bootstrap does this by default) */
}
/* By default: box-sizing: content-box; — width = content only */
```

---

## 6. Units of measurement

| Unit | What it means | When to use it |
|---------|------------|---------------------|
| `px` | Pixels — absolute | Borders, shadows, small details |
| `rem` | Relative to the font size of `<html>` (usually 16px) | Fonts, spacing — adaptive |
| `em` | Relative to the font size of the parent element | Components that need to scale |
| `%` | Percentage of the parent element | Column widths, fluid layouts |
| `vw` | Viewport Width — % of the window width | Full-screen sections |
| `vh` | Viewport Height — % of the window height | Hero sections, full-screen |
| `fr` | Fraction — a share in CSS Grid | Grid columns/rows |
| `ch` | Width of the "0" character | Limiting text width |
| `auto` | The browser calculates it itself | Margin for centering, height |

---

## 7. Displaying elements — `display`

The `display` property defines how an element participates in the document flow. `block` takes up the whole line. `inline` — only its own content, in line. `inline-block` — like inline, but you can set its dimensions. `none` — complete removal from the flow (it takes up no space, unlike `visibility: hidden`). `flex` and `grid` are modern layout systems.

```css
/* Block — takes the full width, a new line before and after */
div, p, h1, section, article { display: block; }

/* Inline — exactly as wide as its content, in a line with other inline elements */
span, a, strong, img { display: inline; }
/* You can't set width/height on inline elements */

/* Inline-block — in a line, but you can set width/height */
.badge { display: inline-block; padding: 4px 8px; }

/* None — hide the element (takes up no space) */
.hidden { display: none; }  /* vs visibility: hidden; — takes up space but is invisible */

/* Flex — a flexible container (next section) */
.nav { display: flex; }

/* Grid — a grid system (after flex) */
.layout { display: grid; }
```

---

---
> **🧠 Mental model:** Flexbox is a 1D layout system. It arranges elements along ONE axis at a time (either a row or a column). The key point: there is a CONTAINER (`display: flex`) and there are ITEMS (all direct children). The container controls positioning, the items obey — but each item can override some rules itself via `align-self`, `order`, `flex`.
>
> **📚 Why it exists:** Before Flexbox, developers built horizontal rows with `float: left` (which required a clearfix — a hack with `overflow: hidden`) or `display: inline-block` (which had gaps between elements because of whitespace in the HTML, removed with `font-size: 0` on the parent). Flexbox is a clean, semantic replacement for these crutches.
>
> **🌐 How the browser handles it:** The browser determines the main axis (`flex-direction`) and the cross axis (perpendicular to it). `justify-content` controls distribution ALONG the main axis. `align-items` controls alignment ALONG the cross axis. These are two independent parameters, and confusing them is the most common beginner mistake.
>
> **❌ Common beginner mistake:** Not understanding the axes. If `flex-direction: column`, then `justify-content` becomes VERTICAL (along the column) and `align-items` becomes HORIZONTAL. Many beginners think that `justify-content: center` always centers horizontally — no, only along the main axis.
---

## 8. Flexbox — one-dimensional flexible layout

Before reading the code, understand the Flexbox architecture through an ASCII diagram. The main axis is the flex-direction direction. The cross axis is perpendicular to it. `justify-content` always controls the main axis. `align-items` always controls the cross axis. Remember this — and Flexbox becomes predictable.

```
Main axis (flex-direction: row) →
┌─────────────────────────────────────┐
│ [item1] [item2] [item3]             │  ← justify-content controls distribution here
└─────────────────────────────────────┘
↑
align-items controls alignment here (cross axis — vertical for row)
```

If you change to `flex-direction: column`, the axes swap places:

```
Cross axis →
┌──────────┐
│ [item1]  │  ← align-items controls here (horizontal for column)
│ [item2]  │
│ [item3]  │
└──────────┘
↓ Main axis (justify-content controls vertically for column)
```

Below is the full set of Flexbox properties with explanations. Start by understanding `display: flex`, `flex-direction`, `justify-content`, `align-items` — that covers 80% of all use cases.

```css
/* Container */
.flex-container {
    display: flex;
    flex-direction: row;            /* row | column | row-reverse | column-reverse */
    justify-content: space-between; /* alignment along the main axis */
    align-items: center;            /* alignment along the cross axis */
    flex-wrap: wrap;                /* wrap to a new line if it doesn't fit */
    gap: 16px;                      /* spacing between child elements */
}

/* justify-content values:
   flex-start  → ← ← ←  (left)
   flex-end    →     → →  (right)
   center      →   →→→   (centered)
   space-between → ← → ← → ← (equal spacing between, none at the edges)
   space-around  →  ←→ ←→ ←→  (equal spacing around each item)
   space-evenly  → ← → ← → ← → (equal spacing between all, including the edges)
*/

/* align-items values:
   flex-start  → items at the top
   flex-end    → items at the bottom
   center      → vertically centered
   stretch     → stretch to full height (default)
   baseline    → along the text baseline
*/

/* Child element */
.flex-item {
    flex: 1;           /* grow: 1, shrink: 1, basis: auto — takes an equal share */
    flex: 0 0 200px;   /* fixed width of 200px, doesn't grow, doesn't shrink */
    flex-grow: 2;      /* grows twice as much as the others */
    align-self: flex-start; /* overrides align-items for a single item */
    order: -1;         /* changes the order (default 0) */
}
```

### Common Flexbox patterns

These patterns are templates you will use every day. A navbar with a logo and a menu on opposite sides — `space-between`. Cards that wrap onto a new line — `flex-wrap: wrap` with `flex: 1 1 300px`. Centering on the screen — `justify-content: center` + `align-items: center` + `min-height: 100vh`. Sticky footer — `flex-direction: column` on `body` and `flex: 1` on `main`.

```css
/* Navbar */
.navbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 0 20px;
}

/* Cards in a row with wrapping */
.cards {
    display: flex;
    flex-wrap: wrap;
    gap: 20px;
}
.card { flex: 1 1 300px; } /* at least 300px, otherwise it wraps */

/* Centering an element */
.centered {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;     /* full screen height */
}

/* Footer at the bottom of the page */
body {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
}
main { flex: 1; } /* takes all the remaining height */
footer { /* automatically at the bottom */ }
```

---

---
> **🧠 Mental model:** Grid is a 2D layout system. Unlike Flexbox (one axis), Grid controls rows AND columns at the same time. Imagine an Excel spreadsheet: you define how many columns there are and their widths, how many rows and their heights, and then you place elements into the "cells" of that table.
>
> **📚 Why it exists:** Before Grid, complex layouts (sidebar + content + header + footer) required complex hacks with floats, tables or absolute positioning. CSS Grid is the first native 2D layout system in the browser, and it makes complex layouts trivial.
>
> **🌐 How the browser handles it:** The browser builds an invisible grid of lines (grid lines). `grid-template-columns: 250px 1fr` = two vertical "railroad tracks" that divide the space into two columns. Elements are placed between these lines. `fr` = "fractional unit" — a share of the remaining space after fixed sizes are subtracted.
>
> **❌ Common beginner mistake:** Trying to solve everything with Flexbox when the task is two-dimensional. The rule of thumb is simple: if you are thinking about rows AND columns at the same time (page layout, dashboard) → Grid. If you are thinking about one direction (buttons in a row, a list of cards) → Flexbox.
---

## 9. CSS Grid — two-dimensional grid layout

When to use Grid vs Flexbox is one of the most important decisions in layout:
- **Flexbox**: "I have some items, arrange them in a row or a column" (1D: navbar, button group, a row of cards)
- **Grid**: "I have a page with rows AND columns at the same time" (2D: dashboard, magazine layout, Holy Grail Layout)

Hint: if you are thinking about rows AND columns — Grid. If only about one direction — Flexbox.

```css
/* Container */
.grid-container {
    display: grid;
    grid-template-columns: 1fr 2fr 1fr;      /* 3 columns: 25% | 50% | 25% */
    grid-template-columns: repeat(3, 1fr);   /* 3 equal columns */
    grid-template-columns: 250px auto 1fr;   /* fixed, auto, remainder */
    grid-template-rows: auto 1fr auto;       /* header, main, footer */
    gap: 20px;                               /* between columns and rows */
    column-gap: 20px;
    row-gap: 10px;
}

/* Child element — placement */
.header  { grid-column: 1 / -1; }  /* from the 1st to the last column */
.sidebar { grid-column: 1; grid-row: 2; }
.main    { grid-column: 2 / 4; }
.footer  { grid-column: 1 / -1; }

/* Named areas */
.layout {
    display: grid;
    grid-template-areas:
        "header header header"
        "sidebar main main"
        "footer footer footer";
    grid-template-columns: 250px 1fr 1fr;
}
header { grid-area: header; }
.sidebar { grid-area: sidebar; }
main { grid-area: main; }
footer { grid-area: footer; }
```

---

---
> **🧠 Mental model:** `position: static` — the element is in the normal document flow, like houses on a street. Each one stands in its place. `position: relative` — the house moves, but its "spot" on the street stays reserved. `position: absolute` — the house has "lifted off" into the air and no longer takes up space in the flow. `position: fixed` — like a billboard stuck to your window: always in the same place regardless of scrolling.
>
> **📚 Why it exists:** Overlay elements (modals, tooltips, dropdown menus, a sticky navbar) need the ability to leave the normal flow. `position` gives you that power — but with great power comes great responsibility: positioned elements need to be kept track of, because they can cover other content.
>
> **🌐 How the browser handles it:** Positioned elements (not static) create a "stacking context" and take part in z-index sorting. An `absolute` element looks for the nearest ancestor with `position` != `static` — and is positioned relative to it. If there is no such ancestor, it is positioned relative to `<html>`.
>
> **❌ Common beginner mistake:** An element with `position: absolute` "flies off" to the wrong place. The cause: you forgot to add `position: relative` to the parent element. Always check: the parent of an absolutely positioned element must have `position: relative` (or `absolute`/`fixed`/`sticky`).
---

## 10. Positioning

`position` is one of the most powerful and most dangerous CSS properties. `static` is the default. `relative` moves the element from its normal place but keeps its space "reserved". `absolute` breaks out of the flow completely and is positioned relative to the nearest positioned ancestor. `fixed` is attached to the viewport, ideal for sticky navbars. `sticky` is a combination: it behaves like `relative` until it reaches a scroll threshold, then it "sticks".

```css
.element {
    position: static;    /* default — in the document flow */
    position: relative;  /* relative to its normal position (top/left/right/bottom) */
    position: absolute;  /* relative to the nearest non-static parent */
    position: fixed;     /* relative to the viewport (doesn't scroll) */
    position: sticky;    /* relative + fixed (sticks while scrolling) */
}

/* Sticky navbar */
nav {
    position: sticky;
    top: 0;
    z-index: 100;       /* layer: higher = on top */
    background: white;
}

/* Overlay on top of an image */
.image-container {
    position: relative;
}
.overlay {
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;   /* stretch over the whole parent */
    background: rgba(0, 0, 0, 0.5);
}

/* Centering with absolute */
.centered {
    position: absolute;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
}
```

---

---
> **🧠 Mental model:** Media queries are IF statements for CSS. `@media (min-width: 768px) { ... }` = "IF the window width >= 768px, THEN apply these styles". The browser constantly checks these conditions and instantly switches styles when the window is resized.
>
> **📚 Why Mobile First exists:** Mobile traffic overtook desktop traffic long ago. Besides, Mobile First is a better architectural strategy: base CSS for a simple mobile device, then we ADD complexity for larger screens. This is simpler than starting with desktop and CANCELING complex styles for mobile. Fewer cancellations = fewer bugs.
>
> **🌐 How the browser handles it:** The browser always loads ALL CSS rules. Media queries are not "not loaded" — they are simply not applied. That is why `<link media="print">` is always downloaded, it just isn't applied to the screen.
>
> **❌ Common beginner mistake:** Mixing Desktop First and Mobile First in one file — some rules with `max-width`, some with `min-width`. This creates unpredictable conflicts. Choose ONE approach and stick to it. Bootstrap uses `min-width` (Mobile First) — if you write CSS alongside Bootstrap, do the same.
---

## 11. Responsive design — Media Queries

A media query is a condition for CSS. Styles inside `@media` are applied only if the condition is met. `min-width` = "from this size and up" (Mobile First). `max-width` = "up to this size" (Desktop First). Start with Mobile First — it is the standard in Bootstrap and in modern web development.

```css
/* Mobile First approach (Bootstrap uses this one!) */

/* By default — styles for mobile */
.container { padding: 16px; }
.card { width: 100%; }

/* Tablet (≥768px) */
@media (min-width: 768px) {
    .card { width: 48%; display: inline-block; }
}

/* Desktop (≥992px) */
@media (min-width: 992px) {
    .container { max-width: 960px; margin: 0 auto; }
    .card { width: 30%; }
}

/* Large screen (≥1200px) */
@media (min-width: 1200px) {
    .container { max-width: 1140px; }
}

/* Orientation */
@media (orientation: landscape) { ... }

/* Dark theme */
@media (prefers-color-scheme: dark) {
    body { background: #1a1a1a; color: #fff; }
}

/* Reduced motion (accessibility) */
@media (prefers-reduced-motion: reduce) {
    * { animation: none !important; transition: none !important; }
}
```

---

## 11b. Mobile First and Bootstrap Breakpoints

### The architectural logic of Mobile First

**Mobile First** means: the base CSS is written for the **smallest screen**, then it is **progressively extended** for larger ones via `min-width` media queries.

```
❌ Desktop First (outdated approach):
   Write for large → override for small → more code, more conflicts

✅ Mobile First (modern):
   Write for small → add for large → less code, no cancellations
```

Here is why Mobile First is simpler. With Desktop First you write a complex layout for desktop and then try to "simplify" it for mobile with `max-width` — and you often forget to cancel some rules. With Mobile First you start with something simple (a single column) and ADD complexity for larger screens.

```css
/* Mobile First: the base is mobile */
.card { width: 100%; padding: 12px; }

/* Tablet and up */
@media (min-width: 768px) {
    .card { width: 48%; padding: 16px; }
}

/* Desktop and up */
@media (min-width: 992px) {
    .card { width: 31%; padding: 20px; }
}
```

**Why min-width and not max-width?**

```css
/* max-width = Desktop First — you cancel styles for small screens */
@media (max-width: 768px) { ... }

/* min-width = Mobile First — you add styles for large screens */
@media (min-width: 768px) { ... }
```

### Bootstrap 5 — Breakpoints

Bootstrap builds its grid on the same `min-width` media queries:

| Prefix | Breakpoint | min-width | Typical device |
|--------|-----------|-----------|-----------------|
| *(none)* | xs | 0px | Phones (portrait) |
| `sm` | Small | 576px | Phones (landscape) |
| `md` | Medium | 768px | Tablets |
| `lg` | Large | 992px | Desktops |
| `xl` | X-Large | 1200px | Large monitors |
| `xxl` | XX-Large | 1400px | Very large screens |

Bootstrap classes are read from left to right as Mobile First declarations. `col-12` = 100% on all screens by default. `col-md-6` = 50% on tablets and up. `col-lg-4` = 33% on desktops and up. Each subsequent breakpoint overrides the previous one.

```html
<!-- Reading the classes: Mobile First = left to right = smaller → larger -->
<div class="col-12 col-md-6 col-lg-4">Content</div>
```

**How the browser reads this code:**

```
Width 0–767px   → col-12 → 12/12 = 100% (mobile, 1 block per row)
Width 768–991px → col-md-6 → 6/12 = 50%  (tablet, 2 blocks per row)
Width 992px+    → col-lg-4 → 4/12 = 33%  (desktop, 3 blocks per row)
```

The prefix for a larger screen **always overrides** the smaller one, because in CSS the media query
with the larger `min-width` is declared later and has higher priority.

### Prediction Quiz — Bootstrap Grid

**Scenario:** there are three identical blocks in a `.row`:

```html
<div class="row">
    <div class="col-12 col-md-6 col-lg-4">Block 1</div>
    <div class="col-12 col-md-6 col-lg-4">Block 2</div>
    <div class="col-12 col-md-6 col-lg-4">Block 3</div>
</div>
```

**Question:** How many blocks per row on a tablet (800px) and on a monitor (1200px)?

**Options:**
- A) Tablet — 1 block (100%), monitor — 2 blocks (50%)
- B) Tablet — 2 blocks (50%), monitor — 3 blocks (33.3%)
- C) On both devices — 1 block (col-12 always wins)

**Answer: B**

```
800px → col-md-6 is active → each block = 6/12 = 50%
        6 + 6 = 12 → 2 blocks fit, the 3rd wraps onto a new row

1200px → col-lg-4 is active → each block = 4/12 = 33.3%
         4 + 4 + 4 = 12 → all 3 blocks in one row ✓
```

**Why C is wrong:** `col-12` is the base class for xs (0px+).
When the screen reaches 768px, `col-md-6` **overrides** `col-12` because of its higher `min-width`.
The `col-12` class doesn't "hard-lock" anything — it is just a base that larger breakpoints override.

> **Bootstrap responsive utilities** (spacing, `d-none d-lg-block`, `flex-column flex-md-row`, etc.)
> are described in [BOOTSTRAP_5.md §4](bootstrap_5_full.md) — Bootstrap Utilities.

---

## 12. CSS variables (Custom Properties)

CSS variables (Custom Properties) are named values declared with `--` and used with `var()`. Their advantage over Sass variables: they are live (they can be changed via JavaScript) and they are inherited through the DOM. Declaring them in `:root` makes them global. Declaring them in a component makes them local.

```css
/* Declaration in :root — global variables */
:root {
    --color-primary: #007bff;
    --color-secondary: #6c757d;
    --color-success: #28a745;
    --color-danger: #dc3545;
    --font-size-base: 16px;
    --border-radius: 8px;
    --shadow: 0 2px 8px rgba(0, 0, 0, 0.15);
}

/* Usage */
.btn-primary {
    background: var(--color-primary);
    border-radius: var(--border-radius);
    box-shadow: var(--shadow);
}

/* Override for a component */
.dark-card {
    --color-primary: #4dabf7;  /* local version */
}
```

---

## 13. Typography

Typography in CSS is much more than just `font-size`. A `font-family` with a "stack" of fonts guarantees a fallback font if the main one fails to load. `line-height: 1.5` without units is best practice: it scales proportionally with `font-size`. `rem` for font sizes lets the user scale text through browser settings (accessibility).

```css
body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
                 'Helvetica Neue', Arial, sans-serif;
    font-size: 16px;          /* base size */
    line-height: 1.5;         /* spacing between lines (unitless = x times font-size) */
    color: #212529;
}

/* Google Fonts */
@import url('https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap');
body { font-family: 'Roboto', sans-serif; }

h1 { font-size: 2.5rem;   line-height: 1.2; }
h2 { font-size: 2rem;     line-height: 1.3; }
h3 { font-size: 1.75rem;  line-height: 1.4; }
p  { font-size: 1rem;     line-height: 1.6; margin-bottom: 1rem; }

/* Text utilities */
.text-center    { text-align: center; }
.text-uppercase { text-transform: uppercase; }
.text-truncate  { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.text-muted     { color: #6c757d; }
```

---

---
> **🧠 Mental model:** The Holy Grail is called the "Holy Grail" of layout for a reason. For years (the 1990s to the 2010s) developers tried to implement this classic layout (header + sidebar + main content + footer) in pure CSS — and couldn't do it elegantly. Float hacks, tables, absolute positioning — everything gave either incomplete functionality or horrible code. CSS Grid finally solved the problem in 10 lines.
>
> **📚 Why macro/micro layout:** Grid is for the MACRO level (where the large page blocks are). Flexbox is for the MICRO level (how content is distributed inside a block). They are not competitors — they complement each other. A typical page: Grid for the page layout, Flexbox for the navbar, Grid or Flexbox for cards, Flexbox for forms.
>
> **🌐 How the browser handles it:** Grid containers and Flex containers can be nested inside each other. `.header { display: grid; ... }` and inside it `.header { display: flex; ... }` — that's fine. The browser processes each container independently.
>
> **❌ Common beginner mistake:** Trying to build the whole layout with only Flexbox or only Grid. The right answer is to combine them. Grid for the overall page structure, Flexbox for the components inside.
---

## 14. Holy Grail Layout — the classic page layout

The classic "Holy Grail" pattern: Header + Sidebar + Content + Footer.
It is the best illustration of combining CSS Grid (macro) and Flexbox (micro).

### HTML — structure only, no positioning

The HTML in this pattern is pure semantics. No `float`, `position`, or inline styles. The whole layout lives in CSS. Note: the order of elements in the HTML may not match the visual order — Grid lets you place them anywhere.

```html
<div class="app-layout">
    <header class="header">Logo and Navigation</header>
    <aside class="sidebar">Side menu</aside>
    <main class="content">Main content</main>
    <footer class="footer">Copyright</footer>
</div>
```

### CSS Grid — macro architecture (the building)

Grid defines the "load-bearing walls" — where the large blocks are. `1fr` means "all the remaining space". `grid-column: 1 / -1` means "from the first to the last line" — i.e. the full width. `-1` is an index from the end, like negative indexes in Python.

```css
.app-layout {
    display: grid;
    /* 2 columns: fixed left + flexible right */
    grid-template-columns: 250px 1fr;
    /* 3 rows: header | content | footer */
    grid-template-rows: 60px 1fr 50px;
    min-height: 100vh;         /* full screen height */
}

/* Header and footer — full width (both columns) */
.header { grid-column: 1 / 3; }   /* from the 1st to the 3rd vertical line */
.footer { grid-column: 1 / 3; }

/* sidebar and content — one column each (by default) */
/* sidebar → column 1, content → column 2 */
```

**How the browser calculates `1fr`:**
1. Fixed space: `250px` + `60px` + `50px`
2. `1fr` = **all the remaining** viewport — this is safer than `calc(100% - 250px)`

```
+---------------------------------------+
|                HEADER                 |  ← 60px, span 2 columns
+-----------+---------------------------+
|           |                           |
|  SIDEBAR  |         CONTENT           |  ← 1fr (takes the remaining height)
|  (250px)  |         (1fr)             |
|           |                           |
+-----------+---------------------------+
|                FOOTER                 |  ← 50px, span 2 columns
+---------------------------------------+
```

### Flexbox — micro architecture (furniture in a room)

Grid has set the size of the header. Now Flexbox arranges the content **inside** the header. This is a key pattern: Grid + Flexbox on the same element at the same time — the Grid grid-area property controls HOW the element is placed in the grid, while display: flex controls HOW the content inside the element is distributed.

```css
.header {
    grid-column: 1 / 3;          /* Grid: spans both columns */
    display: flex;               /* Flexbox: arrange the content inside */
    justify-content: space-between;  /* logo on the left, menu on the right */
    align-items: center;         /* vertically centered */
    padding: 0 20px;
    background: #2c3e50;
    color: white;
}
```

> **Key intuition:**
> **Grid** controls WHAT SIZE the header takes relative to the whole page.
> **Flexbox** controls how the HEADER'S CONTENT is distributed inside it.

### Responsiveness — Mobile First

On mobile there is no room for the sidebar next to the content — they must be stacked in a column. This responsive version switches between a single-column (mobile) and a two-column (desktop) layout via a media query. The browser performs a Reflow on every window resize.

```css
/* Mobile (default) — one column */
.app-layout {
    display: grid;
    grid-template-columns: 1fr;
    grid-template-rows: 60px auto 1fr 50px;
    min-height: 100vh;
}
.header, .footer { grid-column: 1 / 2; }

/* Desktop (≥768px) — two columns */
@media (min-width: 768px) {
    .app-layout {
        grid-template-columns: 250px 1fr;
        grid-template-rows: 60px 1fr 50px;
    }
    .header { grid-column: 1 / 3; }
    .footer { grid-column: 1 / 3; }
}
```

**What happens on resize:**
When the viewport < 768px → the browser rebuilds (Reflows) the grid on the fly.
The sidebar goes above the content — a vertical stack for mobile.

### Sticky Header with z-index

A sticky header sticks to the top while scrolling. `z-index: 100` guarantees that it stays on top of the sidebar and content. Important: `z-index` doesn't work without `position`. A sticky header automatically gets `position: sticky`, so `z-index` works here.

```css
.header {
    grid-column: 1 / 3;
    position: sticky;   /* sticks while scrolling */
    top: 0;
    z-index: 100;       /* on top of the sidebar and content while scrolling */
    background: #2c3e50;
}
/* Important: z-index works only on positioned elements
   (position: relative/absolute/fixed/sticky) */
```

---

## 15. Practical patterns

### Card

The card is the most common UI component. These styles demonstrate several important techniques: `border-radius` for rounded corners, `box-shadow` for a depth shadow, `overflow: hidden` so the image doesn't spill past the rounded corners, `transition` for a smooth hover animation, and `transform: translateY` for a "lift" effect on the card — a cheap animation that doesn't trigger reflow.

```css
.card {
    background: #fff;
    border-radius: 12px;
    box-shadow: 0 2px 12px rgba(0, 0, 0, 0.1);
    overflow: hidden;
    transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.card:hover {
    transform: translateY(-4px);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
}
.card-img { width: 100%; height: 200px; object-fit: cover; }
.card-body { padding: 16px 20px; }
.card-title { font-size: 1.25rem; font-weight: 600; margin-bottom: 8px; }
.card-text { color: #666; line-height: 1.6; }
```

### Button

A button with `display: inline-flex` is the modern approach: it lets you vertically align icons and text with `align-items: center`. `transition: all 0.2s ease` adds smoothness. `transform: translateY(-1px)` on hover gives a press effect. `cursor: pointer` is important for `<button>` and `<a>` elements styled as buttons.

```css
.btn {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 10px 20px;
    border: none;
    border-radius: 6px;
    font-size: 1rem;
    font-weight: 500;
    cursor: pointer;
    text-decoration: none;
    transition: all 0.2s ease;
}
.btn-primary { background: #007bff; color: #fff; }
.btn-primary:hover { background: #0056b3; transform: translateY(-1px); }
.btn-primary:active { transform: translateY(0); }
```

---

---
> **🧠 Mental model:** CSS debugging is detective work. You have a "crime" (a style isn't applied or looks wrong) and you have evidence (DevTools). Your job: find the "culprit" (the winning rule) by systematically narrowing down the list of suspects.
>
> **📚 Why it exists:** CSS is a declarative language without exceptions or stack traces. The browser doesn't say "error on line 42". DevTools is the only tool that gives you visibility into what the browser actually applies. Without DevTools, CSS debugging is a guessing game played blindfolded.
>
> **🌐 How the browser handles it:** The Styles tab in DevTools shows ALL rules for an element, sorted by specificity, with the losing ones crossed out. Computed shows the final value after the whole cascade is resolved. Layout shows the Box Model visually.
>
> **❌ Common beginner mistake:** Changing CSS blindly, reloading the page and being surprised. Always start with DevTools. 5 minutes in DevTools saves 50 minutes of blind edits.
---

## 16. Debugging CSS — Debugging Intuition

Before reading the algorithm, memorize a systematic checklist for any CSS problem. Follow these steps in order:

```
CSS not working? Follow this checklist:
1. Hard reload: Ctrl+Shift+R (clears the cache — the most common cause of "old" styles)
2. F12 → Elements → click on the element
3. Check the Styles panel: is your rule there?
   - Not there → the CSS file isn't loaded (check the Network tab)
   - Crossed out → specificity conflict (check which rule won)
4. Check the Computed panel → see the FINAL value
5. Check the Box Model in the Layout panel
```

### Debugging algorithm: "The style isn't applied"

```
Style not working → you changed the CSS, but the browser shows the old one?
│
├── 1. Is the file saved?
│       Ctrl+S → refresh the browser (Ctrl+Shift+R — hard reload without cache)
│
├── 2. Open DevTools (F12) → Elements tab → click on the element
│
├── 3. Look at the Styles tab (on the right)
│       ┌─────────────────────────────────────┐
│       │ .card { ... }                       │  ← active rule
│       │ ~~p { color: black; }~~             │  ← crossed out = lost
│       │ ~~.old-class { padding: 5px; }~~    │  ← crossed out = overridden
│       └─────────────────────────────────────┘
│
├── 4. If your rule is crossed out → its specificity is lower
│       See what wins → increase specificity or check the order
│
├── 5. If the rule isn't in Styles at all → the CSS isn't loaded
│       F12 → Network → find your .css file → status 200? 404?
│       Django: is {% load static %} + {% static 'css/...' %} in place?
│
└── 6. Computed tab → the final value after the whole cascade
        "Which properties actually apply to this element right now?"
```

### DevTools — step-by-step instructions

**F12 → Elements tab:**

```
┌─── HTML structure ──────────────┬─── CSS rules ────────────────────┐
│ ▼ <body>                        │ Styles  Computed  Layout  ...    │
│   ▼ <main>                      │                                  │
│     ▼ <div class="card"> ←──── │ element.style { }               │
│         <h2>Heading</h2>       │                                  │
│         <p>Text</p>             │ .card {                         │
│                                 │   border-radius: 12px;           │
│                                 │   box-shadow: ...;               │
│                                 │ }                                │
│                                 │                                  │
│                                 │ ~~div { color: red; }~~         │
│                                 │    ↑ crossed out = lost         │
└─────────────────────────────────┴──────────────────────────────────┘
```

**Box Model in the Layout tab:**

```
┌──────────────────────────────────────────┐
│              margin: 16px                │
│   ┌──────────────────────────────────┐   │
│   │           border: 1px            │   │
│   │   ┌──────────────────────────┐   │   │
│   │   │      padding: 20px       │   │   │
│   │   │   ┌──────────────────┐   │   │   │
│   │   │   │  300 × 150 px    │   │   │   │
│   │   │   └──────────────────┘   │   │   │
│   │   └──────────────────────────┘   │   │
│   └──────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

Click on any number in the Box Model to change the value right in DevTools.

### Common CSS bugs and their causes

| Symptom | Cause | Solution |
|---------|---------|---------|
| The style isn't applied | Lower specificity | DevTools → Styles → find the rule that won |
| `width: 200px` but the element is wider | `box-sizing: content-box` | Add `box-sizing: border-box` |
| `margin-top` doesn't work between two `div`s | Margin collapse | Use `padding`, `overflow: auto`, or `display: flex` |
| `z-index` doesn't raise the element | No `position: relative/absolute/fixed` | Add `position: relative` |
| A flex child is stretched to full height | `align-items: stretch` (default) | `align-items: flex-start` or `align-self: flex-start` |
| `inline-block` elements have a gap | Whitespace between tags in the HTML | Remove the spaces, or `font-size: 0` on the parent |
| `overflow: hidden` clips the shadow | `box-shadow` extends beyond the overflow boundary | Move the shadow to the parent element |
| `position: sticky` doesn't "stick" | The parent has `overflow: hidden/auto` | Remove `overflow` from the parent |
| A CSS animation stutters on mobile | `top/left` is animated instead of `transform` | Replace with `transform: translateX/Y` |

### Margin Collapse — the sneakiest bug

```html
<div style="margin-bottom: 30px">Block 1</div>
<div style="margin-top: 20px">Block 2</div>
```

**Expectation:** the distance between the blocks = 30 + 20 = 50px
**Reality:** the distance = max(30, 20) = **30px** — the margins collapse!

```
Margin Collapse happens between:
  - adjacent block elements vertically
  - a parent and its first/last child (if there is no border/padding)

It does not happen:
  - in flex containers
  - in grid containers
  - between inline-block elements
  - if there is a border or padding between them
```

**Solution:**

```css
/* Option 1: add padding instead of margin */
.parent { padding-top: 1px; }  /* breaks the collapse */

/* Option 2: make the parent a flex container */
.parent { display: flex; flex-direction: column; }

/* Option 3: overflow (a hack, avoid it) */
.parent { overflow: auto; }
```

### Stacking Context (z-index)

`z-index` is **not global** — it works inside its own stacking context.

```html
<div style="position: relative; z-index: 1;">   <!-- Context A -->
    <div style="position: relative; z-index: 999;">
        <!-- z-index=999, but it is inside context A (z-index=1) -->
    </div>
</div>

<div style="position: relative; z-index: 2;">   <!-- Context B -->
    <div style="position: relative; z-index: 1;">
        <!-- z-index=1, but the whole context B (z-index=2) is above A -->
    </div>
</div>
```

**Result:** The element with `z-index: 1` from context B will be **on top of** the element with `z-index: 999` from context A, because context B (z-index: 2) is higher than context A (z-index: 1).

**What creates a new stacking context:**
- `position` + `z-index` (not `auto`)
- `opacity < 1`
- `transform`, `filter`, `clip-path`
- `will-change`
- `isolation: isolate`

```css
/* Isolating a component from the global z-index */
.modal-wrapper {
    isolation: isolate;  /* ← explicitly create a context, protects against leaking */
}
```

---

---
> **🧠 Mental model:** CSS performance is about how expensive the operations you force the browser to perform are. Some CSS changes cost 1 unit of work (opacity), some cost 1000 units (changing width recalculates the whole layout). Knowing the "cost", you can write animations and styles that don't "slow down" the browser.
>
> **📚 Why CSS performance matters for Django:** If your CSS file is 500KB (unmodified Bootstrap + custom styles), the user sees a white screen for ALL of that download time, because CSS blocks rendering. Solution: minify (remove whitespace/comments), use only the Bootstrap components you need, include critical CSS inline and load the rest asynchronously.
>
> **🌐 GPU layers:** Some CSS properties (transform, opacity, filter) run on the GPU (Graphics Processing Unit) instead of the CPU. The GPU is specialized in parallel pixel processing — GPU animations are much smoother (60fps vs 15fps). `will-change: transform` "asks" the browser to move the element to a GPU layer in advance.
>
> **❌ Common beginner mistake:** Animating `top/left/width/height` instead of `transform`. `top: 0 → top: 100px` triggers Layout (the most expensive operation). `transform: translateY(0) → translateY(100px)` is handled by the GPU without Layout — dozens of times cheaper.
---

## 17. CSS Performance — what happens under the hood

### Critical Rendering Path

Back to the Critical Rendering Path — this time with a focus on performance. CSS is a "render-blocking" resource. The browser won't paint anything until it has downloaded and processed all the CSS in `<head>`. Therefore: minimize the CSS size, use a CDN for Bootstrap (cached across sites), consider Critical CSS (inline the most important CSS right in the HTML).

```
HTML parsing → DOM
                 \
                  → Render Tree → Layout → Paint → Composite
                 /
CSS parsing → CSSOM
```

**Render blocking:** `<link rel="stylesheet">` blocks rendering until the CSS is loaded.
That is why the Bootstrap CDN is included in `<head>` — the browser doesn't paint anything until it knows the styles.

### Properties by cost

Knowing the "cost" of CSS properties helps you write efficient animations. The general rule: if a CSS change requires recalculating the positions of other elements (Layout/Reflow), it is expensive. If it only repaints pixels without changing positions, it is cheaper. If it is handled by the GPU without the CPU, it is the cheapest.

```
Cheap (doesn't trigger layout):
  opacity, transform, filter, color, background-color

Expensive (triggers Reflow — recalculation of positions):
  width, height, margin, padding, font-size, border,
  top, left, right, bottom

Most expensive (triggers a synchronous reflow in JS):
  el.offsetHeight, el.clientWidth, el.getBoundingClientRect()
```

Here is a concrete example of why `transform` is more efficient than `left` for animations. Both look the same to the user, but one loads the CPU and triggers Layout, while the other is lightweight GPU rendering.

```css
/* ❌ An animation that triggers Layout → expensive */
@keyframes slide { from { left: 0; } to { left: 100px; } }

/* ✅ An animation only on the Composite layer → cheap */
@keyframes slide { from { transform: translateX(0); } to { transform: translateX(100px); } }
```

### will-change — a hint to the browser

`will-change` is a "warning" to the browser: "this element will change soon". The browser can move it to a GPU layer in advance, which makes the upcoming animation smoother. But don't overuse it: each GPU layer consumes video memory. Add `will-change` only to elements that WILL be animated, and remove it after the animation has finished.

```css
/* Move the element to a GPU layer in advance */
.animated-card {
    will-change: transform;  /* the browser will promote it to a GPU layer */
}
/* Remove will-change once the animation has finished — it consumes GPU memory */
```

---

## 18. Self-check questions

1. The browser received HTML and CSS at the same time. What is built first — the DOM or the CSSOM?
2. What is the difference between `display: none` and `visibility: hidden`? Which one triggers reflow?
3. There are two rules: `.card p { color: blue; }` and `#main .card p { color: red; }`. Which one wins?
4. Why does `margin: 0 auto` center a block horizontally but not vertically?
5. An element with `position: absolute` and `z-index: 999` hides behind an element with `z-index: 1`. Why?
6. Why does `width: 100%` on a flex child sometimes not take up the whole row?
7. `@media (min-width: 768px)` vs `@media (max-width: 768px)` — what is the difference in approach?
8. There is a Bootstrap class `col-12 col-md-6`. On a 900px screen, what is the width?
9. Why is `transition: all 0.3s` a bad practice for performance?
10. Which three CSS properties can be animated without triggering reflow?
