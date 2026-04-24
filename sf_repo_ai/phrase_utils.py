from __future__ import annotations

import re


def _phrase_pattern(phrase: str) -> str:
    return r"\b" + re.escape(phrase).replace(r"\ ", r"\s+") + r"\b"


def has_phrase(text: str, *phrases: str) -> bool:
    for phrase in phrases:
        if re.search(_phrase_pattern(phrase), text):
            return True
    return False


def has_all_phrases(text: str, *phrases: str) -> bool:
    return all(re.search(_phrase_pattern(phrase), text) for phrase in phrases)


def starts_with_phrase(text: str, *phrases: str) -> bool:
    for phrase in phrases:
        if re.match(r"^\s*" + _phrase_pattern(phrase), text):
            return True
    return False
