from django.contrib import admin
from django.contrib.auth import views as auth_views
from django.urls import path, include
from debug_toolbar.toolbar import debug_toolbar_urls
from rest_framework.routers import DefaultRouter

from notes_app.api import NoteViewSet

# REST API: /api/notes/, /api/notes/<id>/, /api/notes/<id>/pin/ (див. notes_app/api.py)
router = DefaultRouter()
router.register("notes", NoteViewSet, basename="api-note")

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include(router.urls)),
    # Django built-in auth: login, logout, password change
    path("accounts/", include("django.contrib.auth.urls")),
    path("", include("notes_app.urls", namespace="notes_app")),
] + debug_toolbar_urls()
