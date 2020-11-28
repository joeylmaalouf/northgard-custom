// list the zone IDs for each island's town hall, harbor, and drakkar launching/landing points
var homeZoneIDs = [80, 40, 83, 156, 244, 287, 247, 171];
var harborZoneIDs = [126, 97, 131, 158, 203, 220, 206, 150];
var seaZoneIDs = [124, 115, 117, 157, 177, 185, 188, 137];
var arenaZoneIDs = [153, 152, 152, 162, 162, 176, 176, 153];
// keep track of how many free feasts we've given each player as a reward for their military experience
var grantedFeasts = [0, 0, 0, 0, 0, 0, 0, 0];


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
	// remove all existing victory conditions and set our custom objective
	// it sure would be nice if we could set this up as a custom VictoryKind, so the victory overview screen would still work
	// and we wouldn't need to do the progress checking/setting ourselves down there in regularUpdate
	state.removeVictory(VictoryKind.VMilitary);
	state.removeVictory(VictoryKind.VFame);
	state.removeVictory(VictoryKind.VMoney);
	state.removeVictory(VictoryKind.VLore);
	state.removeVictory(VictoryKind.VHelheim);
	state.removeVictory(VictoryKind.VOdinSword);
	state.removeVictory(VictoryKind.VYggdrasil);
	if (isHost()) {
		for (currentPlayer in state.players) {
			currentPlayer.objectives.add("islandinfo", "Welcome to the islands! You can send military units into the arena by moving them to your harbor zone and clicking this button. It's a one-way trip, but at least it comes with a full heal!", {}, {
				name: "Send a Drakkar",
				action: "invokeDrakkar"
			});
			currentPlayer.objectives.add("feastinfo", "Eldhrumnir will let you keep your units healthy as long as you can feast, and you'll gain a free feast for every 200 military experience earned.");
			currentPlayer.objectives.add("militaryxp", "To win this competition, be the first to acquire ::value:: [MilitaryXP]!", {
				visible: true,
				showProgressBar: true,
				showOtherPlayers: true,
				goalVal: 4000,
				autoCheck: true
			});

			// reveal the whole map
			currentPlayer.discoverAll();
		}
	}

	// disallow building on the harbor/arena zones
	for (zoneID in harborZoneIDs.concat(arenaZoneIDs)) {
		getZone(zoneID).maxBuildings = 0;
	}
}


function onEachLaunch () {
	// we don't support saving and loading yet
}


// Regular update is called every 0.5s
function regularUpdate (dt : Float) {
	if (isHost()) {
		var playerIndex = 0;
		for (homeZoneID in homeZoneIDs) { // unlike state.players, this order will always remain the same, regardless of which clan the host picks
			var currentPlayer = getZone(homeZoneID).owner;

			// update each player's progress towards our custom objective
			@sync {
				for (otherPlayer in state.players) {
					if (currentPlayer == otherPlayer) {
						otherPlayer.objectives.setCurrentVal("militaryxp", currentPlayer.getResource(Resource.MilitaryXP));
					}
					else {
						otherPlayer.objectives.setOtherPlayerVal("militaryxp", currentPlayer, currentPlayer.getResource(Resource.MilitaryXP));
					}
				}
			}
			// TODO: fix non-host players seeing themselves duplicated over the host in xp objective list

			// trigger a custom victory/defeat if any player has completed our custom objective
			if (currentPlayer.getResource(Resource.MilitaryXP) >= currentPlayer.objectives.getGoalVal("militaryxp")) {
				currentPlayer.customVictory("Congratulations! You've won the competition.", "Oh no! You've lost the competition.");
			}

			// grant each player a free feast each time they earn another 200 military xp
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
}


function getPlayerIndex (player : Player) {
	// this function will let us get the index into our global arrays that matches the given player objects
	var playerIndex = -1;
	var homeIndex = -1;
	for (homeZoneID in homeZoneIDs) {
		++homeIndex;
		if (getZone(homeZoneID).owner == player) {
			playerIndex = homeIndex;
			break;
		}
	}
	return playerIndex;
}


function invokeDrakkar () {
	// the drakkar() function is host-only, so we need to use invokeHost
	var args : Array<Dynamic> = [];
	args.push(getPlayerIndex(player));
	invokeHost("sendDrakkar", args);
}


function sendDrakkar (playerIndex : Int) {
	if (playerIndex != -1) {
		// if we have a valid player, we can send any military units at their harbor to the arena via drakkar
		var harborZone = getZone(harborZoneIDs[playerIndex]);
		if (harborZone.owner != null) {
			// we end up having to pull the indices out and iterate a second time (in reverse) so we don't modify the array while iterating over it
			var unitIndex = -1;
			var validIndices = [];
			var drakkarList = [];
			for (unit in harborZone.units) {
				++unitIndex;
				if (unit.owner == harborZone.owner && unit.isMilitary && unit.kind != Unit.Militia) {
					validIndices.push(unitIndex);
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
				// batch the drakkar list into groups of 4 and send each group on their own ship
				var drakkarGroups = [];
				var drakkarGroup = [];
				var counter = 0;
				for (unit in drakkarList) {
					if (counter <= 3) {
						drakkarGroup.push(unit);
						++counter;
					}
					else {
						drakkarGroups.push(drakkarGroup);
						drakkarGroup = [unit];
						counter = 1;
					}
				}
				drakkarGroups.push(drakkarGroup);
				for (drakkarGroup in drakkarGroups) {
					drakkar(harborZone.owner, arenaZone, seaZone, 0, 0, drakkarGroup, 0.1);
				}
			}
		}
	}
}