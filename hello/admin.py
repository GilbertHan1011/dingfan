from django.contrib import admin
from hello.models import User
from hello2.models import Tester

# Register your models here.
admin.site.register([User, Tester])
