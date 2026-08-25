class_name StoreService
extends RefCounted

## Buying things: real money through `Billing`, premium currency through the profile.
##
## ## The order of operations is the whole feature
##
## ```
## billing confirms  ->  write PENDING to disk  ->  server validates  ->  grant  ->  acknowledge
## ```
##
## Every arrow is a place the app can die, and only one ordering survives all of them.
## Writing the pending record before granting means a crash mid-grant is recoverable at
## the next launch. Acknowledging only after the grant is committed means the store
## refunds anyone we failed to deliver to, which is the correct outcome and not one to
## be clever about.
##
## Validation is **server-side and keyed on the store's order id**, so a captured receipt
## replayed a hundred times grants once. The client's copy of that check is a
## convenience, not a defence.
##
## Offline, real-money purchases are refused outright rather than granted optimistically.
## A grant that the server later rejects would have to be taken back off a player who
## paid, and there is no good way to do that.

const PENDING_LIMIT: int = 32

var content: ContentDB
var billing: Billing
var client: NakamaClient

var _profile: PlayerProfile
var _store: ProfileStore

signal purchases_changed


static func open(
	content_in: ContentDB, profile: PlayerProfile, store: ProfileStore,
	billing_in: Billing = null, client_in: NakamaClient = null
) -> StoreService:
	var service := StoreService.new()
	service.content = content_in
	service._profile = profile
	service._store = store
	service.billing = billing_in if billing_in != null else LocalBilling.new()
	service.client = client_in
	return service


func is_online() -> bool:
	return client != null and client.online


## Products of a kind, in author order. `iap` costs real money; `currency` costs cores.
func products(kind: String = "") -> Array:
	var out: Array = []
	for id: Variant in content.store.keys():
		var product: Dictionary = content.store[id]
		if kind.is_empty() or String(product.get("kind", "")) == kind:
			out.append(product)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("sort", 0)) != int(b.get("sort", 0)):
			return int(a.get("sort", 0)) < int(b.get("sort", 0))
		return String(a.get("id", "")) < String(b.get("id", "")))
	return out


func owns(product_id: String) -> bool:
	return (_state().get("owned", {}) as Dictionary).has(product_id)


## What the player is actually charged, in their own currency, as the store reports it.
func price_of(product: Dictionary) -> String:
	return billing.price_of(
		String(product.get("id", "")), String(product.get("display_price", "")))


func total_spent_products() -> int:
	return (_state().get("owned", {}) as Dictionary).size()


# --- Real money --------------------------------------------------------------

## `reply` receives `(result: int, message: String)`.
func buy_iap(product_id: String, now: int, reply: Callable = Callable()) -> void:
	var product: Dictionary = content.store.get(product_id, {})
	if product.is_empty():
		_settle(reply, Billing.Result.FAILED, "no such product")
		return
	if bool(product.get("once_only", false)) and owns(product_id):
		_settle(reply, Billing.Result.ALREADY_OWNED, Billing.result_name(Billing.Result.ALREADY_OWNED))
		return
	if not is_online() and billing.is_real():
		# Refused, not granted-and-reconciled. Taking something back off a player who
		# paid for it is worse than making them wait for signal.
		_settle(reply, Billing.Result.UNAVAILABLE,
			"purchases need a connection so they can be confirmed")
		return

	billing.purchase(product_id, func(result: int, receipt: Billing.Receipt) -> void:
		if result != Billing.Result.OK or receipt == null:
			_settle(reply, result, Billing.result_name(result))
			return
		# On disk BEFORE anything is granted. If the process dies on the next line, the
		# next launch finds this and finishes the job.
		_remember_pending(receipt)
		_process_pending(now, reply))


## Finishes any purchase that was paid for but not yet delivered. Called at launch, and
## after every purchase.
func process_pending(now: int) -> void:
	_process_pending(now, Callable())


func pending_count() -> int:
	return (_state().get("pending", []) as Array).size()


func _process_pending(now: int, reply: Callable) -> void:
	var pending: Array = (_state().get("pending", []) as Array).duplicate()
	if pending.is_empty():
		_settle(reply, Billing.Result.OK, "")
		return

	for entry: Variant in pending:
		var receipt: Billing.Receipt = Billing.Receipt.from_dict(entry as Dictionary)
		if is_online():
			_validate_then_grant(receipt, now, reply)
		elif not receipt.is_real:
			# A dev-stub receipt has no server to validate against and no money behind
			# it, so it settles locally. This branch can never run for real money:
			# `buy_iap` refuses those while offline.
			_grant_receipt(receipt, now, reply)
		else:
			_settle(reply, Billing.Result.OK, "waiting for a connection to confirm")


