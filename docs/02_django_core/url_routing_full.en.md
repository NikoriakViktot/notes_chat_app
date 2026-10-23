# Django URL Routing
When an HTTP request reaches your backend, Django does not just call some random function. It uses the **URL Dispatcher** — a strict system of rules for determining exactly which Python code should respond to this particular request.

Here is an architectural breakdown of how this system works.

---

## 1. The core mechanism and execution flow

Routing follows a clear algorithm:

1. **Initialization:** ROOT_URLCONF.
Django reads the `ROOT_URLCONF` setting to find the main routes file (usually the project-level `urls.py`).


2. **Loading patterns:** urlpatterns.
It looks for the `urlpatterns` variable — a plain list (sequence) of `path()` or `re_path()` objects.


3. **Top-down search:** Top-down matching.
Django reads this list strictly from top to bottom and compares the requested URL with each pattern. It stops at the very first match.


4. **Calling the view:** HttpRequest.
As soon as a match is found, Django imports the corresponding view function, passes it the `HttpRequest` object and any variables "captured" from the URL.


5. **404 error:** Resolver404.
If no route matches, a `Resolver404` exception is raised and the error handler is called (404 Page Not Found).


> **Mental model:**
> Imagine a mail carrier walking down a long street (your `urlpatterns` list) and comparing the address on the envelope with the house numbers. As soon as they see a house whose number matches the address on the letter, they drop the letter there (calling the view) and **stop searching**. They do not walk to the end of the street to check whether there is a "better" house.

---

## 2. Modular backend architecture and `include()`

To scale the backend, Django uses the `include()` function. It lets you split one giant list of routes into isolated modules for each app.

When Django encounters `include()`, it **cuts off the part of the URL that has already matched** and passes the rest of the string to the nested `urls.py` file for further searching.

**Architectural significance:** This makes apps "plug-and-play" (independent modules). The `polls` app has no idea whether it lives at `/polls/` or `/api/v1/polls/`. It only handles its own segment of the path.

### Example of the main `urls.py` (project level)

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    # All requests starting with /users/ are passed to the users_app app
    path('users/', include('users_app.urls')), 
    # API versioning
    path('api/v1/', include('api_v1.urls')),
]

```

---

## 3. Two kinds of dynamic parameters

Django lets you pass data to a view in two different ways: through the structure of the path itself (Path Converters) and through request parameters (Query Strings).

### Type A: extracting parameters from the path (Path Converters)

Dynamic URLs use path converters to automatically turn parts of the URL text into Python variables. When the dispatcher finds a match (for example `<int:id>`), it "captures" that value, converts it to the specified type and passes it to the function.

* `<int:id>`: captures an integer and passes it to the view as `id=5`.
* `<slug:post_slug>`: captures text (letters, digits, hyphens).
* `<str:username>`: captures any string up to the next slash `/`.

**`urls.py` (app level):**

```python
from django.urls import path
from . import views

urlpatterns = [
    # Matches /users/42/
    path('<int:id>/', views.user_profile, name='profile'),
    
    # Matches /users/johndoe-99/
    path('<slug:username_slug>/', views.user_by_slug, name='profile_slug'),
]

```

**`views.py`:**

```python
from django.shortcuts import render, get_object_or_404
from .models import User

def user_profile(request, id):
    # Behind the scenes Django executed: user_profile(request, id=42)
    user = get_object_or_404(User, pk=id)
    return render(request, 'profile.html', {'user': user})

```

### Type B: GET parameters (Query Strings)

Unlike converters, the URL dispatcher **completely ignores** everything in the address after the question mark `?`. The router treats `/users/` and `/users/?id=42&sort=asc` as one and the same route.

This data is automatically collected into the `request.GET` dictionary. It is convenient for filtering, sorting or pagination. This is a safe approach: if the parameters are missing, you simply use a default value via the `.get()` method.

**`views.py`:**

```python
def users_list(request):
    # Look for the 'id' parameter (e.g. ?id=42). Returns None if it is missing.
    user_id = request.GET.get('id')

    # Look for 'sort'. If it is missing, default to 'asc'
    sort_by = request.GET.get('sort', 'asc')
    
    # Processing logic...
    return render(request, 'users_list.html', {'sort_by': sort_by})

