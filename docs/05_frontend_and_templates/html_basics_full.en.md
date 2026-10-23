# HTML — Markup Language Basics

> HTML (HyperText Markup Language) is a markup language that describes the **structure** of a web page.
> HTML does not program logic — it tells the browser WHAT to show.
> CSS says HOW it looks. JavaScript says WHAT happens on interaction.

---

---
> **🧠 Mental model:** HTML is a RECIPE, not a program. The browser is the COOK who follows that recipe. The DOM is the FINISHED DISH on the table.
>
> Imagine that Django is a restaurant kitchen. When a customer (the browser) places an order (an HTTP request), the kitchen (Django) takes a recipe template (an HTML template), adds the ingredients (data from the DB via the context), and sends the finished recipe (an HTML string) to the table. But the browser is not just a waiter who puts the recipe on the table: it cooks the dish (the DOM) from this recipe itself, rendering pixels on the screen.
>
> **📚 Why this exists:** Separation of responsibilities — the server is responsible for data and structure, the browser for rendering. Django does not know, and should not know, how wide the user's screen is, which browser version they use, or whether it supports CSS grid. All of that is the browser's business.
>
> **🌐 The full path from URL to pixels:**
> ```
> The user types a URL into the address bar
>         ↓
> DNS resolution: example.com → 93.184.216.34
>         ↓
> TCP connection to the server (port 80/443)
>         ↓
> HTTP GET request: GET /notes/ HTTP/1.1
>         ↓
> Nginx (reverse proxy) → Django WSGI/ASGI
>         ↓
> Django: urls.py → views.py → template render
>         ↓
> Django generates an HTML string (all {{ }} and {% %} replaced)
>         ↓
> HTTP Response: 200 OK + HTML bytes over the network
>         ↓
> Browser HTML Parser (tokenization → tree construction)
>         ↓
> DOM Tree in the browser's memory
>         ↓  (CSS is downloaded in parallel)
> CSSOM Tree
>         ↓
> Render Tree = DOM + CSSOM
>         ↓
> Layout Engine (computes the coordinates of every element)
>         ↓
> Paint (colors, shadows, borders)
>         ↓
> Composite (layers on the GPU)
>         ↓
> Pixels on the user's screen
> ```
>
> **❌ Common beginner mistake:** Thinking that HTML is a program the browser "executes" line by line like a Python script. In reality the browser builds an object model (the DOM) and renders it as a whole. That is why the browser does not "crash" on errors — it silently fixes them and keeps going.
---

## 0. How the browser interprets HTML — Core Mechanism

### From bytes to pixels: the Pipeline

```
Django Template Render
        ↓  (generates an HTML string)
HTTP Response (bytes over the network)
        ↓
Browser HTML Parser
        ↓  (Tokenization → Tree Construction)
DOM Tree (object model in memory)
        ↓  (together with CSS → Render Tree)
Layout Engine (computes sizes and positions)
        ↓
Paint (pixels on the screen)
```

### DOM — Document Object Model

When the browser receives an HTML document, it **does not execute** it like a program.
It **parses** the document and builds a tree of objects in memory — the **DOM**.

```
Document
└── <html>
    ├── <head>
    │   ├── <meta charset="UTF-8">
    │   └── <title>"My site"</title>
    └── <body>
        ├── <header>
        │   └── <nav>
        │       ├── <a href="/">"Home"</a>
        │       └── <a href="/about/">"About us"</a>
        ├── <main>
        │   ├── <h1>"Hello!"</h1>
        │   └── <p>"Text..."</p>
        └── <footer>"© 2026"</footer>
```

* **DOM** — a live tree of objects. JavaScript can modify it after the page loads.
* **HTML Source** (Ctrl+U) — the static text that Django sent. It may differ from the DOM.

> **Debugging rule:** If the layout looks wrong, open DevTools (F12) → Elements.
> There you see the **live DOM**, not the raw HTML from the server.

### Browser forgiveness — Error Recovery

The browser **does not crash** on broken HTML. It **silently fixes** errors:

```html
<!-- As written (without closing tags) -->
<ul><li>Item 1<li>Item 2</ul>

<!-- The DOM after the browser fixes it -->
<ul>
    <li>Item 1</li>    ← the browser added </li>
    <li>Item 2</li>    ← the browser added </li>
</ul>
```

```html
<!-- Incorrect nesting -->
<b><i>text</b></i>

<!-- The browser will fix it to the correct form -->
<b><i>text</i></b>
```

**The problem:** the browser hides the errors visually, but a broken DOM structure:
- Ruins SEO (Google sees a different tree)
- Breaks screen readers (accessibility)
- Causes strange bugs in JavaScript (querySelector finds the wrong element)

### HTML and design principles

| HTML concept | Design principle |
|----------------|-----------------|
| `<div>` groups elements | **Proximity** — related elements sit together |
| `<h1>` → `<h6>` hierarchy | **Contrast** — more important = bigger/bolder |
| `<ul>` / `<ol>` lists | **Alignment** — a single line on the left |
| `class="card"` on all cards | **Repetition** — the same style = a single system |
| `<header>`, `<nav>`, `<main>` | **Navigation design** — "Where am I? What is here?" |

> **Mental model:**
> HTML is the **skeleton of a building**: where the walls are, where the rooms are.
> The DOM is the architect's **3D model in CAD**: live, can be changed.
> CSS is the **interior and facade**: colors, sizes, positions.
> JavaScript is the **elevator and doors**: dynamic behavior after loading.

### What it really means for a backend developer

- **SSR (Server-Side Rendering):** Django generates the full HTML before sending it to the browser
- **SEO:** Google's crawler reads the HTML from the server — correct structure = better ranking
- **First Contentful Paint (FCP):** Ready HTML = the user sees content immediately, even before JS
- **Accessibility:** Correct semantics = screen readers read the page correctly

---

---
> **🧠 Mental model:** An HTML document is a matryoshka (a doll inside a doll). DOCTYPE wraps everything. Inside is `<html>`, which contains two dolls: `<head>` (invisible, for the browser and search engines) and `<body>` (visible, for humans). Inside `<body>` there are even more dolls — sections, articles, divs. Each doll knows only its direct children, but the whole hierarchy forms the DOM tree.
>
> **📚 Why DOCTYPE exists:** Before HTML5 (2008), browsers had two modes: "quirks mode" (compatibility with old buggy sites from the 90s) and "standards mode" (the correct CSS box model). `<!DOCTYPE html>` is a command to the browser: "Turn on standards mode, HTML5". Without a DOCTYPE, Internet Explorer switched to quirks mode, where, for example, box-sizing behaved differently and the whole layout "drifted". HTML5 simplified the DOCTYPE to the minimal form `<!DOCTYPE html>` — nothing more is needed.
>
> **🌐 What `lang="uk"` does in the browser:** (1) Google understands the page language and shows it to the right audience in search; (2) Screen readers (NVDA, VoiceOver) switch voice and pronunciation to the corresponding language; (3) Browser spell checkers know which language to check spelling in for `<textarea>`; (4) Translation features (Chrome Translate) offer translation from the correct language.
>
> **❌ Common beginner mistake:** Leaving out `<meta name="viewport">`. Without it, mobile browsers render the page at "desktop width" (~980px) and shrink it to the screen size — the text becomes microscopic. `content="width=device-width, initial-scale=1.0"` tells the browser: viewport width = device width, scale = 1:1.
---

## 1. Anatomy of an HTML document

