# -*- coding: utf-8 -*-

from django.http import HttpResponse


# Create your views here.
def first_page(request):
    return HttpResponse("<p>受到粉丝的</p>")
