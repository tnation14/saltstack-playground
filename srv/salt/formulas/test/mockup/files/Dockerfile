FROM python:3.7

RUN pip install django

WORKDIR /usr/src/app

COPY . .

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
