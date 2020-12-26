// zone lists for each island's town hall, harbor, and drakkar launching/landing points
var homeZones = [for(i in [99, 42, 30, 77, 199, 246, 287, 216]) getZone(i)];
var harborZones = [for(i in [114, 85, 73, 118, 169, 214, 241, 185]) getZone(i)];
var seaZones = [for(i in [146, 115, 122, 141, 177, 194, 186, 166]) getZone(i)];
var arenaZones = [for(i in [136, 128, 143, 145, 167, 179, 168, 153]) getZone(i)];
// keep track of how many free feasts we've given each player as a reward for their military experience
var grantedFeasts = [0, 0, 0, 0, 0, 0, 0, 0];
// and we want our own player array, since state.players doesn't always maintain the same order regardless of which clan the host picks
var players = [for(z in homeZones) z.owner];


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
		for (currentPlayer in players) {
			currentPlayer.objectives.add("islandinfo", "Welcome to the islands! You can send your military units into the arena by moving them to your harbor zone and clicking this button. It's a one-way trip, but at least it comes with a full heal! To prevent the game from crashing, each click will only send up to 20 units, but feel free to double- or triple-click as necessary.", {}, {
				name: "Send a Drakkar",
				action: "invokeDrakkar"
			});
			currentPlayer.objectives.add("feastinfo", "Eldhrumnir is both free to forge and your only available relic; it will keep your units healthy as long as you can feast, and you'll gain a free feast for every 250 military experience earned. You'll also (invisibly) gain the Recruitment lore at 1000 military experience, so get in there!");
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

	// disallow building on the harbor zones
	for (zone in harborZones) {
		zone.maxBuildings = 0;
	}
}


function onEachLaunch () {
	// we don't support saving and loading yet
}


// Regular update is called every 0.5s
function regularUpdate (dt : Float) {
	if (isHost()) {
		var playerIndex = 0;
		for (currentPlayer in players) {
			// update each player's progress towards our custom objective
			@sync for (otherPlayer in players) {
				if (otherPlayer == currentPlayer) {
					currentPlayer.objectives.setCurrentVal("militaryxp", currentPlayer.getResource(Resource.MilitaryXP));
				}
				else {
					otherPlayer.objectives.setOtherPlayerVal("militaryxp", currentPlayer, currentPlayer.getResource(Resource.MilitaryXP));
				}
			}

			// trigger a custom victory/defeat if any player has completed our custom objective
			if (currentPlayer.getResource(Resource.MilitaryXP) >= currentPlayer.objectives.getGoalVal("militaryxp")) {
				currentPlayer.customVictory("Congratulations! You've won the competition.", "Oh no! You've lost the competition.");
			}

			// grant each player a free feast each time they earn another 250 military xp
			var feastsOwed = toInt(currentPlayer.getResource(Resource.MilitaryXP) / 250);
			var feastsGiven = grantedFeasts[playerIndex];
			while (feastsOwed > feastsGiven) {
				++currentPlayer.freeFeast;
				++grantedFeasts[playerIndex];
				feastsGiven = grantedFeasts[playerIndex];
			}
			// as well as the recruitment lore if they've reached 1000
			if (!currentPlayer.hasTech(Tech.Recruit) && currentPlayer.getResource(Resource.MilitaryXP) >= 1000) {
				currentPlayer.unlockTech(Tech.Recruit, true);
			}

			++playerIndex;
		}
	}
}


function getPlayerIndex (player : Player) {
	// this function will let us get the index into our global arrays that matches the given player objects
	var playerIndex = -1;
	var homeIndex = -1;
	for (currentPlayer in players) {
		++homeIndex;
		if (currentPlayer == player) {
			playerIndex = homeIndex;
			break;
		}
	}
	return playerIndex;
}


function invokeDrakkar () {
	// the drakkar() function is host-only, so we need to use invokeHost
	var args : Array<Dynamic> = [];
	args.push(getPlayerIndex(me()));
	invokeHost("sendDrakkar", args);
}


function sendDrakkar (playerIndex : Int) {
	if (playerIndex != -1) {
		// if we have a valid player, we can send any military units at their harbor to the arena via drakkar
		var harborZone = harborZones[playerIndex];
		if (harborZone.owner != null) {
			// we end up having to pull the indices out and iterate a second time (in reverse) so we don't modify the array while iterating over it
			var unitIndex = 0;
			var validIndices = [];
			var drakkarList = [];
			for (unit in harborZone.units) {
				if (unit.owner == harborZone.owner && unit.isMilitary && unit.kind != Unit.Militia) {
					validIndices.push(unitIndex);
				}
				// the game crashes if we try to send too many units at once, regardless of how we try to split them among the boats
				if (unitIndex >= 20) {
					break;
				}
				++unitIndex;
			}
			validIndices.reverse();
			for (index in validIndices) {
				var unit = harborZone.units[index];
				drakkarList.push(unit.kind);
				unit.die(true, false);
			}
			if (drakkarList.length > 0) {
				var arenaZone = arenaZones[playerIndex];
				var seaZone = seaZones[playerIndex];
				// batch the drakkar list into groups of 5 and send each group on their own ship
				var drakkarGroups = [];
				var drakkarGroup = [];
				var counter = 0;
				for (unit in drakkarList) {
					if (counter < 5) {
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