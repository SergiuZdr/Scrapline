class_name NakamaClient
extends Node

## A thin REST client for Nakama.
##
## Deliberately **not** the official GDScript SDK. Async PvP needs exactly two things
## from the server — authenticate once, then call RPCs — and both are plain HTTP. The
## SDK's value is its realtime socket, which nothing in this phase uses. Taking the
## dependency now would mean carrying an addon, its version drift and its export
## quirks for a feature that arrives in Phase 5.
##
## When live PvP lands, this class is where the socket goes, and everything above it
## is unchanged.
##
## Every call is fire-and-forget with a `Callable` reply, because the whole point of an
## async ladder is that no screen ever blocks on the network. A request that fails
## reports the failure; it never leaves the caller waiting.

signal connection_changed(online: bool)

const CONFIG_PATH: String = "user://server.json"
const DEFAULT_HOST: String = "127.0.0.1"
const DEFAULT_PORT: int = 7350
const DEFAULT_KEY: String = "defaultkey"
const TIMEOUT_SEC: float = 8.0

## A session token is good for two hours (see the compose file). Refresh well before
## that so a long play session never fails a submit on an expired token.
const TOKEN_LIFETIME_SEC: int = 7200
const TOKEN_REFRESH_MARGIN_SEC: int = 300

var host: String = DEFAULT_HOST
var port: int = DEFAULT_PORT
var server_key: String = DEFAULT_KEY
var use_tls: bool = false
var enabled: bool = false

var online: bool = false
var user_id: String = ""

var _token: String = ""
var _token_expires_at: int = 0
var _device_id: String = ""
var _pending: Array = []


func _ready() -> void:
	_load_config()
	_apply_overrides()


## `--server <host:port>` points a build at a server without editing a file, which is
## how the game gets tested against a local stack. `--offline` forces the offline path
## even when a config exists, so offline behaviour can be checked deliberately rather
## than by unplugging something.
func _apply_overrides() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--server")
	if index >= 0 and index + 1 < args.size():
		var target: String = args[index + 1].replace("http://", "").replace("https://", "")
		var parts: PackedStringArray = target.split(":")
		host = parts[0]
		if parts.size() > 1:
			port = int(parts[1])
		enabled = true
	if args.has("--offline"):
		enabled = false


## Server settings live in a file, not in code, so a build can be pointed at a laptop,
## a VPS or nothing at all without recompiling. Absent file means offline, which is the
## correct default: the game is fully playable with no server in existence.
func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(CONFIG_PATH)) != OK:
		push_warning("nakama: unreadable " + CONFIG_PATH)
		return
	var config: Dictionary = json.data as Dictionary
	if config == null:
		return
	host = String(config.get("host", DEFAULT_HOST))
	port = int(config.get("port", DEFAULT_PORT))
	server_key = String(config.get("key", DEFAULT_KEY))
	use_tls = bool(config.get("tls", false))
	enabled = bool(config.get("enabled", true))


func save_config() -> void:
	var file: FileAccess = FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"host": host, "port": port, "key": server_key, "tls": use_tls, "enabled": enabled,
	}, "\t"))
	file.close()


func base_url() -> String:
	return "%s://%s:%d" % ["https" if use_tls else "http", host, port]


# --- Authentication ----------------------------------------------------------

## Device authentication: no email, no password, no account screen between a new player
## and their first battle. An account upgrade path (email, Google, Apple) is a later
## RPC on the same identity, which is exactly why device auth is the right first door.
##
## **No username is sent.** Nakama usernames are unique server-wide, so passing the
## player's display name meant the second player ever to sign in was rejected with
## "username already in use" -- every new account after the first, silently offline.
## Nakama generates a handle; the name other players actually see travels with the
## defence record, where duplicates are somebody else's problem to care about.
func authenticate(device_id: String, reply: Callable = Callable()) -> void:
	if not enabled:
		_settle(reply, false, {"error": "server disabled"})
		return
	_device_id = device_id

	var body: Dictionary = {"id": device_id}
	# The server key is the HTTP basic *username*, with an empty password. That is
	# Nakama's scheme, and getting it wrong returns a 401 that reads like a bad device id.
	var auth: String = Marshalls.utf8_to_base64(server_key + ":")
	var headers: PackedStringArray = [
		"Content-Type: application/json", "Authorization: Basic " + auth,
	]
	var url: String = "%s/v2/account/authenticate/device?create=true" % base_url()

	_request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body),
		func(ok: bool, response: Dictionary) -> void:
			if ok and response.has("token"):
				_token = String(response["token"])
				_token_expires_at = int(Time.get_unix_time_from_system()) + TOKEN_LIFETIME_SEC
				user_id = _user_id_from_token(_token)
				_set_online(true)
				_settle(reply, true, {"user_id": user_id})
			else:
				_set_online(false)
				_settle(reply, false, response))


