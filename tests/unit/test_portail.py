import json
import logging

import pytest

from portail import ENTETES_SECURITE, creer_app
from portail.journal import FormatJson, configurer_journal


@pytest.fixture()
def web():
    return creer_app("web").test_client()


@pytest.fixture()
def api():
    return creer_app("api").test_client()


def test_service_inconnu_refuse():
    with pytest.raises(ValueError):
        creer_app("autre")


def test_service_par_variable_environnement(monkeypatch):
    monkeypatch.setenv("SERVICE", "api")
    client = creer_app().test_client()
    assert client.get("/api/health").status_code == 200


@pytest.mark.parametrize("client_nom", ["web", "api"])
def test_sante(client_nom, request):
    client = request.getfixturevalue(client_nom)
    reponse = client.get("/health")
    assert reponse.status_code == 200
    assert reponse.get_json()["statut"] == "ok"
    assert reponse.get_json()["service"] == client_nom


def test_accueil(web, monkeypatch):
    reponse = web.get("/")
    assert reponse.status_code == 200
    assert "Portail des portefeuilles" in reponse.get_data(as_text=True)
    assert reponse.headers["Content-Type"].startswith("text/html")


def test_css_mis_en_cache(web):
    reponse = web.get("/static/portail.css")
    assert reponse.status_code == 200
    assert reponse.headers["Cache-Control"] == "public, max-age=86400"


def test_entetes_securite(web):
    reponse = web.get("/")
    for nom in ENTETES_SECURITE:
        assert nom in reponse.headers
    assert reponse.headers["Cache-Control"] == "no-store"


def test_identifiant_requete_repris(web):
    reponse = web.get("/health", headers={"X-Request-Id": "abc123"})
    assert reponse.headers["X-Request-Id"] == "abc123"


def test_web_ne_sert_pas_api(web):
    assert web.get("/api/portefeuilles").status_code == 404


def test_api_ne_sert_pas_accueil(api):
    assert api.get("/").status_code == 404


def test_api_sante(api):
    assert api.get("/api/health").get_json() == {"statut": "ok", "service": "api", "version": "dev"}


def test_api_version(api):
    assert api.get("/api/version").get_json()["environnement"] == "dev"


def test_liste_portefeuilles(api):
    donnees = api.get("/api/portefeuilles").get_json()
    assert donnees["total"] == 3
    assert {pf["id"] for pf in donnees["portefeuilles"]} == {"PF-001", "PF-002", "PF-003"}


def test_portefeuille_trouve(api):
    assert api.get("/api/portefeuilles/PF-002").get_json()["devise"] == "CHF"


def test_portefeuille_introuvable(api):
    reponse = api.get("/api/portefeuilles/PF-999")
    assert reponse.status_code == 404
    assert reponse.get_json()["erreur"] == "portefeuille introuvable"


def test_journal_json(capsys, api):
    api.get("/api/health")
    ligne = capsys.readouterr().out.strip().splitlines()[-1]
    evenement = json.loads(ligne)
    assert evenement["chemin"] == "/api/health"
    assert evenement["statut"] == 200
    assert evenement["service"] == "api"
    assert "duree_ms" in evenement


def test_format_json_champs_extra():
    enregistrement = logging.makeLogRecord({"msg": "test", "levelname": "INFO", "client": "x"})
    sortie = json.loads(FormatJson("web").format(enregistrement))
    assert sortie["client"] == "x"
    assert sortie["message"] == "test"


def test_journal_configure_une_seule_fois():
    premier = configurer_journal("essai")
    second = configurer_journal("essai")
    assert premier is second
    assert len(second.handlers) == 1