This code block is the absolute minimum of every HTML document. The browser expects exactly this structure. `<head>` contains metadata — instructions for the browser and search engines that are not displayed on the page. `<body>` is everything the user sees and interacts with. Note: `<link rel="stylesheet">` in `<head>` is loaded before rendering — this is critical so that the page does not "flash" unstyled content (FOUC — Flash of Unstyled Content).

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Browser tab title</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <!-- All visible content goes here -->
    <h1>Hello, HTML!</h1>
</body>
</html>
```

| Element | Role |
|---------|------|
| `<!DOCTYPE html>` | Tells the browser this is HTML5 (not HTML4 or XHTML) |
| `<html lang="uk">` | The document root, `lang` is for search engines and screen readers |
| `<head>` | Metadata — not visible on the page (charset, title, CSS, meta) |
| `<meta charset="UTF-8">` | Encoding: support for Cyrillic, emoji, all languages |
| `<meta name="viewport">` | Responsive design: 1:1 scale on mobile |
| `<title>` | Text in the browser tab and in Google results |
| `<body>` | All visible content of the page |

---

---
> **🧠 Mental model:** A tag is an envelope with a letter. The opening tag `<a>` is the front of the envelope with the address (attributes). The content between the tags is the letter inside. The closing tag `</a>` is the sealed back of the envelope. Void elements (`<img>`, `<br>`, `<input>`) are postcards: they are the message themselves and do not need a wrapping envelope.
>
> **📚 Why attributes exist:** HTML without attributes is only structure. Attributes add behavior and context. `href` in `<a>` — where the link leads. `src` in `<img>` — which image to show. `type` in `<input>` — what type of field (text, email, number, checkbox). Without attributes, tags would be far too limited.
>
> **🌐 How the browser sees it:** The browser reads the opening tag, then its attributes (left to right), then the content, then the closing tag. Attributes without a value (`required`, `disabled`, `checked`) are boolean attributes: their presence = true, absence = false.
>
> **❌ Common beginner mistake:** Forgetting the closing tag on non-void elements (`<div>`, `<p>`, `<a>`). The browser will fix it, but the DOM will differ from what you expect — and querySelector will return an unexpected result.
---

## 2. Anatomy of an HTML tag

```html
<a href="https://example.com" target="_blank" class="btn">Link text</a>
 │   │                        │               │
 │   └─ href attribute        │               └─ class attribute
 │                            └─ target attribute
 └─ opening tag
                                                                   └─ closing tag
```

### Rules

- **Attributes** always go in the **opening** tag: `<tag attr="value">`
- Values go in **quotes**: `href="link"` (single or double — no difference)
- Case does not matter (`<DIV>` = `<div>`), but the standard is lowercase
- Some tags are **self-closing** (void elements): `<img>`, `<br>`, `<input>`, `<meta>`, `<link>`

---

---
> **🧠 Mental model:** Headings `<h1>`–`<h6>` are a book's table of contents. `<h1>` is the book title (only one). `<h2>` are chapters. `<h3>` are sections. Google reads this hierarchy and understands what the page is about. Skipping levels (`<h1>` → straight to `<h4>`) is like a table of contents where sub-items come right after the book title with no chapters: confusion.
>
> **📚 Why there is a difference between `<strong>`/`<em>` and `<b>`/`<i>`:** `<strong>` and `<em>` are semantic tags with "meaning". `<strong>` says: "this is important information" — a screen reader may read it louder. `<em>` says: "this is emphasis" — a screen reader may change intonation. `<b>` and `<i>` are purely visual. Use the semantic versions by default.
>
> **🌐 How the browser sees it:** `<p>` is a block element. The browser automatically adds margin-top and margin-bottom (usually 1em). `<br>` is a forced line break without a new paragraph. `<hr>` is a thematic break, displayed as a horizontal line.
>
> **❌ Common beginner mistake:** Using `<br><br>` to create spacing between paragraphs instead of CSS `margin`. This breaks the layout when font-size changes and makes maintenance harder. Spacing always belongs in CSS.
---

## 3. Headings and text

```html
<h1>Main page heading — only ONE per page</h1>
<h2>Section</h2>
<h3>Subsection</h3>
<h4>Level 4</h4>
<h5>Level 5</h5>
<h6>Smallest heading</h6>

<p>A paragraph of text. The browser automatically adds spacing above and below.</p>

<strong>Important text (bold + semantically important)</strong>
<b>Just bold (no semantics)</b>

<em>Emphasis (italic + semantically stressed)</em>
<i>Just italic (no semantics)</i>

<br>    <!-- Line break (inline) -->
<hr>    <!-- Horizontal line (block) -->

<small>Small print: copyright, caption</small>
<mark>Highlighted text (yellow marker)</mark>
<del>Strikethrough text</del>
<ins>Underlined (inserted) text</ins>
<sup>superscript</sup> — H<sub>2</sub>O (subscript)
<code>inline code</code>
<pre><code>a code block
with indentation</code></pre>
```

---

---
> **🧠 Mental model:** A link `<a>` is a portal between documents. `href` is the portal's address. Absolute URLs (`https://...`) are a portal to another site. Relative URLs (`/about/`) are a portal within the same site. Anchor links (`#section`) are a portal to another place on the same page. `<img>` is a "hole" in the document: the browser downloads the image with a separate HTTP request and inserts it into that hole.
>
> **📚 Why `rel="noopener noreferrer"` matters for security:** Without this attribute, a page opened in a new tab can get JavaScript access to the page that opened it through `window.opener` (a "reverse tabnapping" attack). `noopener` blocks this access. `noreferrer` additionally does not send the HTTP Referer header.
>
> **🌐 How the browser handles `<img>`:** The browser builds the DOM and in parallel sends a separate HTTP GET request for each `src`. Images are loaded asynchronously. If `width` and `height` are not specified, the browser does not know the sizes in advance and the page "jumps" while loading (Cumulative Layout Shift). Always specify them!
>
> **❌ Common beginner mistake:** Leaving out `alt` on `<img>`. It is not just "text if the image did not load" — it is also what Google Images indexes, what a screen reader announces, and what appears in browsers with images disabled.
---

## 4. Links and images

```html
<!-- Links -->
<a href="https://google.com">External link</a>
<a href="/about/">Internal (relative path)</a>
<a href="#section-id">Anchor on the same page</a>
<a href="mailto:email@example.com">Email</a>
<a href="tel:+380501234567">Phone</a>
<a href="https://example.com" target="_blank" rel="noopener noreferrer">
    In a new tab (rel="noopener" — security!)
</a>

<!-- Images -->
<img src="photo.jpg" alt="Image description for screen readers and SEO">
<img src="/static/img/logo.png" alt="Logo" width="200" height="100">

<!-- alt="" — empty if the image is decorative (carries no meaning) -->
<img src="decorative.jpg" alt="">
```

> **Why does `alt` matter?**
> - It is shown if the image fails to load
> - It is read by screen readers for people with visual impairments
> - It is indexed by Google Image Search

---

---
> **🧠 Mental model:** Lists are the only correct HTML for any enumeration. A navigation menu is a `<ul>` with `<li>`. Instruction steps are an `<ol>`. A glossary of terms is a `<dl>`. Do not try to build a "list" out of separate `<p>` or `<div>` elements — that breaks semantics, SEO and accessibility.
>
> **📚 Why there are three types of lists:** `<ul>` (unordered) — when order does not matter (menu items, tags). `<ol>` (ordered) — when order is critical (recipe steps, instructions, a numbered ranking). `<dl>` (definition list) — for "term: definition" pairs (a glossary, key-value metadata pairs).
>
> **🌐 How the browser sees it:** `<ul>` and `<ol>` are block elements. `<li>` is also a block element. By default the browser adds `padding-left` and bullets/numbers. CSS `list-style: none` removes the bullets — the standard technique for a navigation menu.
>
> **❌ Common beginner mistake:** Putting anything other than `<li>` inside a `<ul>`. Only `<li>` can be a direct child of `<ul>`/`<ol>`. Inside an `<li>` — anything, including nested lists.
---

