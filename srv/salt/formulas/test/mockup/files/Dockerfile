FROM python:3.7

ARG VERSION

ENV MYAPP_VERSION="{{ salt['pillar.get']('mockup:version') }}"
RUN pip install django

WORKDIR /usr/src/app

COPY . .

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
