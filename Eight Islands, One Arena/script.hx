// list the zone IDs for each island's harbor and its corresponding central arena landing point
var harborZoneIDs = [126, 97, 131, 158, 203, 239, 206, 150];
var arenaZoneIDs = [153, 152, 152, 162, 162, 176, 176, 153];

function saveState () {
}


function init () {
	if (state.time == 0) {
		onFirstLaunch();
	}
	onEachLaunch();
}


function onFirstLaunch () {
	// remove all existing victory conditions and set our custom objective
	state.removeVictory(VictoryKind.VMilitary);
	state.removeVictory(VictoryKind.VFame);
	state.removeVictory(VictoryKind.VMoney);
	state.removeVictory(VictoryKind.VLore);
	state.removeVictory(VictoryKind.VHelheim);
	state.removeVictory(VictoryKind.VOdinSword);
	state.removeVictory(VictoryKind.VYggdrasil);
	// it sure would be nice if we could set this up as a custom VictoryKind, so the victory overview screen would still work
	// and we wouldn't need to do the progress checking/setting ourselves down there in regularUpdate
	state.objectives.add("islandinfo", "Welcome to the islands! You can send military units into the arena by moving them to your harbor zone, but it's a one-way trip!");
	state.objectives.add("feastinfo", "Eldhrumnir will let you keep your units healthy as long as you can feast, and you'll gain a free feast for every 200 military experience earned.");
	state.objectives.add("militaryxp", "To win this competition, be the first to acquire ::value:: [MilitaryXP]!", {
		visible: true,
		showProgressBar: true,
		showOtherPlayers: true,
		goalVal: 5000,
		autoCheck: true
	});

	// reveal the whole map for everyone
	for (currentPlayer in state.players) {
		currentPlayer.discoverAll();
	}

	// disallow building on the harbor/arena zones
	for (zoneID in harborZoneIDs.concat(arenaZoneIDs)) {
		getZone(zoneID).maxBuildings = 0;
	}
}


function onEachLaunch () {
	// we don't want to do anything here, since I don't think saving and loading works properly yet
}


// Regular update is called every 0.5s
function regularUpdate (dt : Float) {
	// update the players' progress towards our custom objective
	state.objectives.setCurrentVal("militaryxp", player.getResource(Resource.MilitaryXP));
	for (otherPlayer in state.players) {
		state.objectives.setOtherPlayerVal("militaryxp", otherPlayer, otherPlayer.getResource(Resource.MilitaryXP));
	}

	// trigger a custom victory/defeat if any player has completed our custom objective
	for (currentPlayer in state.players) {
		if (currentPlayer.getResource(Resource.MilitaryXP) >= state.objectives.getGoalVal("militaryxp")) {
			if (currentPlayer == player) {
				player.customVictory("Congratulations! You've won the competition.", "Oh no! You've lost the competition.");
			}
			else {
				customDefeat("Oh no! You've lost the competition.");
			}
		}
	}

	// send any military units at the harbors to the arena via drakkars
	for (harborZoneID in harborZoneIDs) {
		var harborZone = getZone(harborZoneID);
		var drakkarList = [];
		for (unit in harborZone.units) {
			if (unit.isMilitary) {
				drakkarList.push({ kind: unit.kind, hitLife: unit.hitLife });
				unit.die(true, false);
			}
		}
		if (drakkarList.length > 0) {
			var matchIndex = harborZoneIDs.indexOf(harborZoneID);
			var arenaZone = getZone(arenaZoneIDs[matchIndex]);
			// drakkar(harborZone.owner, harborZone, arenaZone, 0, 0, drakkarList.map(function (unit) { return unit.kind; }));
			// TODO: since drakkar() doesn't seem to actually work, we'll just use zone.addUnit(), but hopefully it gets fixed soon
			for (unit in drakkarList) {
				arenaZone.addUnit(unit.kind, 1, harborZone.owner);
			}
			// we can only spawn unitKind, not the unit itself, so after they land, modify their health accordingly
			// this wouldn't be so indented if Array.filter actually worked...
			for (zoneUnit in arenaZone.units) {
				if ((zoneUnit.owner == harborZone.owner) && (zoneUnit.hitLife == 0)) {
					for (drakkarUnit in drakkarList) {
						if (drakkarUnit.hitLife > 0) {
							if (zoneUnit.kind == drakkarUnit.kind) {
								zoneUnit.hitLife = drakkarUnit.hitLife;
								drakkarList.remove(drakkarUnit);
							}
						}
						else {
							drakkarList.remove(drakkarUnit);
						}
					}
				}
			}
		}
	}

	// TODO: grant each player a free feast each time they earn another 200 military xp
}