## 5. Lists

```html
<!-- Unordered list (bulleted) -->
<ul>
    <li>Item 1</li>
    <li>Item 2</li>
    <li>Item 3
        <ul>
            <li>Nested item</li>  <!-- Nested lists -->
        </ul>
    </li>
</ul>

<!-- Ordered list (numbered) -->
<ol>
    <li>First step</li>
    <li>Second step</li>
    <li>Third step</li>
</ol>

<!-- Definition list -->
<dl>
    <dt>HTML</dt>
    <dd>HyperText Markup Language</dd>
    <dt>CSS</dt>
    <dd>Cascading Style Sheets</dd>
</dl>
```

---

---
> **🧠 Mental model:** An HTML table is like an Excel spreadsheet: rows (`<tr>`), column headers (`<th>`), data (`<td>`). `<thead>` is Excel's frozen first row. `<tbody>` is the scrollable data. `<tfoot>` is the totals row at the bottom. But remember: Excel is for data, not for layout. HTML tables are only for tabular data, not for positioning blocks on a page.
>
> **📚 Why `<thead>`, `<tbody>`, `<tfoot>` exist:** Semantics and accessibility: screen readers announce "table header", "row 1 of 10" and so on. When printing across several pages, `<thead>` and `<tfoot>` are repeated on every page automatically. `scope="col"` on a `<th>` tells the screen reader which column the header belongs to.
>
> **🌐 How the browser sees it:** Tables have their own layout engine — the "table layout algorithm". The browser computes column widths taking all cells into account. `colspan` and `rowspan` merge cells horizontally and vertically, respectively.
>
> **❌ Common beginner mistake:** Using `<table>` for page layout (two columns, a sidebar and content). This is an archaic practice from the 2000s. The modern solution is CSS Flexbox or Grid. Tables used for layout break responsive design and accessibility.
---

## 6. Tables

```html
<table>
    <caption>Table caption (for accessibility)</caption>
    <thead>
        <tr>
            <th scope="col">Name</th>
            <th scope="col">Age</th>
            <th scope="col">City</th>
        </tr>
    </thead>
    <tbody>
        <tr>
            <td>Oleksii</td>
            <td>25</td>
            <td>Kyiv</td>
        </tr>
        <tr>
            <td>Mariia</td>
            <td>30</td>
            <td>Lviv</td>
        </tr>
    </tbody>
    <tfoot>
        <tr>
            <td colspan="3">Total: 2 people</td>
        </tr>
    </tfoot>
</table>
```

| Element | Role |
|---------|------|
| `<table>` | The table container |
| `<thead>` | Table head (column headers) |
| `<tbody>` | Body (main data) |
| `<tfoot>` | Footer (totals) |
| `<tr>` | Table Row — a row |
| `<th>` | Table Header — a header cell |
| `<td>` | Table Data — a data cell |
| `colspan="3"` | The cell spans 3 columns |
| `rowspan="2"` | The cell spans 2 rows |

---

---
> **🧠 Mental model:** An HTML form is an envelope with a letter. The user fills in the fields (writes the letter), clicks Submit (seals the envelope and drops it into the mailbox). The browser is the post office: it reads the address (`action`), the delivery method (`method`) and delivers it. Django is the recipient: it opens the envelope and reads the contents (`request.POST`).
>
> **📚 This is the most important section for a Django developer:** Every form in Django starts with HTML. `request.POST` is not magic: it is the browser serializing the form fields and sending an HTTP POST request. Understanding this mechanism lets you debug forms without Django, test APIs with curl, and understand why `{% csrf_token %}` is not optional.
>
> **🌐 Detailed flow: from clicking Submit to `request.POST` in Django:**
> ```
> The user fills in the form:
>     <input name="username" value="Oleksii">
>     <input name="email" value="user@example.com">
>         ↓
> The user clicks the type="submit" button
>         ↓
> The browser reads the method="POST" attribute
>         ↓
> The browser serializes all <input name="x" value="y"> into a string:
>     username=Oleksii&email=user%40example.com&csrfmiddlewaretoken=abc123
>     (special characters are URL-encoded: @ → %40, space → +, non-ASCII such as Cyrillic → UTF-8 bytes like %D0%9E…)
>         ↓
> The browser sends an HTTP POST request:
>     POST /register/ HTTP/1.1
>     Host: example.com
>     Content-Type: application/x-www-form-urlencoded
>     Content-Length: 68
>
>     username=Oleksii&email=user%40example.com&csrfmiddlewaretoken=abc123
>         ↓
> Django receives the request:
>     request.method == 'POST'                    # True
>     request.POST['username'] == 'Oleksii'       # True
>     request.POST['email'] == 'user@example.com' # True (Django decodes it)
>     request.POST['csrfmiddlewaretoken'] == 'abc123'
> ```
>
> **The difference between GET and POST is not just technical, it is semantic:**
> ```
> method="GET":
>     The browser appends the data to the URL as a query string:
>     GET /search/?q=python&category=books HTTP/1.1
>
>     In Django:
>     request.GET['q'] == 'python'
>     request.GET['category'] == 'books'
>
>     When to use GET:
>     ✅ Search forms (the URL can be bookmarked)
>     ✅ Filters and sorting
>     ✅ Pagination (?page=2)
>     ❌ NOT for passwords (the URL is stored in history!)
>     ❌ NOT for large data (URLs are limited to ~2000 characters)
>
> method="POST":
>     Data in the request body (invisible in the URL)
>
>     When to use POST:
>     ✅ Login/registration (the password is not in the URL)
>     ✅ Creating/updating/deleting data
>     ✅ File uploads
>     ✅ Any state "mutations" on the server
> ```
>
> **❌ Common beginner mistake:** Forgetting `enctype="multipart/form-data"` when uploading files. Without it, the browser sends only the file name, not its contents. Django will receive an empty `request.FILES`. This is a bug that is very hard to find without understanding how forms work.
---

## 7. Forms — the most important element for Django

```html
<form method="POST" action="/submit/" enctype="multipart/form-data">
    {% csrf_token %}

    <!-- Text input -->
    <label for="name">Name:</label>
    <input type="text" id="name" name="name" placeholder="Enter your name" required>

    <!-- Email -->
    <input type="email" name="email" required>

    <!-- Password -->
    <input type="password" name="password" minlength="8">

    <!-- Number -->
    <input type="number" name="age" min="0" max="120">

    <!-- Checkbox -->
    <input type="checkbox" id="agree" name="agree" value="yes">
    <label for="agree">I agree to the terms</label>

    <!-- Radio buttons (choose one of several) -->
    <input type="radio" id="m" name="gender" value="male">
    <label for="m">Male</label>
    <input type="radio" id="f" name="gender" value="female">
    <label for="f">Female</label>

    <!-- Select (dropdown list) -->
    <select name="city">
        <option value="">Choose a city</option>
        <option value="kyiv" selected>Kyiv</option>
        <option value="lviv">Lviv</option>
        <option value="kharkiv">Kharkiv</option>
    </select>

    <!-- Textarea (multi-line text) -->
    <textarea name="message" rows="5" cols="40" placeholder="Your message..."></textarea>

    <!-- File upload -->
    <input type="file" name="photo" accept="image/*">

    <!-- Hidden field (hidden, not visible to the user) -->
    <input type="hidden" name="user_id" value="42">

    <!-- Buttons -->
    <button type="submit">Submit</button>
    <button type="reset">Clear</button>
    <button type="button" onclick="doSomething()">Just a button</button>

    <!-- An alternative to the submit button -->
    <input type="submit" value="Submit">
</form>
```