```

---

## 4. Common misconceptions and edge cases

* **The "best match" trap:** Students often think Django looks for the most precise match. It does not — it takes the *first* one. If you put the `<str:name>/` route above `about/`, a request to `/about/` will be intercepted by the first route, and the view will receive the string `"about"` in the `name` variable. Always put static routes above dynamic ones.
* **Debugging intuition:** When you see a `404` error in development mode (`DEBUG = True`), Django shows you the exact list of regular expressions and routes it checked, **in exactly the order in which it checked them**. This is your main tool for understanding where the system "took a wrong turn".

---

Here is a learning section that explains the architectural difference between handling `GET` and `POST` requests and shows how to safely pass data from the user to the database.

---

# Handling user data: GET filtering and POST forms

In web application architecture, the `GET` and `POST` methods play fundamentally different roles. `GET` is used exclusively for **reading and filtering** data (it does not change server state). `POST` is used for **writing or modifying** data (it changes server state).

## Part 1: Filtering the database via GET parameters

When a user applies filters on a site (for example, picks a category or a sort order), the URL looks like this: `/books/?category=fiction&sort=-price`. Django collects these parameters into the `request.GET` dictionary.

Your task is to extract these parameters and safely pass them into ORM methods (`.filter()`, `.order_by()`).

### Architectural pattern: query chaining

A Django QuerySet is "lazy". This means you can apply filters one after another, and Django will not hit the database until you pass the final result to the template.

### Code example: dynamic filtering and sorting

```python
from django.shortcuts import render
from .models import Book

def book_list(request):
    # 1. Start with a base query (the DB is not called yet)
    queryset = Book.objects.all()

    # 2. Extract the GET parameters
    # Returns None if the parameter is missing
    category_query = request.GET.get('category') 
    # If the parameter is missing, sort by title by default
    sort_query = request.GET.get('sort', 'title') 

    # 3. Apply filtering if the parameter exists
    if category_query:
        # Translates to SQL: WHERE category = 'fiction'
        queryset = queryset.filter(category=category_query)

    # 4. Safe sorting
    # IMPORTANT: Always check the allowed sort fields!
    # If the user enters ?sort=invalid_column, the DB will raise a 500 error.
    allowed_sort_fields = ['title', '-title', 'price', '-price']
    if sort_query in allowed_sort_fields:
        # Translates to SQL: ORDER BY price DESC
        queryset = queryset.order_by(sort_query)

    # 5. Pass the finished QuerySet to the template (this is where the SQL query happens)
    return render(request, 'books/list.html', {'books': queryset})

```

> **Mental model:** A `GET` request is like talking to a librarian. You ask: "Show me the fiction books, sorted by price" (`?category=fiction&sort=price`). The librarian (the view) applies these filters to the catalog (the QuerySet) and hands you a list. The state of the library does not change.

---

## Part 2: Handling POST requests from HTML forms

When a user fills in a form (for example, registration or adding a product), the data is sent with the `POST` method. This data ends up in the `request.POST` dictionary.

### Form handling lifecycle (the PRG pattern)

Correct handling of a `POST` request requires following the **PRG** (Post/Redirect/Get) pattern. You should never return an HTML template directly after a successful `POST` request, because refreshing the page in the browser (F5) will resubmit the form (a double charge or a duplicate record).

1. **GET request (displaying the form):**
The user navigates to the page. The server sees that the method is `GET` and returns an empty HTML form.


2. **Submitting the data:**
The user fills in the fields and clicks "Submit". The browser builds a `POST` request.


3. **POST request (processing the logic):**
The server receives `request.POST`, extracts the data, checks it for errors and saves it to the database.


4. **Redirect:**
Instead of rendering a template, the server returns a `302 Redirect` status. This forces the browser to make a new, clean `GET` request to another page (for example, a success page).


### Code example: handling "raw" POST data

The HTML form (note the mandatory `{% csrf_token %}`, which protects against cross-site request forgery):

```html
<!-- create_book.html -->
<form method="POST" action="{% url 'create_book' %}">
    {% csrf_token %}
    <input type="text" name="title" placeholder="Book title">
    <input type="number" name="price" placeholder="Price">
    <button type="submit">Save</button>
</form>

```

The handler in `views.py`:

```python
from django.shortcuts import render, redirect
from .models import Book

def create_book(request):
    # If the request came with the POST method (the form was submitted)
    if request.method == 'POST':
        # 1. Extract the data by the 'name' attribute from the HTML form
        book_title = request.POST.get('title')
        book_price = request.POST.get('price')
        
        # 2. Raw validation (are the fields non-empty?)
        if book_title and book_price:
            # 3. Save to the database
            Book.objects.create(title=book_title, price=book_price)
            
            # 4. Mandatory redirect (protection against double submission)
            return redirect('book_list') 
        else:
            # If there are errors, you can return the form with a message
            error_message = "Please fill in all fields."
            return render(request, 'create_book.html', {'error': error_message})

    # If the method is GET, just show an empty form
    return render(request, 'create_book.html')

