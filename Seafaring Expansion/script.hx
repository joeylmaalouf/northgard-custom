var centerZone = getZone(164);
var mainlandBeachZones = [for (i in [118, 115, 104, 95, 103, 110, 123, 139, 154, 175, 193, 210, 216, 233, 221, 227, 222, 211, 195, 176, 156, 142]) getZone(i)];
var homeZones = [for (i in [70, 30, 63, 155, 250, 304, 267, 174]) getZone(i)];
var landingPoints = [[], [], [], [], [], [], [], []];
var isSpecialColonizing = [false, false, false, false, false, false, false, false];
var maxLandingPoints = 2;
var maxUnitsPerDrakkar = 12;
var specialColonizeCost = 200;


function saveState () {
	// we don't support saving and loading yet
}


function init () {
	if (state.time == 0) {
		onFirstLaunch();
	}
	onEachLaunch();
}


function onFirstLaunch () {
	// remove all existing victory conditions besides Helheim
	state.removeVictory(VictoryKind.VMilitary);
	state.removeVictory(VictoryKind.VFame);
	state.removeVictory(VictoryKind.VMoney);
	state.removeVictory(VictoryKind.VLore);
	state.removeVictory(VictoryKind.VOdinSword);
	state.removeVictory(VictoryKind.VYggdrasil);
	if (isHost()) {
		@sync for (currentPlayer in state.players) {
			if (!currentPlayer.isAI) {
				currentPlayer.objectives.add("summaryInfo", "To win this free-for-all brawl, you'll need to hold map center as you would normally. What's not normal, however, is how you'll get there; as a master of the sea, you'll need to send drakkars from your home base to the mainland!");
				currentPlayer.objectives.add("shipInfo", "After exploring an open beach via harbor, you can colonize up to " + maxLandingPoints + " landing points from afar and ferry your units between them. Up to " + maxUnitsPerDrakkar + " units can fit in each ship, so you'll have to send larger groups over in multiple parts!");
				currentPlayer.objectives.add("civilianInfo", "Non-[Villager] civilians prioritize their jobs over adventure, so they won't board the ships that leave from your [TownHall], though they will return from the mainland.");
				for (beach in mainlandBeachZones) {
					var transportBuildingList = [for (building in beach.buildings) if (building.kind != Building.Decal && building.kind != Building.Shoal && building.kind != Building.Stones && building.kind != Building.IronDeposit) "[" + building.kind + "]"].join(", ");
					currentPlayer.objectives.add(
						"sendTo" + beach.id,
						"You can send units from your [TownHall] to the beach with: " + transportBuildingList,
						{ visible: false },
						{ name: "Send", action: "invokeSendTo" + beach.id }
					);
					currentPlayer.objectives.add(
						"sendFrom" + beach.id,
						"You can send units back to your [TownHall] from the beach with: " + transportBuildingList,
						{ visible: false },
						{ name: "Retrieve", action: "invokeSendFrom" + beach.id }
					);
				}
				currentPlayer.objectives.add(
					"showColonizable",
					"You can view a list of the beaches available to be colonized here:",
					{ visible: false },
					{ name: "Show Me", action: "invokeSpecialColonizing" }
				);
				currentPlayer.objectives.add(
					"cancelShowColonizable",
					"You can return to the main menu without colonizing anything:",
					{ visible: false },
					{ name: "Cancel", action: "invokeCancelColonizing" }
				);
				currentPlayer.objectives.add(
					"specialColonizeInfo",
					"Or you can pay " + specialColonizeCost + " [Money]s to colonize any available beach as a landing point:",
					{ visible: false }
				);
				for (beach in mainlandBeachZones) {
					var colonizeBuildingList = [for (building in beach.buildings) if (building.kind != Building.Decal && building.kind != Building.Shoal) "[" + building.kind + "]"].join(", ");
					currentPlayer.objectives.add(
						"colonize" + beach.id,
						"Colonize the beach with: " + colonizeBuildingList,
						{ visible: false },
						{ name: "Colonize", action: "invokeSpecialColonize" + beach.id }
					);
				}
			}

			// reveal the map center at the start
			currentPlayer.discoverZone(centerZone);
		}

		// we want the starting islands to have a little more building room than usual
		@sync for (homeZone in homeZones) {
			homeZone.maxBuildings = 4;
			for (neighborZone in homeZone.next) {
				neighborZone.maxBuildings = 5;
			}
		}
	}
}