### Form attributes — critical for Django

| Attribute | Meaning | When to use |
|---------|---------|---------------------|
| `method="GET"` | Data in the URL: `?name=value` | Search, filters |
| `method="POST"` | Data in the request body | Creating/changing data |
| `action="/url/"` | Where to send it | Always specify it, or Django will handle the current URL |
| `enctype="multipart/form-data"` | For files | Required if there is an `<input type="file">` |
| `novalidate` | Disables browser validation | For testing or custom validation |

---

---
> **🧠 Mental model:** Non-semantic HTML is a city without street signs and street names. People (users) can still find their way by the buildings, but GPS (Google, Bing) and the navigator for blind people (the screen reader) are completely lost. Semantic HTML is the same city, but with proper street signs, district names and direction markers. Everyone finds their way instantly.
>
> **📚 Why semantics matters for Google:** Consider two variants:
> ```
> ❌ <div class="nav">               ✅ <nav>
>      <a href="/">Home</a>               <a href="/">Home</a>
>    </div>                           </nav>
> ```
> Both look the same in the browser. But for Google: `<div class="nav">` is just a block with the class "nav" (Google does not know what you meant). `<nav>` is navigation. Google understands it as "here are links for navigating the site" and builds a better site map, determines link importance, and understands the structure.
>
> **🌐 How a screen reader uses semantics:** A screen reader (NVDA, VoiceOver) reads ARIA "roles". `<header>` has the role "banner". `<nav>` — "navigation". `<main>` — "main". `<footer>` — "contentinfo". A blind user can press 'H' (headings), 'F' (forms), 'L' (lists), 'N' (navigation) — and the screen reader instantly jumps to the corresponding semantic block. With `<div>` this is impossible.
>
> **❌ Common beginner mistake:** Thinking that semantics is "a recommendation for the good kids". In reality: non-semantic markup = worse SEO ranking = less traffic = less money. In commercial projects, the difference in semantics can mean the difference in your position on Google.
---

## 8. HTML5 semantic markup

**Semantic tags** are tags with **meaning**: the browser, Google and screen readers understand what they are.

```
❌ Non-semantic:
<div id="header">...</div>
<div class="nav">...</div>
<div class="main">...</div>
<div class="sidebar">...</div>
<div id="footer">...</div>

✅ Semantic:
<header>...</header>
<nav>...</nav>
<main>...</main>
<aside>...</aside>
<footer>...</footer>
```

### The full map of semantic tags

```html
<header>
    <!-- Page or section header: logo, navigation, title -->
    <nav>
        <!-- Navigation links — main menu, pagination -->
    </nav>
</header>

<main>
    <!-- ONE per page. The main unique content -->

    <article>
        <!-- Independent content: a blog post, a news item, a comment -->
        <header>
            <h2>Article title</h2>
            <time datetime="2026-05-21">May 21, 2026</time>
        </header>
        <p>Article text...</p>
        <footer>Author: Ivan</footer>
    </article>

    <section>
        <!-- A thematic section with a heading — "Services", "Contacts" -->
        <h2>Our services</h2>
        <p>...</p>
    </section>
</main>

<aside>
    <!-- Sidebar: ads, tags, related links -->
</aside>

<footer>
    <!-- Footer: copyright, contacts, site map -->
    <address>
        <!-- Contact information of the author/organization -->
        Email: <a href="mailto:info@example.com">info@example.com</a>
    </address>
</footer>

<!-- Other semantic tags -->
<figure>
    <img src="chart.png" alt="Sales chart">
    <figcaption>Sales chart for 2026</figcaption>
</figure>

<details>
    <summary>Click to expand</summary>
    <p>Hidden content</p>
</details>

<dialog id="myDialog">
    <!-- A native modal dialog (without JS libraries) -->
</dialog>
```

---

---
> **🧠 Mental model:** `<div>` is a transparent box with no label. `<span>` is a transparent unlabeled wrapper for inline content. They are used only when none of the "named" boxes (`<section>`, `<article>`, `<nav>`, `<aside>`) fits. The rule: first check all the semantic tags — if none fits, then use `<div>`.
>
> **📚 Why `<div>` and `<span>` exist at all:** Not every UI pattern has a semantic equivalent. Is "a product card in a shop" an `<article>` or a `<div>`? "A column in a grid layout" is definitely a `<div>`. "A discounted price" is a `<span>` with a CSS class. These tags are building material for CSS and JavaScript where there is no suitable semantic tag.
>
> **🌐 How the browser sees `<div>` and `<span>`:** `<div>` is `display: block` by default (takes the full width). `<span>` is `display: inline` (takes exactly as much space as its content). The browser gives them no ARIA role — they are "invisible" to the accessibility tree without additional attributes.
>
> **❌ Common beginner mistake:** "Div soup" — markup made entirely of `<div>` without a single semantic tag. It looks the same in the browser, but Google and screen readers get a "soup" with no structure. The problem is quick to diagnose: open F12 → Elements and count the `<div>`s — if they make up more than 80% of all tags, there is a problem.
---

## 9. `<div>` and `<span>` — non-semantic containers

```html
<!-- div — a block container (takes the full width of the line) -->
<div class="card">
    <div class="card-header">Title</div>
    <div class="card-body">Card content</div>
</div>

<!-- span — an inline container (exactly the size of its content) -->
<p>
    Price: <span class="price text-danger">1500 UAH</span>
    (with a discount <span class="badge">-20%</span>)
</p>
```

**Rule:** use `<div>` and `<span>` when no semantic tag fits.
If `<section>`, `<article>` or `<nav>` fits — use them.

---

---
> **🧠 Mental model:** `id` is a passport (unique across the whole document). `class` is a uniform (the same for everyone who wears it). A passport is used to identify a specific person. A uniform is for styling everyone with the same role.
>
> **📚 Why both `id` and `class` exist:** `id` is for unique elements: the main page content, a specific form, a section for an anchor link. The CSS specificity of `id` is higher than that of `class` — this can cause problems when overriding styles. `class` is for repeating patterns: cards, buttons, badges. In modern practice `id` is used mainly for JavaScript, anchor links and linking `<label for="">` / `<input id="">`.
>
> **🌐 How the browser uses `id` and `class`:** The CSS selector `#id` has specificity 0-1-0-0. `.class` — 0-0-1-0. `tag` — 0-0-0-1. That is why `#header p { color: red }` beats `.content p { color: blue }` even if the second one is written later — because of the higher specificity of `#header`.
>
> **❌ Common beginner mistake:** Duplicating an `id` on a page. An `id` must be UNIQUE. If there are two `<div id="card">`, CSS and JavaScript will behave unpredictably: `getElementById` returns only the first one, while CSS may apply to both (browsers forgive this, but it is a bug).
---

## 10. The `id` and `class` attributes

