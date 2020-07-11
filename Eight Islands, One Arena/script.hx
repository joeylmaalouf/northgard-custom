// list the zone IDs for each island's harbor and its corresponding drakkar launching and landing points
var harborZoneIDs = [126, 97, 131, 158, 203, 220, 206, 150];
var seaZoneIDs = [124, 115, 117, 157, 177, 185, 188, 137];
var arenaZoneIDs = [153, 152, 152, 162, 162, 176, 176, 153];
// keep track of how many free feasts we've given each player based on their military experience
var grantedFeasts = [0, 0, 0, 0, 0, 0, 0, 0];


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
	state.objectives.add("islandinfo", "Welcome to the islands! You can send military units into the arena by moving them to your harbor zone and clicking this button. It's a one-way trip, but at least it comes with a full heal!", {}, {
		name: "Send a Drakkar",
		action: "sendDrakkar"
	});
	state.objectives.add("feastinfo", "Eldhrumnir will let you keep your units healthy as long as you can feast, and you'll gain a free feast for every 200 military experience earned.");
	state.objectives.add("militaryxp", "To win this competition, be the first to acquire ::value:: [MilitaryXP]!", {
		visible: true,
		showProgressBar: true,
		showOtherPlayers: true,
		goalVal: 4000,
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
	// TODO: fix issue of military xp display not updating for anyone but host (use me() to get local player)

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

	// grant each player a free feast each time they earn another 200 military xp
	var playerIndex = 0;
	for (currentPlayer in state.players) {
		var feastsOwed = toInt(currentPlayer.getResource(Resource.MilitaryXP) / 200);
		var feastsGiven = grantedFeasts[playerIndex];
		while (feastsOwed > feastsGiven) {
			++currentPlayer.freeFeast;
			++grantedFeasts[playerIndex];
			feastsGiven = grantedFeasts[playerIndex];
		}
		++playerIndex;
	}
}


function sendDrakkar () {
	// first we need to find the right playerIndex based on which harborZone is in their owned zones
	var playerIndex = -1;
	var found = false;
	for (ownedZone in me().zones) {
		if (!found) {
			playerIndex = -1;
			for (harborZoneID in harborZoneIDs) {
				++playerIndex;
				if (ownedZone.id == harborZoneID) {
					found = true; // since I can't double-break, this gets us out of the outer loop
					break;
				}
			}
		}
	}

	if (playerIndex != -1) {
		// now we can send any military units at the harbors to the arena via drakkar
		var harborZone = getZone(harborZoneIDs[playerIndex]);
		if (harborZone.owner != null) {
			// we end up having to pull the indices out and iterate a second time (in reverse) so we don't modify the array while iterating over it
			var currentIndex = -1;
			var validIndices = [];
			var drakkarList = [];
			for (unit in harborZone.units) {
				++currentIndex;
				if (unit.isMilitary && unit.owner == harborZone.owner) {
					validIndices.push(currentIndex);
				}
			}
			validIndices.reverse();
			for (index in validIndices) {
				var unit = harborZone.units[index];
				drakkarList.push(unit.kind);
				unit.die(true, false);
			}
			if (drakkarList.length > 0) {
				var arenaZone = getZone(arenaZoneIDs[playerIndex]);
				var seaZone = getZone(seaZoneIDs[playerIndex]);
				drakkar(harborZone.owner, arenaZone, seaZone, 0, 0, drakkarList, 0.15);
			}
		}
	}
}
