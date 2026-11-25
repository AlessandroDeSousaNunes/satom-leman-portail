"""Portail Groupe Léman Finance SA : service web et API des portefeuilles.

Une seule image sert deux rôles, choisis par la variable SERVICE :
- web : page d'accueil, fichiers statiques, /health ;
- api : routes /api/* (santé, portefeuilles, version).
"""

from __future__ import annotations

import os
import time
import uuid

from flask import Flask, Response, g, jsonify, request

from portail.journal import configurer_journal

VERSION = os.environ.get("APP_VERSION", "dev")

PORTEFEUILLES = [
    {"id": "PF-001", "client": "Client A", "devise": "CHF", "valeur": 1250000.0, "risque": "modéré"},
    {"id": "PF-002", "client": "Client B", "devise": "CHF", "valeur": 480000.0, "risque": "prudent"},
    {"id": "PF-003", "client": "Client C", "devise": "EUR", "valeur": 2100000.0, "risque": "dynamique"},
]

ENTETES_SECURITE = {
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": "default-src 'self'; frame-ancestors 'none'; form-action 'self'",
    "Permissions-Policy": "geolocation=(), camera=(), microphone=()",
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Resource-Policy": "same-origin",
    "Cache-Control": "no-store",
}

PAGE_ACCUEIL = """<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="Portail des portefeuilles du Groupe Léman Finance SA">
<title>Portail Léman Finance</title>
<link rel="stylesheet" href="/static/portail.css">
</head>
<body>
<main>
<h1>Portail des portefeuilles</h1>
<p>Groupe Léman Finance SA · environnement <strong>{env}</strong> · version {version}</p>
<p><a href="/api/portefeuilles">Liste des portefeuilles (API)</a></p>
</main>
</body>
</html>
"""

CSS = "body{font-family:system-ui,sans-serif;margin:2rem;color:#13254f}a{color:#0b5cad}"


def creer_app(service: str | None = None) -> Flask:
    """Construit l'application pour le rôle demandé (web ou api)."""
    service = (service or os.environ.get("SERVICE", "web")).lower()
    if service not in ("web", "api"):
        raise ValueError(f"SERVICE inconnu : {service}")

    app = Flask(__name__, static_folder=None)
    journal = configurer_journal(service)
    environnement = os.environ.get("ENVIRONNEMENT", "dev")

    @app.before_request
    def _debut() -> Response | None:
        g.debut = time.perf_counter()
        g.requete_id = request.headers.get("X-Request-Id") or uuid.uuid4().hex
        # Injection de panne (sprint 12, test d'alarme de bout en bout) : PANNE_SIMULEE=1 fait répondre 503
        # aux routes métier de l'API ; les sondes de santé restent vertes pour que l'ALB garde ses cibles.
        if (
            os.environ.get("PANNE_SIMULEE") == "1"
            and request.path.startswith("/api/")
            and request.path != "/api/health"
        ):
            return Response('{"erreur": "panne simulee"}', status=503, mimetype="application/json")
        return None

    @app.after_request
    def _fin(reponse: Response) -> Response:
        for nom, valeur in ENTETES_SECURITE.items():
            reponse.headers.setdefault(nom, valeur)
        if request.path.startswith("/static/"):
            reponse.headers["Cache-Control"] = "public, max-age=86400"
        reponse.headers["X-Request-Id"] = g.requete_id
        journal.info(
            "requete",
            extra={
                "requete_id": g.requete_id,
                "methode": request.method,
                "chemin": request.path,
                "statut": reponse.status_code,
                "duree_ms": round((time.perf_counter() - g.debut) * 1000, 2),
                "trace_id": request.headers.get("X-Amzn-Trace-Id", ""),
            },
        )
        return reponse

    @app.get("/health")
    def sante():
        return jsonify(statut="ok", service=service, version=VERSION)

    if service == "web":

        @app.get("/")
        def accueil():
            html = PAGE_ACCUEIL.format(env=environnement, version=VERSION)
            return Response(html, mimetype="text/html")

        @app.get("/static/portail.css")
        def css():
            return Response(CSS, mimetype="text/css")

    else:

        @app.get("/api/health")
        def api_sante():
            return jsonify(statut="ok", service="api", version=VERSION)

        @app.get("/api/version")
        def api_version():
            return jsonify(version=VERSION, environnement=environnement)

        @app.get("/api/portefeuilles")
        def portefeuilles():
            return jsonify(portefeuilles=PORTEFEUILLES, total=len(PORTEFEUILLES))

        @app.get("/api/portefeuilles/<identifiant>")
        def portefeuille(identifiant: str):
            for pf in PORTEFEUILLES:
                if pf["id"] == identifiant:
                    return jsonify(pf)
            return jsonify(erreur="portefeuille introuvable"), 404

    @app.errorhandler(404)
    def introuvable(_erreur):
        return jsonify(erreur="ressource introuvable"), 404

    return app
