"""Drives a public Gradio app the way its web page does -- the queue protocol, one session for
every call -- with only the standard library (017). For apps whose functions keep per-session
state: TRELLIS makes a working folder in `start_session`, so its REST endpoints called one by
one fail with no message (each call is a new session with no folder).

    python3 tools/gen3d/gradio_queue.py <space-url> <out-dir> '<json: [[api_name, [inputs]], ...]>'

Inputs are the dependency's FULL input list from `/config`, `gr.State` slots included (pass
null): the REST API hides them, the queue does not. Each step's output is printed; files in
the LAST step's output are saved to <out-dir>. HF_TOKEN is sent as a bearer token, which is
what the ZeroGPU quota message asks for (the anonymous quota cannot cover one TRELLIS call:
120 s asked). Untested with a token -- there was none on this machine in 017.

TRELLIS, image already uploaded to `<space>/gradio_api/upload` as PATH:

    python3 tools/gen3d/gradio_queue.py https://trellis-community-trellis.hf.space out \
      '[["start_session", []], ["preprocess_image", [IMG]],
        ["generate_and_extract_glb", [IMG, [], null, 0, 7.5, 12, 3.0, 12, "stochastic", 0.95, 1024]]]'
    # IMG = {"path": PATH, "meta": {"_type": "gradio.FileData"}}
"""
import json
import os
import random
import string
import sys
import time
import urllib.request


def get_json(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.loads(r.read().decode())


def headers():
    token = os.environ.get("HF_TOKEN", "")
    out = {"Content-Type": "application/json"}
    if token:
        out["Authorization"] = "Bearer " + token
    return out


def post(url, payload):
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=headers())
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())


def files_in(value, found):
    if isinstance(value, dict):
        if value.get("url"):
            found.append(value)
        for v in value.values():
            files_in(v, found)
    elif isinstance(value, list):
        for v in value:
            files_in(v, found)
    return found


def main():
    base, out, steps = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
    config = get_json(base + "/config")
    index = {}
    for i, dep in enumerate(config.get("dependencies", [])):
        name = dep.get("api_name")
        if name:
            index[str(name).lstrip("/")] = dep.get("id", i)
    session = "".join(random.choice(string.ascii_lowercase + string.digits) for _ in range(11))
    last = None
    for api_name, data in steps:
        fn = index[api_name.lstrip("/")]
        t = time.time()
        post(base + "/gradio_api/queue/join", {"data": data, "event_data": None, "fn_index": fn,
                                               "trigger_id": None, "session_hash": session})
        result = None
        stream = urllib.request.Request(base + "/gradio_api/queue/data?session_hash=" + session, headers=headers())
        with urllib.request.urlopen(stream, timeout=1200) as r:
            for raw in r:
                line = raw.decode().strip()
                if not line.startswith("data:"):
                    continue
                msg = json.loads(line[5:].strip())
                kind = msg.get("msg")
                if kind in ("estimation", "process_starts", "progress", "heartbeat", "log"):
                    if kind == "log":
                        print("  log:", msg.get("log"))
                    continue
                if kind == "process_completed":
                    result = msg
                    break
        ok = bool(result and result.get("success"))
        print("%s: %s in %.0fs" % (api_name, "ok" if ok else "FAILED", time.time() - t))
        if not ok:
            print(json.dumps(result)[:800])
            sys.exit(1)
        last = result.get("output", {}).get("data")
        print("  ", json.dumps(last)[:400])
    os.makedirs(out, exist_ok=True)
    for i, f in enumerate(files_in(last, [])):
        name = f.get("orig_name") or os.path.basename(str(f.get("path", "file_%d" % i)))
        path = os.path.join(out, "%d_%s" % (i, name))
        urllib.request.urlretrieve(f["url"], path)
        print("saved", path, os.path.getsize(path))


if __name__ == "__main__":
    main()
