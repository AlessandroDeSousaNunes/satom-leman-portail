"""Journalisation structurée en JSON (une ligne par événement), lue par CloudWatch Logs."""

from __future__ import annotations

import json
import logging
import sys
from datetime import UTC, datetime

CHAMPS_STANDARD = set(vars(logging.makeLogRecord({})))


class FormatJson(logging.Formatter):
    """Formate chaque enregistrement en objet JSON avec les champs ajoutés par `extra`."""

    def __init__(self, service: str) -> None:
        super().__init__()
        self.service = service

    def format(self, record: logging.LogRecord) -> str:
        donnees = {
            "horodatage": datetime.fromtimestamp(record.created, tz=UTC).isoformat(),
            "niveau": record.levelname,
            "service": self.service,
            "message": record.getMessage(),
        }
        for cle, valeur in vars(record).items():
            if cle not in CHAMPS_STANDARD and cle not in donnees:
                donnees[cle] = valeur
        return json.dumps(donnees, ensure_ascii=False, default=str)


class SortieStandard(logging.StreamHandler):
    """Écrit toujours sur le sys.stdout courant (utile sous gunicorn et dans les tests)."""

    @property
    def stream(self):
        return sys.stdout

    @stream.setter
    def stream(self, _valeur) -> None:
        """Le flux est toujours sys.stdout : la valeur imposée par logging est ignorée."""


def configurer_journal(service: str) -> logging.Logger:
    """Retourne le journal du service, configuré une seule fois."""
    journal = logging.getLogger(f"portail.{service}")
    if not journal.handlers:
        sortie = SortieStandard()
        sortie.setFormatter(FormatJson(service))
        journal.addHandler(sortie)
        journal.setLevel(logging.INFO)
        journal.propagate = False
    return journal
