"""Point d'entrée gunicorn : `gunicorn wsgi:app`."""

from portail import creer_app

app = creer_app()
