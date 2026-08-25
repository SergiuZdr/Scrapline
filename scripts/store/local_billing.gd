class_name LocalBilling
extends Billing

## A development stand-in for a real payment processor. **Takes no money and never can.**
##
## It exists so the entire purchase pipeline — pending queue, server validation, replay
## refusal, grant, acknowledge, restore — can be built and tested before the $25 Google
## Play account exists. Every path a real purchase takes is exercised here except the
## payment itself.
##
## It is loud about what it is on purpose. A stub that looks like real billing in a
## screenshot is how a build ships unable to take money with nobody noticing, so
## `is_real()` returns false, the store screen says so in as many words, and a receipt
## from here is marked `is_real = false` all the way to the server.

## Simulated failures, so the unhappy paths are reachable in a test rather than
## theoretical. Set before calling `purchase`.
var next_result: int = Result.OK
var owned: Dictionary = {}

var _counter: int = 0


func is_real() -> bool:
	return false


## Marked, not disguised. A real backend returns the store's own localised string; this
## one has no store to ask, so it says so rather than presenting a plausible price tag.
func price_of(_product_id: String, fallback: String) -> String:
	return "$%s (dev)" % fallback if not fallback.is_empty() else "buy (dev)"


func purchase(product_id: String, reply: Callable) -> void:
	if next_result != Result.OK:
		var failure: int = next_result
		next_result = Result.OK
		reply.call(failure, null)
		return

	if owned.has(product_id):
		reply.call(Result.ALREADY_OWNED, null)
		return

	_counter += 1
	var receipt := Receipt.new()
	receipt.product_id = product_id
	# Shaped like a real order id, and unique per transaction, because the whole
	# duplicate-grant defence is keyed on it.
	receipt.order_id = "DEV.%d.%d" % [int(Time.get_unix_time_from_system()), _counter]
	receipt.token = "dev-token-%s-%d" % [product_id, _counter]
	receipt.purchased_at = int(Time.get_unix_time_from_system())
	receipt.is_real = false
	owned[product_id] = receipt.order_id

	reply.call(Result.OK, receipt)


func acknowledge(_receipt: Billing.Receipt) -> void:
	pass


func restore(reply: Callable) -> void:
	var receipts: Array = []
	for product_id: Variant in owned.keys():
		var receipt := Receipt.new()
		receipt.product_id = String(product_id)
		receipt.order_id = String(owned[product_id])
		receipt.purchased_at = int(Time.get_unix_time_from_system())
		receipts.append(receipt)
	reply.call(Result.OK, receipts)