function onEachLaunch () {
	// we don't support saving and loading yet
}


// Regular update is called every 0.5s
function regularUpdate (dt : Float) {
	if (isHost()) {
		// every few seconds, we'll check if there are any mainland beaches to potentially colonize or transfer units between
		if (state.time % 3 < 0.1) {
			@sync for (playerIndex in 0 ... homeZones.length) {
				var currentPlayer = homeZones[playerIndex].owner;
				if (currentPlayer != null && !currentPlayer.isAI) {
					currentPlayer.objectives.setVisible("summaryInfo", !isSpecialColonizing[playerIndex]);
					currentPlayer.objectives.setVisible("shipInfo", !isSpecialColonizing[playerIndex]);
					currentPlayer.objectives.setVisible("civilianInfo", !isSpecialColonizing[playerIndex]);
					// we want to process the landing points first because if we lose any of them, we want the colonize options logic below to pick them up
					for (landingPoint in landingPoints[playerIndex]) {
						if (getZone(landingPoint).owner != currentPlayer) {
							landingPoints[playerIndex].remove(landingPoint);
							currentPlayer.objectives.setStatus("colonize" + landingPoint, OStatus.Empty);
							currentPlayer.objectives.setVisible("sendTo" + landingPoint, false);
							currentPlayer.objectives.setVisible("sendFrom" + landingPoint, false);
						}
						else {
							currentPlayer.objectives.setVisible("sendTo" + landingPoint, !isSpecialColonizing[playerIndex]);
							currentPlayer.objectives.setVisible("sendFrom" + landingPoint, !isSpecialColonizing[playerIndex]);
						}
					}
					// if the player hasn't maxed out their landing points yet and they've discovered any of the potential ones, give them the option to see the list
					var hasDiscoveredAny = false;
					for (beach in mainlandBeachZones) {
						if (currentPlayer.hasDiscovered(beach)) {
							hasDiscoveredAny = true;
							break;
						}
					}
					var canSpecialColonize = (
						!isSpecialColonizing[playerIndex]
						&& landingPoints[playerIndex].length < maxLandingPoints
						&& hasDiscoveredAny
					);
					currentPlayer.objectives.setVisible("showColonizable", canSpecialColonize);
					currentPlayer.objectives.setVisible("cancelShowColonizable", isSpecialColonizing[playerIndex]);
					currentPlayer.objectives.setVisible("specialColonizeInfo", isSpecialColonizing[playerIndex]);
					// we'll show all of the beaches they've discovered, but gray out any they can't colonize
					for (beach in mainlandBeachZones) {
						var isSpecialColonizable = (
							landingPoints[playerIndex].length < maxLandingPoints
							&& currentPlayer.getResource(Resource.Money) >= specialColonizeCost
							&& beach.owner == null
							&& beach.colonizeBy == null
							&& [for (unit in beach.units) if (!unit.isOwner(currentPlayer) && unit.kind != Unit.Sheep) unit].length == 0
						);
						// the Done status plays its animation every time it's set, so if it's been set we don't want to update it anymore unless we lose the zone (handled further above)
						if (currentPlayer.objectives.getStatus("colonize" + beach.id) != OStatus.Done) {
							currentPlayer.objectives.setStatus("colonize" + beach.id, isSpecialColonizable ? OStatus.Empty : OStatus.Missed);
						}
						currentPlayer.objectives.setVisible("colonize" + beach.id, isSpecialColonizing[playerIndex] && currentPlayer.hasDiscovered(beach));
					}
				}
			}
		}
	}
}


function getPlayerIndex (currentPlayer : Player) {
	for (i in 0 ... homeZones.length) {
		if (homeZones[i].owner == currentPlayer) {
			return i;
		}
	}
	return -1;
}


