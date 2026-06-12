"""Temporary debug middleware — catch and print all 500 exceptions."""
import traceback

from django.http import HttpResponse


class DebugExceptionMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        try:
            response = self.get_response(request)
            if response.status_code == 500:
                print(f"[MW 500] {request.method} {request.path} → 500", flush=True)
            return response
        except Exception as exc:
            tb = traceback.format_exc()
            print(f"[MW EXCEPTION] {request.method} {request.path} → {exc}", flush=True)
            print(tb, flush=True)
            return HttpResponse(f"<pre>{tb}</pre>", status=500, content_type='text/html')
