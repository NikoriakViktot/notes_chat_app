# Zero Trust Architecture

> **"Never trust, always verify"** — no user, device or network
> should be considered safe just because it is "inside" the system.
>
> **Analogy:** Even if an employee passes through the office turnstile every day,
> every time they open the door to the server room
> the system checks their card again. That's Zero Trust.

---

## What is Zero Trust?

**Zero Trust Architecture** is a security philosophy and design pattern that rejects the notion of "implicit trust" based on:
- A user or device being inside the internal network
- A previous successful authentication

The principle: **"never trust, always verify"** — explicit confirmation of identity and permissions for **every request** to the system.

> **Important:** Zero Trust Architecture isn't a product you can "buy and install".
> It's an approach to system design where every component distrusts the others by default.

### 6 key principles of Zero Trust

**1. Continuous Verification**

Simply having a token or having logged in doesn't mean the user can be trusted permanently. Every privileged action must go through a check. Blind trust in a token is a serious vulnerability.

**2. Least Privilege**

Every user, device or script gets access only to what they absolutely need. If a manager needs access to the cafeteria menu, they shouldn't see the company's customer database.

**3. Strict identity management (IAM)**

The system must clearly know EVERYONE: people, devices, programs. Tactics:
- **MFA (Multi-Factor Authentication):** password + smartphone + biometrics
- **SSO (Single Sign-On):** one trusted authentication provider

**4. Micro-segmentation**

Instead of general access to the whole environment — strict rules for each department, user and device. If an attacker gains access to one resource, they can't automatically reach the others.

**5. Continuous Monitoring**

Log and inspect all network traffic. Watch all entities to see whether they exceed their authority.

**6. Framework-level protection**

Correct use of built-in security mechanisms (CSRF protection in Django, parameterized ORM queries) is part of the Zero Trust approach.

---

## 1. Continuous authorization (Continuous Verification)

Zero Trust requires checking **every call to a privileged function**, not just a one-time login.

> Having a valid token doesn't mean unconditional trust — the user's status may have changed.

**Django implementation:**
```python
# NOT enough — checking only at login:
@login_required
def edit_note(request, pk):
    note = get_object_or_404(Note, pk=pk)  # IDOR vulnerability!

# Zero Trust — checking on every request:
@login_required
@permission_required('notes_app.change_note')
def edit_note(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)  # ← explicit check
```

---

## 2. Object-Level Permissions

Global permissions aren't enough for Zero Trust. You need to check ownership of the specific object.

**The IDOR problem:**
```python
# Alice knows the URL: /notes/42/edit/
# Note 42 belongs to Bob. Without a check:
note = get_object_or_404(Note, pk=42)   # Alice gets access!

# Zero Trust — checking the owner:
note = get_object_or_404(Note, pk=42, user=request.user)  # 404 for Alice
```

**For group access:**
```python
from django.core.exceptions import PermissionDenied
from django.db.models import Q

def check_note_access(note, user):
    user_groups = user.groups.all()
    has_access = (
        note.user == user or                          # owner
        (note.group and note.group in user_groups)    # group member
    )
    if not has_access:
        raise PermissionDenied
```

**Recommendation:** Use a UUID instead of an auto-incrementing integer PK for important objects — the next ID can't be guessed.

---

## 3. Strict data validation (Zero Trust Input)

No client-side input can be trusted implicitly.

```python
# NOT enough — frontend validation only:
# <input type="number" min="1" max="100">  ← an attacker bypasses it

# Zero Trust — server-side validation in the model:
class Note(models.Model):
    priority = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(4)]
    )
    
    def clean(self):
        if self.priority not in [1, 2, 3, 4]:
            raise ValidationError("Invalid priority")

# or in the form:
class NoteForm(forms.ModelForm):
    def clean_title(self):
        title = self.cleaned_data['title'].strip()
        if len(title) < 3:
            raise forms.ValidationError("The title is too short.")
        return title
```

---

## 4. Multi-Factor Authentication (MFA)

Zero Trust relies heavily on MFA — ordinary passwords are easily compromised.

```python
# Installation:
pip install django-two-factor-auth

# settings.py:
INSTALLED_APPS += ['two_factor']
LOGIN_URL = 'two_factor:login'
TWO_FACTOR_PATCH_ADMIN = True

# urls.py:
from two_factor.urls import urlpatterns as tf_urls
urlpatterns = [path('', include(tf_urls)), ...]
```

**Factors:**
- **Knowledge** — a password
- **Possession** — an OTP code (Google Authenticator, SMS)
- **Inherence** — biometrics (FaceID, fingerprint)

