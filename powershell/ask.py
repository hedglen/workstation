import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
GEMINI_DEFAULT_MODEL = "gemini-2.5-flash"
ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_DEFAULT_MODEL = "claude-3-5-haiku-latest"
ANTHROPIC_API_VERSION = "2023-06-01"


class BackendError(Exception):
    pass


def fail(message: str, code: int = 1) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(code)


def build_system_prompt(cwd: str) -> str:
    return f"""You are a concise terminal command assistant for Windows PowerShell inside WezTerm.

Rules:
- Prefer PowerShell syntax on Windows.
- For app installs or downloads on Windows, prefer winget when appropriate.
- Give short, practical answers optimized for copy/paste.
- Default format:
  1. One short sentence.
  2. A fenced powershell code block with the best command(s).
  3. Optional short note if there is a meaningful caveat.
- Mention when admin rights may be required.
- Do not use markdown tables.

Current shell: PowerShell
Current working directory: {cwd}
"""


def call_gemini(prompt: str, cwd: str) -> str:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise BackendError("Gemini is not configured in this shell.")

    model = os.environ.get("GEMINI_ASK_MODEL", GEMINI_DEFAULT_MODEL)
    payload = {
        "systemInstruction": {
            "parts": [{"text": build_system_prompt(cwd)}],
        },
        "contents": [
            {
                "parts": [{"text": prompt}],
            }
        ],
        "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 700,
        },
    }
    url = GEMINI_API_URL.format(model=urllib.parse.quote(model, safe=""))
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "content-type": "application/json",
            "x-goog-api-key": api_key,
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        lower_details = details.lower()
        if "api_key_invalid" in lower_details or "api key not valid" in lower_details:
            raise BackendError("Gemini is configured, but the API key is invalid.")
        raise BackendError(f"Gemini API error ({exc.code}).")
    except urllib.error.URLError as exc:
        raise BackendError(f"Network error talking to Gemini: {exc.reason}")

    parts = []
    for candidate in body.get("candidates", []):
        content = candidate.get("content", {})
        for part in content.get("parts", []):
            text = part.get("text")
            if text:
                parts.append(text)

    answer = "\n".join(part.rstrip() for part in parts if part.strip()).strip()
    if not answer:
        raise BackendError("Gemini returned an empty response.")
    return answer


def call_anthropic(prompt: str, cwd: str) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise BackendError("Anthropic is not configured in this shell.")

    model = os.environ.get("ANTHROPIC_ASK_MODEL", ANTHROPIC_DEFAULT_MODEL)
    payload = {
        "model": model,
        "max_tokens": 700,
        "system": build_system_prompt(cwd),
        "messages": [{"role": "user", "content": prompt}],
    }

    request = urllib.request.Request(
        ANTHROPIC_API_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "content-type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": ANTHROPIC_API_VERSION,
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        lower_details = details.lower()
        if "credit balance is too low" in lower_details:
            raise BackendError("Anthropic is configured, but that account is out of API credits.")
        raise BackendError(f"Anthropic API error ({exc.code}).")
    except urllib.error.URLError as exc:
        raise BackendError(f"Network error talking to Anthropic: {exc.reason}")

    chunks = []
    for item in body.get("content", []):
        if item.get("type") == "text":
            chunks.append(item.get("text", ""))

    answer = "\n".join(part.rstrip() for part in chunks if part.strip()).strip()
    if not answer:
        raise BackendError("Anthropic returned an empty response.")
    return answer


def main() -> None:
    prompt = " ".join(sys.argv[1:]).strip()
    if not prompt:
        fail('Usage: ask "what you want to do"')

    cwd = os.getcwd()
    problems = []

    if os.environ.get("GEMINI_API_KEY"):
        try:
            print(call_gemini(prompt, cwd))
            return
        except BackendError as exc:
            problems.append(str(exc))

    if os.environ.get("ANTHROPIC_API_KEY"):
        try:
            print(call_anthropic(prompt, cwd))
            return
        except BackendError as exc:
            problems.append(str(exc))

    if problems:
        fail("No working AI backend is available right now.\n- " + "\n- ".join(problems))

    fail("No supported AI backend is configured. Set GEMINI_API_KEY or ANTHROPIC_API_KEY.")


if __name__ == "__main__":
    main()
