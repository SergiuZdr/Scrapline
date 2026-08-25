class_name Billing
extends RefCounted

## The payment backend, behind an interface.
##
## There are exactly two things a game must get right about in-app purchase, and both
## are about **failure**, not about the happy path:
##
##   1. **A player who paid must receive their goods**, even if the app was killed
##      between the charge and the grant. That is why a purchase is written to disk as
##      *pending* the moment the store confirms it, and only acknowledged once the grant
##      has been committed. A purchase acknowledged before it is granted is money taken
##      for nothing, and it is the single most common IAP bug in shipped games.
##   2. **A receipt must not be usable twice.** Validation happens on the server, keyed
##      on the store's order id, so replaying a captured receipt grants nothing.
##
## Google Play Billing needs a $25 developer account, a signed build and a real device.
## None of those exist yet, so `LocalBilling` stands in — and it is deliberately loud
## about being a stub, because a fake billing backend that looks real in a screenshot is
## how a build ships taking nobody's money and nobody notices.

## What a completed purchase looks like, whatever backend produced it.
class Receipt extends RefCounted:
	var product_id: String = ""
	## The store's own id for this transaction. The replay key -- never invent it.
	var order_id: String = ""
	## Opaque blob the server validates with the store. Empty for the local stub.
	var token: String = ""
	var purchased_at: int = 0
	## True when this came from a real payment processor rather than the dev stub.
	var is_real: bool = false

	func to_dict() -> Dictionary:
		return {
			"product": product_id, "order": order_id, "token": token,
			"at": purchased_at, "real": is_real,
		}

	static func from_dict(d: Dictionary) -> Receipt:
		var r := Receipt.new()
		r.product_id = String(d.get("product", ""))
		r.order_id = String(d.get("order", ""))
		r.token = String(d.get("token", ""))
		r.purchased_at = int(d.get("at", 0))
		r.is_real = bool(d.get("real", false))
		return r


enum Result {
	OK,
	CANCELLED,       ## the player backed out; not an error, and never shown as one
	UNAVAILABLE,     ## no billing on this platform or no connection to the store
	ALREADY_OWNED,   ## a one-per-account product they already have
	FAILED,
}


static func result_name(result: int) -> String:
	match result:
		Result.OK: return "ok"
		Result.CANCELLED: return "cancelled"
		Result.UNAVAILABLE: return "the store is unavailable right now"
		Result.ALREADY_OWNED: return "you already own this"
		Result.FAILED: return "the purchase did not go through"
	return "unknown"


## True when this backend can actually take money.
func is_real() -> bool:
	return false


## Localised price for a product, as the store reports it. **Never a hardcoded string**:
## a player paying in zloty must not be shown a dollar figure, and stores reject listings
## that do it.
func price_of(_product_id: String, fallback: String) -> String:
	return fallback


## Starts a purchase. `reply` receives `(result: int, receipt: Receipt)`.
func purchase(_product_id: String, reply: Callable) -> void:
	reply.call(Result.UNAVAILABLE, null)


## Tells the store the goods were delivered. Until this is called the store may refund
## the player automatically -- which is the correct behaviour, and the reason this is
## called only after the grant is committed.
func acknowledge(_receipt: Receipt) -> void:
	pass


## Purchases made on another device or before a reinstall. Restoring is a store
## requirement, not a nicety.
func restore(reply: Callable) -> void:
	reply.call(Result.UNAVAILABLE, [])
