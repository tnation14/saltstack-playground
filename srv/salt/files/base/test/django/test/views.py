from django.conf import settings
from django.http import HttpResponse


def version(request):
    return HttpResponse("Hi! I'm running {}\n".format(settings.VERSION))