function invokeSpecialColonizing () { var args : Array<Dynamic> = []; args.push(me()); args.push(true); invokeHost("setColonizing", args); }
function invokeCancelColonizing () { var args : Array<Dynamic> = []; args.push(me()); args.push(false); invokeHost("setColonizing", args); }
// these need to match mainlandBeachZones...
// I DO NOT LIKE THIS, SHIRO GAMES. LET ME PASS ARGS TO THE OBJECTIVE BUTTON, OR AT LEAST LET ME DYNAMICALLY CREATE THESE CALLBACK FUNCTIONS
function invokeSpecialColonize118 () { var args : Array<Dynamic> = []; args.push(me()); args.push(118); invokeHost("specialColonize", args); }
function invokeSpecialColonize115 () { var args : Array<Dynamic> = []; args.push(me()); args.push(115); invokeHost("specialColonize", args); }
function invokeSpecialColonize104 () { var args : Array<Dynamic> = []; args.push(me()); args.push(104); invokeHost("specialColonize", args); }
function invokeSpecialColonize95 () { var args : Array<Dynamic> = []; args.push(me()); args.push(95); invokeHost("specialColonize", args); }
function invokeSpecialColonize103 () { var args : Array<Dynamic> = []; args.push(me()); args.push(103); invokeHost("specialColonize", args); }
function invokeSpecialColonize110 () { var args : Array<Dynamic> = []; args.push(me()); args.push(110); invokeHost("specialColonize", args); }
function invokeSpecialColonize123 () { var args : Array<Dynamic> = []; args.push(me()); args.push(123); invokeHost("specialColonize", args); }
function invokeSpecialColonize139 () { var args : Array<Dynamic> = []; args.push(me()); args.push(139); invokeHost("specialColonize", args); }
function invokeSpecialColonize154 () { var args : Array<Dynamic> = []; args.push(me()); args.push(154); invokeHost("specialColonize", args); }
function invokeSpecialColonize175 () { var args : Array<Dynamic> = []; args.push(me()); args.push(175); invokeHost("specialColonize", args); }
function invokeSpecialColonize193 () { var args : Array<Dynamic> = []; args.push(me()); args.push(193); invokeHost("specialColonize", args); }
function invokeSpecialColonize210 () { var args : Array<Dynamic> = []; args.push(me()); args.push(210); invokeHost("specialColonize", args); }
function invokeSpecialColonize216 () { var args : Array<Dynamic> = []; args.push(me()); args.push(216); invokeHost("specialColonize", args); }
function invokeSpecialColonize233 () { var args : Array<Dynamic> = []; args.push(me()); args.push(233); invokeHost("specialColonize", args); }
function invokeSpecialColonize221 () { var args : Array<Dynamic> = []; args.push(me()); args.push(221); invokeHost("specialColonize", args); }
function invokeSpecialColonize227 () { var args : Array<Dynamic> = []; args.push(me()); args.push(227); invokeHost("specialColonize", args); }
function invokeSpecialColonize222 () { var args : Array<Dynamic> = []; args.push(me()); args.push(222); invokeHost("specialColonize", args); }
function invokeSpecialColonize211 () { var args : Array<Dynamic> = []; args.push(me()); args.push(211); invokeHost("specialColonize", args); }
function invokeSpecialColonize195 () { var args : Array<Dynamic> = []; args.push(me()); args.push(195); invokeHost("specialColonize", args); }
function invokeSpecialColonize176 () { var args : Array<Dynamic> = []; args.push(me()); args.push(176); invokeHost("specialColonize", args); }
function invokeSpecialColonize156 () { var args : Array<Dynamic> = []; args.push(me()); args.push(156); invokeHost("specialColonize", args); }
function invokeSpecialColonize142 () { var args : Array<Dynamic> = []; args.push(me()); args.push(142); invokeHost("specialColonize", args); }
function invokeSendTo118 () { var args : Array<Dynamic> = []; args.push(me()); args.push(118); invokeHost("sendTo", args); }
function invokeSendTo115 () { var args : Array<Dynamic> = []; args.push(me()); args.push(115); invokeHost("sendTo", args); }
function invokeSendTo104 () { var args : Array<Dynamic> = []; args.push(me()); args.push(104); invokeHost("sendTo", args); }
function invokeSendTo95 () { var args : Array<Dynamic> = []; args.push(me()); args.push(95); invokeHost("sendTo", args); }
function invokeSendTo103 () { var args : Array<Dynamic> = []; args.push(me()); args.push(103); invokeHost("sendTo", args); }
function invokeSendTo110 () { var args : Array<Dynamic> = []; args.push(me()); args.push(110); invokeHost("sendTo", args); }
function invokeSendTo123 () { var args : Array<Dynamic> = []; args.push(me()); args.push(123); invokeHost("sendTo", args); }
function invokeSendTo139 () { var args : Array<Dynamic> = []; args.push(me()); args.push(139); invokeHost("sendTo", args); }
function invokeSendTo154 () { var args : Array<Dynamic> = []; args.push(me()); args.push(154); invokeHost("sendTo", args); }
function invokeSendTo175 () { var args : Array<Dynamic> = []; args.push(me()); args.push(175); invokeHost("sendTo", args); }
function invokeSendTo193 () { var args : Array<Dynamic> = []; args.push(me()); args.push(193); invokeHost("sendTo", args); }
function invokeSendTo210 () { var args : Array<Dynamic> = []; args.push(me()); args.push(210); invokeHost("sendTo", args); }
function invokeSendTo216 () { var args : Array<Dynamic> = []; args.push(me()); args.push(216); invokeHost("sendTo", args); }
function invokeSendTo233 () { var args : Array<Dynamic> = []; args.push(me()); args.push(233); invokeHost("sendTo", args); }
function invokeSendTo221 () { var args : Array<Dynamic> = []; args.push(me()); args.push(221); invokeHost("sendTo", args); }
function invokeSendTo227 () { var args : Array<Dynamic> = []; args.push(me()); args.push(227); invokeHost("sendTo", args); }
function invokeSendTo222 () { var args : Array<Dynamic> = []; args.push(me()); args.push(222); invokeHost("sendTo", args); }
function invokeSendTo211 () { var args : Array<Dynamic> = []; args.push(me()); args.push(211); invokeHost("sendTo", args); }
function invokeSendTo195 () { var args : Array<Dynamic> = []; args.push(me()); args.push(195); invokeHost("sendTo", args); }
function invokeSendTo176 () { var args : Array<Dynamic> = []; args.push(me()); args.push(176); invokeHost("sendTo", args); }
function invokeSendTo156 () { var args : Array<Dynamic> = []; args.push(me()); args.push(156); invokeHost("sendTo", args); }
function invokeSendTo142 () { var args : Array<Dynamic> = []; args.push(me()); args.push(142); invokeHost("sendTo", args); }
function invokeSendFrom118 () { var args : Array<Dynamic> = []; args.push(me()); args.push(118); invokeHost("sendFrom", args); }
function invokeSendFrom115 () { var args : Array<Dynamic> = []; args.push(me()); args.push(115); invokeHost("sendFrom", args); }
function invokeSendFrom104 () { var args : Array<Dynamic> = []; args.push(me()); args.push(104); invokeHost("sendFrom", args); }
function invokeSendFrom95 () { var args : Array<Dynamic> = []; args.push(me()); args.push(95); invokeHost("sendFrom", args); }
function invokeSendFrom103 () { var args : Array<Dynamic> = []; args.push(me()); args.push(103); invokeHost("sendFrom", args); }
function invokeSendFrom110 () { var args : Array<Dynamic> = []; args.push(me()); args.push(110); invokeHost("sendFrom", args); }
function invokeSendFrom123 () { var args : Array<Dynamic> = []; args.push(me()); args.push(123); invokeHost("sendFrom", args); }
function invokeSendFrom139 () { var args : Array<Dynamic> = []; args.push(me()); args.push(139); invokeHost("sendFrom", args); }
function invokeSendFrom154 () { var args : Array<Dynamic> = []; args.push(me()); args.push(154); invokeHost("sendFrom", args); }
function invokeSendFrom175 () { var args : Array<Dynamic> = []; args.push(me()); args.push(175); invokeHost("sendFrom", args); }
function invokeSendFrom193 () { var args : Array<Dynamic> = []; args.push(me()); args.push(193); invokeHost("sendFrom", args); }
function invokeSendFrom210 () { var args : Array<Dynamic> = []; args.push(me()); args.push(210); invokeHost("sendFrom", args); }
function invokeSendFrom216 () { var args : Array<Dynamic> = []; args.push(me()); args.push(216); invokeHost("sendFrom", args); }
function invokeSendFrom233 () { var args : Array<Dynamic> = []; args.push(me()); args.push(233); invokeHost("sendFrom", args); }
function invokeSendFrom221 () { var args : Array<Dynamic> = []; args.push(me()); args.push(221); invokeHost("sendFrom", args); }
function invokeSendFrom227 () { var args : Array<Dynamic> = []; args.push(me()); args.push(227); invokeHost("sendFrom", args); }
function invokeSendFrom222 () { var args : Array<Dynamic> = []; args.push(me()); args.push(222); invokeHost("sendFrom", args); }
function invokeSendFrom211 () { var args : Array<Dynamic> = []; args.push(me()); args.push(211); invokeHost("sendFrom", args); }
function invokeSendFrom195 () { var args : Array<Dynamic> = []; args.push(me()); args.push(195); invokeHost("sendFrom", args); }
function invokeSendFrom176 () { var args : Array<Dynamic> = []; args.push(me()); args.push(176); invokeHost("sendFrom", args); }
function invokeSendFrom156 () { var args : Array<Dynamic> = []; args.push(me()); args.push(156); invokeHost("sendFrom", args); }
function invokeSendFrom142 () { var args : Array<Dynamic> = []; args.push(me()); args.push(142); invokeHost("sendFrom", args); }


