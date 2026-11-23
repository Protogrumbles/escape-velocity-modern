# Commodity economy for slice 1 (design doc §5).
# Prices are fixed per-planet base prices from data/planets.json.
# Slice 1 deliberately has NO stock-sensitive pricing, no events
# and no random noise: prices must be legible enough to learn.
# Stock movement and event spikes are Stage B work (see DESIGN.md).
class_name Economy
extends RefCounted

const COMMODITIES: Array[String] = [
	"food",
	"industrial_goods",
	"ore",
	"medicine",
	"luxuries",
]


static func price(planet: Dictionary, commodity: String) -> int:
	var prices: Dictionary = planet.get("prices", {})
	return int(prices.get(commodity, 0))


static func cargo_used(cargo: Dictionary) -> int:
	var total := 0
	for commodity in cargo:
		total += int(cargo[commodity])
	return total


static func cargo_value(cargo: Dictionary, planet: Dictionary) -> int:
	var total := 0
	for commodity in cargo:
		total += int(cargo[commodity]) * price(planet, String(commodity))
	return total


static func buy_cost(planet: Dictionary, commodity: String, qty: int) -> int:
	return price(planet, commodity) * qty