```html
<!-- id — a unique identifier, ONE per page -->
<section id="about">...</section>

<!-- Usage: -->
<!-- 1. Link anchor: <a href="#about"> -->
<!-- 2. CSS: #about { background: blue; } -->
<!-- 3. JavaScript: document.getElementById('about') -->
<!-- 4. Linking label↔input: <label for="email"> + <input id="email"> -->

<!-- class — can be used many times -->
<div class="card">...</div>
<div class="card">...</div>
<div class="card featured">...</div>  <!-- several classes separated by spaces -->

<!-- Using class in CSS: .card { border: 1px solid; } -->
<!-- Using class in JS: document.querySelectorAll('.card') -->
```

---

---
> **🧠 Mental model:** Meta tags in `<head>` are the packing slip on a shipping crate. The contents of the box (`<body>`) are for people. The packing slip (`<head>`) is for the system: what is inside, where it is from, where it is going, how to handle it. Google, Facebook and Twitter read this "packing slip" before showing the content to the user.
>
> **📚 Why Open Graph exists:** When you share a link on Facebook, Telegram or LinkedIn, these platforms do not open the page "live". They send their bot, which reads only `<head>` and the OG meta tags. If `og:image` is not specified, Telegram will show the link without a preview. If `og:title` is missing, it will take `<title>`. Correct OG tags = a nice preview = more clicks.
>
> **🌐 What `<title>` does in the browser:** (1) The text in the browser tab; (2) The title in Google search results (the first 50-60 characters); (3) The name when bookmarking; (4) The name in the OS task switcher. It is the only element with such broad "visibility" outside the browser.
>
> **❌ Common beginner mistake:** The same `<title>` on every page of the site. Google treats this as "duplicate content" and lowers the ranking. In Django, use `{% block title %}{{ object.name }} | Мій сайт{% endblock %}` for unique titles.
---

## 11. Meta tags for SEO and social networks

```html
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <!-- SEO -->
    <title>Page title (50–60 characters) | Site name</title>
    <meta name="description" content="Page description for Google (150–160 characters)">
    <meta name="keywords" content="html, css, bootstrap, django">  <!-- outdated, but still exists -->
    <meta name="robots" content="index, follow">

    <!-- Open Graph (Facebook, Telegram, LinkedIn) -->
    <meta property="og:title" content="Title">
    <meta property="og:description" content="Description">
    <meta property="og:image" content="https://example.com/image.jpg">
    <meta property="og:url" content="https://example.com/page">
    <meta property="og:type" content="website">

    <!-- Twitter Cards -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="Title">

    <!-- Favicon -->
    <link rel="icon" href="/favicon.ico" type="image/x-icon">
    <link rel="icon" href="/favicon.svg" type="image/svg+xml">
</head>
```

---

These mistakes are not just "bad style". Each one has a concrete negative consequence: broken SEO (less traffic), an inaccessible site (a violation of accessibility law), or a broken Django form (lost data or 403 Forbidden). Treat this list as a checklist before every code review.

---
> **🧠 Mental model:** These mistakes are like building code violations. The house may stand (the browser will render it), but at the first inspection (an SEO audit, an accessibility audit, a Django form) everything falls apart.
>
> **📚 Why this matters for a Django developer:** `<b>` instead of `<strong>` — an SEO hit. Several `<h1>`s — Google does not understand the main topic of the page. `<br>` for spacing — breaks when the font changes. Tables for layout — break on mobile. No `alt` — a penalty from Google. Inline `style=""` — impossible to change through CSS. No `{% csrf_token %}` — Django returns 403 and the form does not work. Mismatched `for`/`id` — clicking a `<label>` does not focus the `<input>`, which is critical for mobile and accessibility.
>
> **🌐 How the browser sees common mistakes:** `<br><br>` — the browser displays empty lines, but a screen reader reads them as "blank line, blank line". `<table>` for layout — the browser applies the table layout algorithm: columns shrink to the minimum content width, which breaks responsive design. Inline `style=""` — specificity 1-0-0-0, which can only be overridden with `!important`.
>
> **❌ Common beginner mistake:** Believing that if the page "looks right" in the browser, everything is fine. The browser forgives and visually fixes errors, but Google, screen readers and Django are not so kind-hearted.
---

## 12. Common beginner mistakes

| Mistake | Rule |
|---------|---------|
| `<b>` instead of `<strong>` for important text | `<strong>` is semantically important, `<b>` is only visual |
| Several `<h1>`s on a page | One `<h1>` — it is the main heading for SEO |
| `<br><br><br>` for spacing | Spacing goes through CSS `margin`/`padding` |
| Tables for page layout | Tables are only for tabular data. Layout — CSS Grid/Flexbox |
| No `alt` on `<img>` | `alt` is required (even `alt=""` for decorative images) |
| `<div>` instead of semantic tags | Check first: is there a `<header>`, `<nav>`, `<main>`, `<article>`? |
| Inline styles `style="..."` | Styles go in a CSS file or `<style>`. Inline only for dynamic values |
| No `{% csrf_token %}` in POST forms | Django rejects the request with 403 Forbidden |
| `for` on `<label>` does not match `id` on `<input>` | Clicking the label does not activate the input |

---

---
> **🧠 Mental model:** Block elements are PARAGRAPHS. Imagine the Word text editor: each paragraph takes the full width of the page and starts on a new line. Inline elements are WORDS in a paragraph. A bold word, an italic word, a link — they flow along with the rest of the text without breaking the line.
>
> **📚 Why this is fundamental for CSS:** A rule that surprises EVERY beginner: `width` and `height` do not work on inline elements. If you write `span { width: 200px; }`, nothing happens. The span stays as wide as its content. This is not a bug — it is the specification: inline elements flow like text, and text has no fixed width.
> The solution: `display: inline-block` or `display: block` — then all CSS properties start working.
>
> **🌐 Visual diagram of Block vs Inline:**
> ```
> ┌─────────────────────────────────────────┐
> │ <div>: Block — takes the whole line     │
> └─────────────────────────────────────────┘
> ┌─────────────────────────────────────────┐
> │ <p>: Block — also takes the whole line  │
> └─────────────────────────────────────────┘
> Text <a>link</a> and more text on the line │ ← Inline in the text flow
> <span>word</span> and another <em>word</em> │ ← Inline side by side
> ─────────────────────────────────────────
> ┌──────────────────────────────────────────┐
> │ <div>: Block starts a new line again     │
> └──────────────────────────────────────────┘
> ```
>
> **❌ Common beginner mistake:** Trying to set `width: 100px; height: 50px; padding: 20px` on a `<span>` or `<a>` and wondering why it does not work. The fix: add `display: inline-block` or `display: block`. This is one of the most common sticking points when learning CSS.
---

## 13. Block vs Inline — the document flow model

Every HTML element has a **default display type**.
This is a fundamental concept — it explains why elements are positioned the way they are and not otherwise.

### Block elements

- Take the **full available width** of the parent container
- Start on a **new line**
- You can set `width`, `height`, `margin`, `padding` on all 4 sides

```html
<div>  <p>  <h1>–<h6>  <ul>  <ol>  <li>
<header>  <nav>  <main>  <section>  <article>
<aside>  <footer>  <form>  <table>  <blockquote>
<hr>  <pre>  <figure>  <figcaption>  <address>
```

### Inline elements

- Take **exactly as much space as their content**
- Are placed **in the line** next to other inline elements
- `width` and `height` **do not work** (the width is determined by the content)
- Vertical `margin`/`padding` is limited

```html
<span>  <a>  <strong>  <em>  <b>  <i>
<img>  <input>  <label>  <button>  <select>
<code>  <abbr>  <small>  <sup>  <sub>  <br>
```

### Prediction Exercise

```html
<!-- How will the browser render this code? -->
<h1>Heading</h1>
<a href="#">Link</a> ← one more line here
```