function setColonizing (currentPlayer : Player, value : Bool) {
	var playerIndex = getPlayerIndex(currentPlayer);
	isSpecialColonizing[playerIndex] = value;
}


function specialColonize (currentPlayer : Player, zoneId : Int) {
	var playerIndex = getPlayerIndex(currentPlayer);
	var beach = getZone(zoneId);
	currentPlayer.addResource(Resource.Money, -specialColonizeCost);
	currentPlayer.takeControl(beach);
	currentPlayer.objectives.setStatus("colonize" + zoneId, OStatus.Done);
	landingPoints[playerIndex].push(zoneId);
	isSpecialColonizing[playerIndex] = false;
}


function sendTo (currentPlayer : Player, zoneId : Int) {
	var playerIndex = getPlayerIndex(currentPlayer);
	sendUnits(currentPlayer, homeZones[playerIndex].id, zoneId, false);
}


function sendFrom (currentPlayer : Player, zoneId : Int) {
	var playerIndex = getPlayerIndex(currentPlayer);
	sendUnits(currentPlayer, zoneId, homeZones[playerIndex].id, true);
}


// I wish we could use actual drakkar here, but they need to be given very specific src/dst zones or they won't appear at all and no units will spawn,
// and with so many possible src/dst combinations of every town hall and every mainland beach, that's not feasible here, so we'll just teleport them over
// we could just figure out one sea zone src for each beach zone dst, but we'd still have the issue of drakkar spawning new units instead of moving existing ones
function sendUnits (currentPlayer : Player, srcZoneId : Int, dstZoneId : Int, includeProducers : Bool) {
	var drakkarIndices = [];
	var zoneUnits = getZone(srcZoneId).units;
	var targetZone = getZone(dstZoneId);
	// we have to loop twice, once to get the indices and again to pull out the units in reverse, since the list of units in the zone will be updated as we go
	for (unitIndex in 0 ... zoneUnits.length) {
		var unit = zoneUnits[unitIndex];
		if (
			(unit.owner == currentPlayer)
			&& (includeProducers
				? (unit.kind != Unit.Sailor) // when bringing units back, we'll take everyone besides sailors
				: (unit.kind == Unit.Villager || unit.isMilitary) // when sending units over, we'll only send actual villagers or military
			)
		) {
			drakkarIndices.push(unitIndex);
		}
		// the game crashes if we try to send too many units at once
		if (drakkarIndices.length >= maxUnitsPerDrakkar) {
			break;
		}
	}
	drakkarIndices.reverse();
	for (unitIndex in drakkarIndices) {
		var unit = zoneUnits[unitIndex];
		// if we don't set the unit's zone, even if we update its position, it'll try to walk back to its previous zone
		unit.zone = targetZone;
		unit.setPosition(targetZone.x + (15 - randomInt(31)), targetZone.y + (15 - randomInt(31)));
		// interrupting their current job will make them immediately try to find something to do in their new zone, even if it's the same job
		unit.stopJob();
	}
}