---

## 5. Micro-segmentation and Monitoring

Zero Trust uses continuous monitoring to detect anomalies.

```python
# settings.py — extended security logging:
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'security_file': {
            'class': 'logging.FileHandler',
            'filename': 'logs/security.log',
        },
        'console': {'class': 'logging.StreamHandler'},
    },
    'loggers': {
        'django.security': {
            'handlers': ['security_file', 'console'],
            'level': 'WARNING',
            'propagate': False,
        },
    },
}

# views.py — logging privileged actions:
import logging
security_log = logging.getLogger('django.security')

@login_required
def note_delete(request, pk):
    note = get_object_or_404(Note, pk=pk, user=request.user)
    if request.method == 'POST':
        security_log.warning(
            f"User {request.user.pk} deleted note {pk}",
            extra={'request': request}
        )
        note.delete()
```

---

## 6. Continuous Verification (In detail)

**Continuous Verification** is a key component of Zero Trust. The mere fact of a previous authentication isn't enough. The system must **check every call to a privileged function**.

### 6.1 Centralized access checks

To avoid adding checks by hand in every function, centralize the logic:

```python
# DRF: a custom permission class
from rest_framework.permissions import BasePermission

class IsOwner(BasePermission):
    def has_object_permission(self, request, view, obj):
        return obj.user == request.user

# Globally in settings.py:
REST_FRAMEWORK = {
    'DEFAULT_PERMISSION_CLASSES': ['notes_app.permissions.IsOwner'],
}

# For regular views — use mixins:
from django.contrib.auth.mixins import LoginRequiredMixin, PermissionRequiredMixin

class NoteUpdateView(LoginRequiredMixin, PermissionRequiredMixin, UpdateView):
    permission_required = 'notes_app.change_note'
    # Authorization runs BEFORE the business logic
```

### 6.2 Middleware as a global shield

A custom Middleware that blocks all unprotected endpoints:

```python
# notes_app/middleware.py
class RequireAuthMiddleware:
    PUBLIC_URLS = ['/accounts/login/', '/accounts/register/', '/']
    
    def __init__(self, get_response):
        self.get_response = get_response
    
    def __call__(self, request):
        if request.path not in self.PUBLIC_URLS:
            if not request.user.is_authenticated:
                from django.shortcuts import redirect
                return redirect('login')
        return self.get_response(request)
```

### 6.3 Validating JWT token state (for APIs)

The JWT problem: a token stays valid until it expires, even if the user has been blocked.

```python
# Solution: a blacklist of revoked refresh tokens in the DB (token_blacklist tables, requires migrate)
# pip install djangorestframework-simplejwt[crypto]

# settings.py:
INSTALLED_APPS += ['rest_framework_simplejwt.token_blacklist']

# On logout — add the token to the blacklist:
from rest_framework_simplejwt.tokens import RefreshToken

def logout_api(request):
    refresh_token = request.data.get('refresh')
    token = RefreshToken(refresh_token)
    token.blacklist()   # DB: a row in the BlacklistedToken table
```

### 6.4 Object-level checks (IDOR Prevention)

```python
# BAD — we only check "whether there's a role":
@login_required
def edit_note(request, pk):
    note = get_object_or_404(Note, pk=pk)   # IDOR! Alice edits Bob's note

# GOOD — we check the permission for the specific object:
@login_required
def edit_note(request, pk):
    note = get_object_or_404(Note, pk=pk)
    if note.user != request.user:
        raise PermissionDenied   # Continuous verification!
    # ...
```

### 6.5 Protection against Mass Assignment

```python
# Attack: POST {'is_admin': True} → a role change

# NOT safe:
class UserForm(forms.ModelForm):
    class Meta:
        model = User
        fields = '__all__'  # ← an attacker can send is_superuser=True!

# SAFE — an explicit whitelist of fields:
class UserProfileForm(forms.ModelForm):
    class Meta:
        model = UserProfile
        fields = ['display_name', 'bio', 'timezone']  # ← only the allowed ones
```

---

## Zero Trust in our project

| ZT principle | Implementation in crispy_notes_chat_app |
|-----------|-----------------------------------|
| Continuous Verification | `@login_required` on every view |
| Object-Level Permissions | `get_object_or_404(Note, pk=pk, user=request.user)` |
| Input Validation | `NoteForm.clean_*()`, `MinValueValidator` in models |
| Least Privilege | `user.groups.all()` filtering for Group sharing |
| Audit Logging | (for extension) `django.security` logger |
| MFA | (for extension) `django-two-factor-auth` |
