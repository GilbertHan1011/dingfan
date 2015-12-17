# -*- coding: utf-8 -*-

from django.http import HttpResponse
from hello.models import User
from django.shortcuts import render
import json


# Create your views here.
def first_page(request):
    print "sssssssssdddddd"
    print request
    users = User.objects.all()
    a = []
    for i in range(0, len(users)):
        print users[i]
        a.append(users[i].name)
    print a
    context = {"label": "!!!!!!!!!!!"}
    return render(request, 'hello2.html', context)


def action1(resquest):
    # print resquest.GET["user"]
    print "vvvvvvv"
    # s = "xxxxxxxx"
    # new_user = User(name=resquest.GET["user"])
    # new_user.save()
    users = User.objects.all()
    print users
    res = HttpResponse(json.dumps({"a": "b"}), content_type="application/json")
    # res["Access-Control-Allow-Origin"] = '*'
    return res