**Answer:**

```
┌───────────────────────────────────┐
│             Heading               │  ← <h1> block: takes the full width
└───────────────────────────────────┘
Link ← one more line here              ← <a> inline: side by side on one line
```

`<h1>` is block → forces a line break before and after itself.
`<a>` is inline → sits next to the neighboring text without a line break.

### Inline-block — a hybrid

```css
/* display: inline-block — in the line, but with the full box model */
.badge {
    display: inline-block;
    padding: 4px 10px;    /* ← vertical padding WORKS (unlike inline) */
    width: 80px;          /* ← width WORKS (unlike inline) */
    background: #007bff;
}
```

```html
<!-- Usage: tags, badges, buttons next to text -->
<p>
    Status: <span class="badge">Active</span>
    Level: <span class="badge">Senior</span>
</p>
```

### Comparison table

| | Block | Inline | Inline-block |
|-|-------|--------|--------------|
| New line | Yes | No | No |
| `width` / `height` | Yes | No | Yes |
| `margin` (all 4) | Yes | Horizontal only | Yes |
| `padding` (all 4) | Yes | Horizontal only | Yes |
| Examples | `<div>`, `<p>`, `<h1>` | `<span>`, `<a>`, `<strong>` | `<button>`, `.badge` |

---

---
> **🧠 Mental model:** Imagine you are an architect designing a building. Accessibility is the ramps, elevators, tactile paving, Braille on the buttons. You can build the building without them — it will be "beautiful". But 15-20% of people (this is the real statistic of people with various kinds of impairments) will not be able to use it. And in many countries you will also be fined.
>
> **📚 Why a11y is not optional (legal context):**
> - **EU (European Union):** Directive 2016/2102 and EN 301 549 — mandatory accessibility for all EU public-sector websites. Private companies that sell in the EU fall under the European Accessibility Act (2025+).
> - **USA:** Americans with Disabilities Act (ADA) — courts have already ruled against companies for inaccessible websites (the Domino's Pizza case, 2019).
> - **UK:** Public Sector Bodies Accessibility Regulations (PSBAR) — public-sector websites must comply with WCAG 2.1 AA.
> - **In practice:** Even if your project does not fall under these laws right now, a client from the EU may set it as a requirement. Better to learn it right away.
>
> **🌐 How a screen reader navigates a page:** A blind user with NVDA (Windows) or VoiceOver (Mac/iOS) does not use a mouse. Here is a typical session:
> ```
> Tab → move between interactive elements (links, buttons, inputs)
> H   → jump to the next heading (h1, h2, h3...)
> F   → jump to the next form field
> L   → jump to the next list
> N   → jump to the next navigation block
> Ins+F7 → list of all links on the page
> ```
> If your "navigation" is built from `<div>` instead of `<nav>`, the 'N' key will not find it. If a button is a `<div onclick="...">` instead of a `<button>`, Tab will not reach it.
>
> **DevTools Accessibility Audit (step by step):**
> 1. Open F12 (DevTools)
> 2. Find the "Lighthouse" tab (formerly "Audits")
> 3. Select only "Accessibility" (uncheck the rest)
> 4. Click "Analyze page load"
> 5. You will get a score from 0 to 100 + a list of specific problems with explanations
> Also: F12 → Elements → select an element → in the right panel find the "Accessibility" tab — you will see that element's ARIA tree.
>
> **❌ Common beginner mistake:** Removing `outline` in CSS without a replacement: `button { outline: none; }`. The outline is the visual focus indicator for keyboard users. Without it, they cannot see where the focus is and cannot navigate. The right way: replace it with a custom `outline` or `box-shadow`, but do not remove it completely.
---

## 14. Accessibility (a11y)

> An accessible site works for everyone: people with visual, hearing and motor impairments.
> It is not a "bonus feature" — in many countries it is a legal requirement.

### ARIA attributes — meaning hints

```html
<!-- role — says what the element is (if the tag is non-semantic) -->
<div role="navigation">...</div>         <!-- = <nav> -->
<div role="main">...</div>               <!-- = <main> -->
<div role="button" tabindex="0">Click</div>  <!-- custom button -->

<!-- aria-label — an accessible name for the screen reader -->
<button aria-label="Close dialog">✕</button>
<input type="search" aria-label="Search the site">
<nav aria-label="Main navigation">...</nav>
<nav aria-label="Pagination">...</nav>

<!-- aria-hidden — hide from the screen reader (decorative elements) -->
<span aria-hidden="true">★★★★☆</span>
<span class="sr-only">4 stars out of 5</span>  <!-- for screen readers only -->

<!-- aria-expanded — expanded state (menu, accordion) -->
<button aria-expanded="false" aria-controls="menu">Menu ▼</button>
<ul id="menu" hidden>...</ul>

<!-- aria-live — dynamic content that updates -->
<div aria-live="polite" id="status">Loading...</div>

<!-- aria-describedby — an additional description of the element -->
<input type="password" id="pwd" aria-describedby="pwd-hint">
<small id="pwd-hint">At least 8 characters, one digit</small>

<!-- aria-required — a required field -->
<input type="email" aria-required="true" required>
```

### Focus navigation (Keyboard Navigation)

```html
<!-- tabindex — the order of navigation with the Tab key -->
<div tabindex="0">A focusable div (natural order)</div>
<div tabindex="-1">Can be focused via JS, but not with Tab</div>
<!-- tabindex="1", "2"... — avoid! It breaks the natural order -->

<!-- Focus trap in a modal window (requires JS) -->
<dialog id="modal" role="dialog" aria-modal="true" aria-labelledby="modal-title">
    <h2 id="modal-title">Confirmation</h2>
    <p>Are you sure?</p>
    <button>Yes</button>
    <button>Cancel</button>
</dialog>
```

### Contrast and color

```html
<!-- Do not rely ONLY on color to convey information -->

<!-- ❌ Bad: only green/red -->
<span style="color: green">✓</span> Success
<span style="color: red">✗</span> Error

<!-- ✅ Good: color + text + icon -->
<span class="text-success" role="img" aria-label="Success">✓</span> Saved successfully
<span class="text-danger" role="img" aria-label="Error">✗</span> Validation error
```

### Skip link — for jumping straight to the content

```html
<!-- The first element in <body> -->
<a href="#main-content" class="skip-link">Skip to content</a>

<nav>... long navigation ...</nav>

<main id="main-content" tabindex="-1">
    <!-- Main content -->
</main>
```

```css
/* Hidden but reachable with Tab */
.skip-link {
    position: absolute;
    top: -40px;
    left: 0;
    background: #007bff;
    color: white;
    padding: 8px;
    z-index: 999;
    transition: top 0.2s;
}
.skip-link:focus {
    top: 0;   /* appears when Tab is pressed */
}
```

### Accessibility checklist

```
✅ All <img> have alt=""
✅ <label> elements are linked to <input> via for/id
✅ Forms have <fieldset> and <legend> for groups
✅ Color contrast ≥ 4.5:1 (text) / 3:1 (large text)
✅ The site works fully with the keyboard only (Tab, Enter, Esc)
✅ Focus is visible (outline not removed without a replacement)
✅ Dynamic content is announced via aria-live
✅ Semantic tags instead of div/span wherever possible
```

---

---
> **🧠 Mental model:** `data-*` attributes are Post-it notes stuck onto HTML elements. They do not change how things are displayed and do not tell the browser to do anything special — they simply store arbitrary data that JavaScript or CSS can read. In Django templates, `data-*` is the ideal way to pass data from Python/Django to JavaScript without hidden `<input>`s or separate API requests.
>
> **📚 Why `data-*` appeared:** Before HTML5, developers stored data in `class` (for example `class="product-id-42"`), in hidden `<input type="hidden">` fields, or in comments. All of these approaches are hacks. `data-*` is a standardized way to store any metadata right in the markup, safely and semantically correctly.
>
> **🌐 An important nuance: camelCase in JavaScript:** The HTML attribute `data-note-id` becomes `dataset.noteId` in JavaScript (hyphen → camelCase). `data-in-stock` → `dataset.inStock`. `data-created-at` → `dataset.createdAt`. CSS reads it via `[data-note-id]` — the original name with the hyphen.
>
> **❌ Common beginner mistake:** Storing confidential data in `data-*` attributes. They are visible to any user via F12 → Elements! For passwords, tokens and sensitive data — server-side logic only, no `data-password` or `data-api-key`.
---

## 15. Data attributes — your own metadata in HTML

```html
<!-- data-* — store arbitrary data right in the HTML -->
<div
    class="product-card"
    data-id="42"
    data-category="electronics"
    data-price="1500"
    data-in-stock="true"
>
    <h3>Smartphone</h3>
    <button class="add-to-cart">Add to cart</button>
</div>

<!-- A list with data for JS -->
<ul>
    {% for note in notes %}
    <li
        data-note-id="{{ note.pk }}"
        data-created="{{ note.created_at|date:'c' }}"
    >
        {{ note.title }}
    </li>
    {% endfor %}
</ul>
```

```javascript
// Reading in JavaScript
const card = document.querySelector('.product-card');
const id = card.dataset.id;           // "42"
const price = card.dataset.price;     // "1500"
const inStock = card.dataset.inStock; // "true" (camelCase!)

// Changing
card.dataset.price = "1200";

// CSS by data attribute
// .product-card[data-in-stock="false"] { opacity: 0.5; }
```

```css
/* Styles by data attributes */
[data-in-stock="false"] {
    opacity: 0.5;
    pointer-events: none;
}
[data-category="electronics"]::before {
    content: "⚡ ";
}
```

---

**HTML debugging rule #1: NEVER debug HTML with Ctrl+U (View Source). ALWAYS use F12 → Elements.**

The reason is critical: Ctrl+U shows you what Django sent — the raw HTML string before the browser processed it. But: (1) the browser may automatically fix broken markup; (2) JavaScript may change the DOM after loading; (3) browser extensions may add/change elements. F12 → Elements always shows the CURRENT state of the DOM — exactly what the browser actually displays on the screen.

---
> **🧠 Mental model:** DevTools is the browser's X-ray. Ctrl+U is a photo of the building from the outside. F12 → Elements is the architectural plan with all the hidden pipes, wires and structures. You see not only what is there, but also why it looks the way it does (computed styles, box model).
>
> **📚 Why Ctrl+U and F12 show different things:** Django generates HTML and sends it over HTTP. This is a fixed string of bytes. The browser receives this string and: (1) parses it into the DOM; (2) fixes errors (closes tags automatically); (3) runs JavaScript, which may change the DOM; (4) browser extensions may add their own elements. As a result, the DOM can differ significantly from the source. If you debug with Ctrl+U, you are looking at the wrong thing.
>
> **🌐 Step-by-step debugging in DevTools:**
> ```
> Step 1: Open F12 (or right click → "Inspect")
>
> Step 2: The "Elements" tab — you see the live DOM
>         Expand the tree with the arrows.
>         Click the "↖" icon (Inspect mode) and click
>         an element on the page — DevTools will highlight
>         that element in the tree.
>
> Step 3: On the right — the "Styles" panel
>         You see all CSS rules that apply
>         to the element (from highest priority down).
>         Crossed-out rules are overridden by others.
>         You can click and edit values live.
>
> Step 4: The "Computed" tab (on the right)
>         The final computed value of EVERY CSS
>         property after the cascade. You see where
>         the rule came from (a click reveals the source).
>         Box model: margin → border → padding → content.
>
> Step 5: Editing HTML live
>         Right click on an element in the tree →
>         "Edit as HTML" → changes disappear on reload,
>         but it is perfect for quick testing.
>
> Step 6: Drag & Drop in the DOM
>         You can drag nodes right in the tree —
>         the browser re-renders immediately.
> ```
>
> **❌ Common beginner mistake:** Editing the HTML file, refreshing the browser, and looking at Ctrl+U again to debug. The right workflow: changes in the editor → refresh → F12 → Elements to check the DOM and Styles to check the CSS.
---

## 16. DevTools — debugging HTML and the DOM

### Opening DevTools

| Action | Windows/Linux | Mac |
|-----|--------------|-----|
| Open DevTools | F12 or Ctrl+Shift+I | Cmd+Option+I |
| Inspect element | Ctrl+Shift+C | Cmd+Shift+C |
| View HTML source | Ctrl+U | Cmd+U |
| Console | Ctrl+Shift+J | Cmd+Option+J |

### Elements Tab — the live DOM

```
Elements | Console | Sources | Network | ...

▼ <html lang="uk">
  ▼ <head>
      <meta charset="UTF-8">
      <title>My site</title>
  ▼ <body>
    ▼ <main id="main-content">    ← click to expand
      ▼ <div class="card">
          <h2>Heading</h2>        ← right click → Edit as HTML
          <p>Text</p>
```

**What you can do in Elements:**
- Click an element → all its CSS rules are shown on the right (Styles)
- Double-click an attribute → edit it on the fly
- Right click → "Edit as HTML" → change the HTML in real time (not saved)
- Drag & drop DOM nodes → rearrange elements
- The "Computed" tab → the final box model after all CSS rules

### Console — quick access to the DOM

```javascript
// Find an element
document.querySelector('.card')            // the first .card
document.querySelectorAll('.card')         // all .card elements (NodeList)
document.getElementById('main-content')    // by ID

// Change the text
document.querySelector('h1').textContent = 'New heading';

// Change the style
document.querySelector('.card').style.background = 'red';

// Inspect data attributes
document.querySelector('[data-note-id]').dataset
```

### Source code vs DOM — the key difference

```
                 ┌─────────────────────────────────┐
                 │  Django generates HTML (server) │
                 └──────────────┬──────────────────┘
                                │ HTTP Response
                                ▼
                 ┌─────────────────────────────────┐
                 │  Ctrl+U — raw HTML from server  │
                 │  (static, unchanged)            │
                 └──────────────┬──────────────────┘
                                │ Browser Parser
                                ▼
                 ┌─────────────────────────────────┐
                 │  F12 → Elements — live DOM      │
                 │  (may differ from the source)   │
                 │  (auto-fixes + JS changes)      │
                 └─────────────────────────────────┘
```

> **If the layout does not look right:** always check the DOM (F12), not the source (Ctrl+U).
> The browser may have fixed your HTML — and you will be looking for the bug in the wrong place.

---

This full example is not just "code that works". It demonstrates EVERY concept from this file in the real context of a Django template. Read it as an ensemble, not as separate elements. Pay attention to every semantic decision — each one is here for a reason, not by accident.

**What to analyze in this example (and why):**

- `<!DOCTYPE html>` + `lang="uk"` — the correct start, turns on standards mode and sets the language
- `{% load static %}` and `{% static '...' %}` — the Django way to include CSS/JS (not hardcoded paths)
- `<a href="#main-content" class="skip-link">` — the first element of `<body>`, accessibility for the keyboard
- `<header role="banner">` — `role="banner"` as a fallback ARIA for older screen readers
- `<nav aria-label="Головна навігація">` — aria-label distinguishes several `<nav>` elements on the page
- `aria-current="page"` — the screen reader says "current page", not just "link"
- `<main id="main-content" tabindex="-1">` — `tabindex="-1"` lets the skip link move the focus here
- `aria-live="polite"` on flash messages — announced by the screen reader automatically without a reload
- `<article>` inside `<li>` — each note is independent and could exist outside the list
- `<time datetime="Y-m-d">` — a machine-readable date format for SEO and screen readers
- `data-note-id="{{ note.pk }}"` — passing Django data to JavaScript without hidden inputs
- `aria-label="Читати нотатку: {{ note.title }}"` — makes the "Читати →" ("Read →") buttons unique for each note
- `<footer role="contentinfo">` — page footer semantics

---
> **🧠 Mental model:** This example is like an orchestra score. Every instrument (tag, attribute) plays its part. Removing any element means losing part of the sound: without `aria-label` on the buttons, the screen reader reads "Читати →, Читати →, Читати →" ("Read →, Read →, Read →") without understanding where they lead; without `<time datetime>`, Google does not understand when the article was published; without `data-note-id`, JavaScript does not know the note ID without an extra request.
>
> **📚 Why this example matters for a Django developer:** A Django developer writes server-side logic, but it is the HTML template that is the contract between the server and the browser. A bad template = bad SEO = fewer users. An inaccessible template = excluded users. A correct template is part of product quality, no less important than a correct Django view.
>
> **🌐 How the browser processes this template (steps):**
> 1. Django renders the template: replaces `{{ note.title }}`, `{% for %}`, `{% url %}` — and gets clean HTML
> 2. The browser receives the HTML and starts parsing it from top to bottom
> 3. It finds `<link rel="stylesheet">` in `<head>` — and downloads the CSS in parallel
> 4. It builds the DOM gradually — `<header>`, then `<main>`, then the `<ul>` with notes
> 5. After the CSS has fully loaded, it builds the Render Tree and displays the page
> 6. The `<script>` at the end of `<body>` runs last, when the DOM is already ready
>
> **❌ Common beginner mistake:** Placing `<script>` in `<head>` without `defer`. JavaScript in `<head>` blocks DOM parsing — the browser stops and waits for the script to download and execute. The user sees a blank page. The solution: `<script>` at the end of `<body>` (as here) or `<script defer src="...">` in `<head>`.
---

## 17. A full example — a notes page with semantics

```html
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Мої нотатки | Hello Django</title>
    <meta name="description" content="Список персональних нотаток">
    {% load static %}
    <link rel="stylesheet" href="{% static 'css/style.css' %}">
</head>
<body>

    {# Skip navigation for screen readers #}
    <a href="#main-content" class="skip-link">Перейти до вмісту</a>

    <header class="site-header" role="banner">
        <nav aria-label="Головна навігація">
            <a href="{% url 'notes_app:index' %}">Головна</a>
            <a href="{% url 'notes_app:note_list' %}" aria-current="page">Нотатки</a>
        </nav>
    </header>

    <main id="main-content" tabindex="-1">

        {# Flash messages from Django #}
        {% if messages %}
        <section aria-live="polite" aria-label="Системні повідомлення">
            {% for message in messages %}
            <div class="alert alert-{{ message.tags }}" role="alert">
                {{ message }}
            </div>
            {% endfor %}
        </section>
        {% endif %}

        <section aria-labelledby="notes-heading">
            <h1 id="notes-heading">Мої нотатки</h1>

            {% if notes %}
            <p>Знайдено нотаток: <strong>{{ notes|length }}</strong></p>

            <ul class="notes-list" role="list">
                {% for note in notes %}
                <li
                    class="note-card"
                    data-note-id="{{ note.pk }}"
                    data-created="{{ note.created_at|date:'c' }}"
                >
                    <article>
                        <header>
                            <h2 class="note-title">
                                <a href="{% url 'notes_app:note_detail' pk=note.pk %}">
                                    {{ note.title }}
                                </a>
                            </h2>
                            <time
                                class="note-date"
                                datetime="{{ note.created_at|date:'Y-m-d' }}"
                            >
                                {{ note.created_at|date:"d.m.Y H:i" }}
                            </time>
                        </header>

                        {% if note.content %}
                        <p class="note-content">
                            {{ note.content|truncatewords:30 }}
                        </p>
                        {% endif %}

                        <footer class="note-actions">
                            <a
                                href="{% url 'notes_app:note_detail' pk=note.pk %}"
                                aria-label="Читати нотатку: {{ note.title }}"
                            >
                                Читати →
                            </a>
                        </footer>
                    </article>
                </li>
                {% endfor %}
            </ul>

            {% else %}
            <p>
                Нотаток ще немає.
                <a href="{% url 'notes_app:note_create' %}">Створити першу →</a>
            </p>
            {% endif %}

        </section>
    </main>

    <footer class="site-footer" role="contentinfo">
        <p>
            <small>© 2026 Hello Django. Всі права захищено.</small>
        </p>
    </footer>

    <script src="{% static 'js/main.js' %}"></script>
</body>
</html>
```

**What is done right here:**

| Element | Why exactly this way |
|---------|---------------|
| `<main id="main-content" tabindex="-1">` | The skip link focuses main when activated |
| `<nav aria-label="Головна навігація">` | Several `<nav>` elements on the page — we tell them apart |
| `aria-current="page"` | The screen reader announces "current page" |
| `aria-live="polite"` | Flash messages are announced automatically |
| `<article>` inside `<li>` | Each note is an independent piece of content |
| `<time datetime="...">` | A machine-readable date format (SEO + accessibility) |
| `aria-label="Читати нотатку: ..."` | The "Читати →" ("Read →") buttons are identical without a label |
| `data-note-id="{{ note.pk }}"` | Data for JS without hidden inputs |

---

## 18. Self-check questions

1. What is the difference between `<strong>` and `<b>`? When should you use each?
2. Why should there be only one `<h1>` per page?
3. What happens if you write `<div class="card">` instead of `<article>`? Is it a mistake?
4. Why use `alt=""` (an empty alt) for decorative images?
5. The browser received `<p>Текст<p>Ще текст` (without closing tags). What will be in the DOM?
6. What is the difference between `Ctrl+U` (source) and `F12 → Elements` (DOM)? When do they differ?
7. Why is `{% csrf_token %}` needed in a POST form? What happens without it?
8. `<img src="logo.png">` without `alt` — what is the problem? Which is better: `alt="logo"` or `alt=""`?
9. How do you make a click on a `<label>` activate an `<input>`?
10. Why is `<table>` not used for page layout — only for tables?

---

## Cheat sheet — HTML in Django Templates

```html
{# base.html — the skeleton of all pages #}
<!DOCTYPE html>
<html lang="uk">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Мій сайт{% endblock %}</title>
    {% load static %}
    <link rel="stylesheet" href="{% static 'css/style.css' %}">
</head>
<body>
    <nav>
        <a href="{% url 'notes_app:index' %}">Головна</a>
        <a href="{% url 'notes_app:note_list' %}">Нотатки</a>
    </nav>

    <main>
        {% if messages %}
            {% for message in messages %}
                <div class="alert alert-{{ message.tags }}">{{ message }}</div>
            {% endfor %}
        {% endif %}

        {% block content %}{% endblock %}
    </main>

    <footer>© 2026</footer>

    <script src="{% static 'js/main.js' %}"></script>
    {% block extra_js %}{% endblock %}
</body>
</html>
```
