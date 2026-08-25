class_name NakamaHttp
extends RefCounted

## Blocking HTTP for headless processes — the verification worker and the online
## integration test.
##
## Not to be confused with `scripts/net/nakama_client.gd`, which is the *game's* client:
## that one is asynchronous because a screen must never block on the network. A worker
## has nothing better to do than wait, and a test wants to read like a script, so this
## one blocks and returns a value.
##
## Both speak the same two quirks of Nakama's HTTP API, and they are the two things that
## silently produce nonsense if you get them wrong:
##
##   1. The RPC payload is a JSON **string** inside the request body — encoded twice.
##   2. The reply is the same shape: an envelope whose `payload` is a JSON string.

var host: String = "127.0.0.1"
var port: int = 7350


static func open(base_url: String) -> NakamaHttp:
	var http := NakamaHttp.new()
	var stripped: String = base_url.replace("https://", "").replace("http://", "")
	var parts: PackedStringArray = stripped.split(":")
	http.host = parts[0]
	if parts.size() > 1:
		http.port = int(parts[1])
	return http


## Device authentication. Returns the session token, or "" with the error printed.
func authenticate(server_key: String, device_id: String, username: String) -> String:
	var auth: String = Marshalls.utf8_to_base64(server_key + ":")
	var response: Dictionary = _send(
		"/v2/account/authenticate/device?create=true&username=" + username.uri_encode(),
		["Content-Type: application/json", "Authorization: Basic " + auth],
		JSON.stringify({"id": device_id}))
	if response.has("error"):
		printerr("auth failed: ", response["error"])
		return ""
	return String(response.get("token", ""))


## An RPC as a signed-in player.
func rpc_as_user(token: String, id: String, payload: Dictionary) -> Dictionary:
	return _rpc("/v2/rpc/" + id,
		["Content-Type: application/json", "Authorization: Bearer " + token], payload)


## An RPC as the server itself. An `http_key` request arrives with no user attached,
## which is precisely what the worker-only endpoints check for.
func rpc_as_server(http_key: String, id: String, payload: Dictionary) -> Dictionary:
	return _rpc("/v2/rpc/%s?http_key=%s" % [id, http_key.uri_encode()],
		["Content-Type: application/json"], payload)


## Raw GET, for the REST endpoints that are not RPCs (the leaderboard, say).
func get_json(path: String, token: String) -> Dictionary:
	return _send(path, ["Authorization: Bearer " + token], "", HTTPClient.METHOD_GET)


func _rpc(path: String, headers: PackedStringArray, payload: Dictionary) -> Dictionary:
	var envelope: Dictionary = _send(path, headers, JSON.stringify(JSON.stringify(payload)))
	if envelope.has("error"):
		return envelope
	var inner := JSON.new()
	if inner.parse(String(envelope.get("payload", "{}"))) != OK:
		return {"error": "unparseable rpc payload"}
	return inner.data as Dictionary


func _send(
	path: String, headers: PackedStringArray, body: String,
	method: int = HTTPClient.METHOD_POST
) -> Dictionary:
	var client := HTTPClient.new()
	if client.connect_to_host(host, port) != OK:
		return {"error": "cannot reach %s:%d" % [host, port]}
	while client.get_status() == HTTPClient.STATUS_CONNECTING \
			or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(20)
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return {"error": "connection refused by %s:%d" % [host, port]}

	if client.request(method, path, headers, body) != OK:
		return {"error": "request failed to start"}
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(20)

	var chunks: PackedByteArray = PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		chunks.append_array(client.read_response_body_chunk())
	var code: int = client.get_response_code()
	client.close()

	var json := JSON.new()
	var text: String = chunks.get_string_from_utf8()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return {"error": "unparseable response (%d): %s" % [code, text.substr(0, 120)]}
	var parsed: Dictionary = json.data as Dictionary
	if code < 200 or code >= 300:
		return {"error": String(parsed.get("message", "http %d" % code))}
	return parsed