func _validate_then_grant(receipt: Billing.Receipt, now: int, reply: Callable) -> void:
	client.rpc_call("validate_purchase", {
		"product": receipt.product_id, "order": receipt.order_id,
		"token": receipt.token, "real": receipt.is_real,
	}, func(ok: bool, response: Dictionary) -> void:
		if not ok:
			_settle(reply, Billing.Result.OK, "waiting for a connection to confirm")
			return
		if not bool(response.get("valid", false)):
			# The server refused it. Drop it rather than retrying forever -- a receipt
			# the server will never accept is not going to start working.
			_forget_pending(receipt.order_id)
			_settle(reply, Billing.Result.FAILED, String(response.get("reason", "not valid")))
			return
		if bool(response.get("duplicate", false)):
			# Already granted on another device. Clearing it is the whole point of the
			# order-id key: the player gets their goods exactly once.
			_forget_pending(receipt.order_id)
			_settle(reply, Billing.Result.OK, "")
			return
		_grant_receipt(receipt, now, reply))


func _grant_receipt(receipt: Billing.Receipt, now: int, reply: Callable) -> void:
	var product: Dictionary = content.store.get(receipt.product_id, {})
	if product.is_empty():
		_forget_pending(receipt.order_id)
		_settle(reply, Billing.Result.FAILED, "no such product")
		return

	var commands: Array = _grant_commands(product.get("grants", {}) as Dictionary, receipt.product_id)
	if not commands.is_empty() and _store.execute_batch(commands) != ProfileCommand.Result.OK:
		# Left pending on purpose: a grant that failed is a debt, and the next launch
		# retries it.
		_settle(reply, Billing.Result.FAILED, "could not deliver; it will retry")
		return

	var state: Dictionary = _state()
	var owned: Dictionary = state.get("owned", {}) as Dictionary
	owned[receipt.product_id] = {"order": receipt.order_id, "at": now}
	state["owned"] = owned
	_forget_pending(receipt.order_id)

	# Only now. Acknowledging earlier tells the store we delivered something we had not.
	billing.acknowledge(receipt)
	purchases_changed.emit()
	_settle(reply, Billing.Result.OK, "")


# --- Premium currency --------------------------------------------------------

## Buys a `currency`-kind offer with cores. No receipts, no store, no network: this is a
## profile transaction like any other, and goes through the command layer.
func buy_with_currency(product_id: String, now: int) -> int:
	var product: Dictionary = content.store.get(product_id, {})
	if product.is_empty() or String(product.get("kind", "")) != "currency":
		return ProfileCommand.Result.INVALID

	var cost: int = int(product.get("cost_amount", 0))
	var currency: String = String(product.get("cost_currency", PlayerProfile.CORES))
	if not _profile.can_afford(currency, cost):
		return ProfileCommand.Result.NOT_ENOUGH_CURRENCY

	var commands: Array = [ProfileCommands.SpendCurrency.new(currency, cost, "store:" + product_id)]
	commands.append_array(_grant_commands(product.get("grants", {}) as Dictionary, product_id))
	var result: int = _store.execute_batch(commands)
	if result == ProfileCommand.Result.OK:
		var _unused: int = now
		purchases_changed.emit()
	return result


# --- Helpers -----------------------------------------------------------------

func _grant_commands(grants: Dictionary, source: String) -> Array:
	var commands: Array = []
	var keys: Array = grants.keys()
	keys.sort()
	for key: Variant in keys:
		var name: String = String(key)
		match name:
			PlayerProfile.SCRAP, PlayerProfile.ALLOY, PlayerProfile.CORES:
				commands.append(ProfileCommands.GrantCurrency.new(
					name, int(grants[key]), "store:" + source))
			"part_ids":
				# Named, not rolled. A bundle bought with money has to contain exactly
				# what its listing said, or the listing is a lie in most jurisdictions.
				for part_id: Variant in (grants[key] as Array):
					commands.append(ProfileCommands.GrantPart.new(String(part_id)))
			"pass_premium":
				commands.append(ProfileCommands.UnlockPassPremium.new())
			_:
				push_warning("store: unknown grant '%s'" % name)
	return commands


func _remember_pending(receipt: Billing.Receipt) -> void:
	var state: Dictionary = _state()
	var pending: Array = state.get("pending", []) as Array
	for entry: Variant in pending:
		if String((entry as Dictionary).get("order", "")) == receipt.order_id:
			return
	if pending.size() >= PENDING_LIMIT:
		push_warning("store: pending queue is full")
		return
	pending.append(receipt.to_dict())
	state["pending"] = pending
	_commit()


func _forget_pending(order_id: String) -> void:
	var state: Dictionary = _state()
	var pending: Array = state.get("pending", []) as Array
	var kept: Array = []
	for entry: Variant in pending:
		if String((entry as Dictionary).get("order", "")) != order_id:
			kept.append(entry)
	state["pending"] = kept
	_commit()


func _state() -> Dictionary:
	if not _profile.data.has("store"):
		_profile.data["store"] = {"owned": {}, "pending": []}
	return _profile.data["store"] as Dictionary


func _commit() -> void:
	if _store == null:
		return
	var result: int = _store.execute(ProfileCommands.SetStoreState.new(_state()))
	if result != ProfileCommand.Result.OK:
		push_warning("store: state rejected (" + ProfileCommand.result_name(result) + ")")


func _settle(reply: Callable, result: int, message: String) -> void:
	if reply.is_valid():
		reply.call(result, message)