```

### Why is "raw" request.POST rarely used?

Extracting data via `request.POST.get()` and writing checks by hand (is the price a number, is the title too long, is the email unique) takes a very long time and leads to bugs.

In real-world engineering, the **Django Forms** or **ModelForms** system is used for this. They automatically generate HTML, check data types on their own and guarantee safety.


Handling "raw" data via `request.POST.get()` quickly becomes unmanageable when a form has 10 fields, checkboxes, dates and files. You have to check manually whether a string is a number, whether it exceeds the character limit, and what to do if the user entered malicious code.

**Django Forms** (specifically `ModelForm`) is a mechanism that takes your database model and automatically builds a validation and HTML generation system for it.

## 1. Mental model: "The smart secretary"

Imagine that a `ModelForm` is a smart secretary at the front desk.
When a client comes for the first time (a GET request), the secretary hands them a blank form. When the client returns the completed form (a POST request), the secretary picks up a pen, checks every line against the rules (is this really a date? is the password too short?), and only if everything is perfect passes the document on to the director (the database). If there are errors, the secretary returns the form to the client, underlining in red marker exactly what needs to be fixed.

---

## 2. Step by step: dropping manual processing

### Step 1: Creating the `forms.py` file

Instead of describing the rules in `views.py`, you create a separate file where you link the form to your model.

```python
# forms.py
from django import forms
from .models import Book

class BookForm(forms.ModelForm):
    class Meta:
        model = Book
        fields = ['title', 'price', 'category'] # Specify which fields may be edited

```

*Architectural benefit:* The form will automatically read your `Book` model. It will know that `title` is text (with a length limit) and `price` is a number, and will generate the corresponding checks and HTML tags (`<input type="text">`, `<input type="number">`).

### Step 2: Optimizing `views.py`

Now we remove all the manual code that parses the `request.POST` dictionary.

```python
# views.py
from django.shortcuts import render, redirect
from .forms import BookForm

def create_book(request):
    if request.method == 'POST':
        # Pass all the user's data into the form (Bound Form)
        form = BookForm(request.POST)
        
        # The magic happens here: automatic checking of all the rules
        if form.is_valid():
            # If the data is clean and correct, save it to the database
            form.save()
            return redirect('book_list')
    else:
        # GET request: create an empty form (Unbound Form)
        form = BookForm()

    # If the form is invalid (has errors), or this is a GET request,
    # we simply pass the form object to the template.
    return render(request, 'create_book.html', {'form': form})

```

### Step 3: Simplifying the HTML template

Previously you had to write every `<input>` by hand. Now Django renders the form itself.

```html
<!-- create_book.html -->
<form method="POST">
    {% csrf_token %}
    
    <!-- Outputs all fields, labels and error messages -->
    {{ form.as_p }}
    
    <button type="submit">Save book</button>
</form>

```

*If the user types text into the price field, `form.is_valid()` will return `False`, and Django will automatically render the page again, adding a red "Enter a number" message next to the price field. You do not need to write a single line of logic for this.*

---

## 3. What happens under the hood of `.is_valid()`?

Calling `form.is_valid()` starts a deep data-cleaning pipeline:

1. **To Python (type conversion):** All data from the web arrives as text (strings). Django tries to turn the string `"15.99"` into a Python `Decimal` object and `"2026-05-19"` into a `datetime` object.
2. **Checking model constraints:** `max_length`, `unique=True` and whether a field with `null=False` is empty are checked.
3. **Creating `cleaned_data`:** If all checks pass, Django creates the protected `form.cleaned_data` dictionary. After calling `is_valid()` you should **never** work with the "raw" `request.POST` — use only `cleaned_data`.
4. **Calling `save()`:** The `.save()` method takes the safe `cleaned_data` dictionary and generates an `INSERT` query to the database.


---

## 4. Maximum optimization: Class-Based Views (CreateView)

We have already seen how `ModelForm` takes over validation and HTML generation. But `views.py` still contains boilerplate code: checking `if request.method == 'POST'`, calling `form.is_valid()`, saving and redirecting.

Django has a built-in tool, **`CreateView`**, which encapsulates this whole lifecycle (GET, POST, validation, saving and redirecting) in a few lines of code.

### Code example: switching to classes

Instead of the `create_book` function, we create a class:

```python
# views.py
from django.urls import reverse_lazy
from django.views.generic.edit import CreateView
from .models import Book
from .forms import BookForm

class BookCreateView(CreateView):
    model = Book
    form_class = BookForm
    template_name = 'create_book.html'
    
    # Where to redirect the user after the form is saved successfully
    success_url = reverse_lazy('book_list')

