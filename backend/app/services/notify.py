import logging

from app.config import get_settings

_settings = get_settings()
_log = logging.getLogger("medicard.notify")


async def notify_patient(patient_id: str, title: str, body: str) -> None:
    """Best-effort push to the patient's device.

    FCM device-token registration is not built yet, so for now this only logs.
    The patient still sees pending requests and access history by polling their
    own endpoints. Wire real FCM here once devices register tokens.
    """
    if not _settings.fcm_credentials_file:
        _log.info("notify(patient=%s): %s — %s", patient_id, title, body)
        return
    _log.info("notify(patient=%s) [fcm configured but token registry TODO]", patient_id)