func is_authenticated() -> bool:
	return not _token.is_empty() \
		and int(Time.get_unix_time_from_system()) < _token_expires_at - TOKEN_REFRESH_MARGIN_SEC


## The user id is in the JWT payload. Reading it here saves a round trip, and a token we
## cannot parse is a token we should not be trusting anyway.
func _user_id_from_token(token: String) -> String:
	var parts: PackedStringArray = token.split(".")
	if parts.size() < 2:
		return ""
	var payload: String = parts[1]
	# JWT uses base64url without padding; Godot's decoder wants standard base64 with it.
	payload = payload.replace("-", "+").replace("_", "/")
	while payload.length() % 4 != 0:
		payload += "="
	var raw: PackedByteArray = Marshalls.base64_to_raw(payload)
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK:
		return ""
	return String((json.data as Dictionary).get("uid", ""))


# --- RPC ---------------------------------------------------------------------

## Calls a server RPC. `reply` receives `(ok: bool, payload: Dictionary)`.
func rpc_call(id: String, payload: Dictionary, reply: Callable = Callable()) -> void:
	if not is_authenticated():
		_settle(reply, false, {"error": "not authenticated"})
		return

	var headers: PackedStringArray = [
		"Content-Type: application/json", "Authorization: Bearer " + _token,
	]
	# Nakama's RPC body is a JSON *string* containing the payload, not the payload
	# itself. Sending the object directly is accepted and then arrives as garbage.
	var body: String = JSON.stringify(JSON.stringify(payload))

	_request("%s/v2/rpc/%s" % [base_url(), id], headers, HTTPClient.METHOD_POST, body,
		func(ok: bool, response: Dictionary) -> void:
			if not ok:
				_set_online(false)
				_settle(reply, false, response)
				return
			# The result comes back double-encoded too: a JSON envelope whose `payload`
			# is itself a JSON string.
			var inner := JSON.new()
			if inner.parse(String(response.get("payload", "{}"))) != OK:
				_settle(reply, false, {"error": "unparseable rpc payload"})
				return
			_settle(reply, true, inner.data as Dictionary))


# --- Transport ---------------------------------------------------------------

func _request(
	url: String, headers: PackedStringArray, method: int, body: String, reply: Callable
) -> void:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SEC
	add_child(http)
	_pending.append(http)

	http.request_completed.connect(
		func(result: int, code: int, _h: PackedStringArray, data: PackedByteArray) -> void:
			_pending.erase(http)
			http.queue_free()

			if result != HTTPRequest.RESULT_SUCCESS:
				reply.call(false, {"error": "transport %d" % result})
				return

			var json := JSON.new()
			var text: String = data.get_string_from_utf8()
			var parsed: Dictionary = {}
			if json.parse(text) == OK and json.data is Dictionary:
				parsed = json.data as Dictionary

			if code < 200 or code >= 300:
				reply.call(false, {"error": String(parsed.get("message", text)), "code": code})
				return
			reply.call(true, parsed))

	if http.request(url, headers, method, body) != OK:
		_pending.erase(http)
		http.queue_free()
		reply.call(false, {"error": "request failed to start"})


func _settle(reply: Callable, ok: bool, payload: Dictionary) -> void:
	if reply.is_valid():
		reply.call(ok, payload)


func _set_online(value: bool) -> void:
	if online == value:
		return
	online = value
	connection_changed.emit(online)