```

### How does it work under the hood?

The `CreateView` class contains all the standard logic you used to write by hand. When a request arrives, this class runs the following algorithm:

1. **If it is a GET request:** The class automatically creates an empty `BookForm` instance and passes it to the `create_book.html` template as the `form` variable.
2. **If it is a POST request:** The class automatically binds the data from `request.POST` to the `BookForm` form.
3. **Validation:** `.is_valid()` is called.
* If there are errors, the class automatically returns the HTML page with the errors highlighted (you do not need to write an `else` block).
* If the data is clean, the class calls `form.save()`, writes the data to the database and performs an HTTP 302 Redirect to the address given in `success_url`.



### Wiring it up in `urls.py`

For the URL dispatcher to understand this class, you need to call it via the `.as_view()` method:

```python
# urls.py
from django.urls import path
from .views import BookCreateView, book_list

urlpatterns = [
    path('books/', book_list, name='book_list'),
    path('books/new/', BookCreateView.as_view(), name='create_book'),
]

```

> **Architectural summary:** Using CBVs (`CreateView`, `UpdateView`, `DeleteView`) turns standard CRUD operations into configuration instead of imperative code. This minimizes the number of bugs and makes the backend architecture much cleaner.

---

## 5. Prediction exercise

Analyze the following URL dispatcher code:

```python
# urls.py
urlpatterns = [
    path('api/users/', views.all_users),               # 1
    path('api/<str:username>/', views.user_profile),   # 2
    path('api/users/active/', views.active_users),     # 3
]

```

**Question to think about:** What happens if the user sends a request to `/api/users/active/`? Which view runs, and why?

> **Answer:** **Route #3** (`active_users`) runs. Route #1 (`api/users/`) does not match, because the path is longer. Route #2 does not match either: the `<str:username>` converter captures any characters **except** `/`, so the string `users/active` (which contains a slash) cannot become the value of `username`. So Django gets to route #3.
>
> The top-down ordering trap here is a different one: route #2 captures any **single-segment** path. For example, `/api/users/` matches both #1 and #2, but #1 runs because it comes first. If a static route such as `path('api/active/', ...)` were placed **after** #2, it would never be reached: `active` would be treated as a `username`. That is why static routes go above routes with parameters.

---

## notes_chat_app — real URL patterns

### Main router (`notes_project/urls.py`)

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('accounts/', include('django.contrib.auth.urls')),  # login, logout, password
    path('', include('notes_app.urls', namespace='notes_app')),
]
```

### App router (`notes_app/urls.py`)

```python
app_name = 'notes_app'   # ← namespace for reverse()

urlpatterns = [
    path('', views.index, name='index'),

    # Notes CRUD
    path('notes/', views.note_list, name='note_list'),
    path('notes/new/', views.note_create, name='note_create'),    # ← BEFORE <int:pk>!
    path('notes/<int:pk>/', views.note_detail, name='note_detail'),
    path('notes/<int:pk>/edit/', views.note_edit, name='note_edit'),
    path('notes/<int:pk>/delete/', views.note_delete, name='note_delete'),

    # Notebooks, Tags
    path('notebooks/', views.notebook_list, name='notebook_list'),
    path('tags/new/', views.tag_create, name='tag_create'),

    # Group chat
    path('groups/<int:pk>/chat/', views.group_chat, name='group_chat'),

    # Todos, Shopping
    path('todo/', views.todo_list_list, name='todo_list'),
    path('shopping/', views.shopping_list_list, name='shopping_list'),
]
```

### Named URLs — `reverse()` and `{% url %}`

```python
# In views.py — redirect by URL name
return redirect('notes_app:note_detail', pk=note.pk)

# reverse() — get the URL string
from django.urls import reverse
url = reverse('notes_app:note_detail', kwargs={'pk': 42})
# url == '/notes/42/'
```

```html
<!-- In a template -->
<a href="{% url 'notes_app:note_detail' pk=note.pk %}">{{ note.title }}</a>
<a href="{% url 'notes_app:note_create' %}">Нова нотатка</a>
```

### Debug — `resolve()` and `show_urls`

```python
from django.urls import resolve

result = resolve('/notes/42/')
result.url_name   # 'note_detail'
result.namespace  # 'notes_app'
result.kwargs     # {'pk': 42}
result.func       # <function note_detail at 0x...>
```

---

## In the book

- [Request Lifecycle](request_lifecycle.md) — the full path of a request through Django
- [Views](views_full.md) — FBV, CBV, decorators, anti-patterns
- [Step 1. Hello Django](../tutorials/01_hello_django/urls_and_views.md) — URL routing in practice

---

## Official documentation

- [Django: URL dispatcher](https://docs.djangoproject.com/en/5.2/topics/http/urls/) — path(), re_path(), include()
- [Django: Reverse resolution of URLs](https://docs.djangoproject.com/en/5.2/topics/http/urls/#reverse-resolution-of-urls) — reverse(), {% url %}
- [Django: URL converters](https://docs.djangoproject.com/en/5.2/topics/http/urls/#path-converters) — int, str, slug, uuid, path
