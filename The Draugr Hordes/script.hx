var humanPlayers = [for (currentPlayer in state.players) if (!currentPlayer.isAI) currentPlayer];
var heroesNeeded = humanPlayers.length * 2;
var centerZone = getZone(161);
var homeZones = [for(i in [85, 106, 110, 221, 227, 219, 169, 176]) getZone(i)];
var waveUnitTypes = [Unit.Death, Unit.Valkyrie, Unit.UndeadGiant];
var waveContents = [ // number of each unit type to send in each wave
	[2, 0, 0],
	[4, 0, 0],
	[4, 1, 0],
	[4, 2, 0],
	[3, 2, 1],
	[3, 3, 1],
	[2, 3, 2],
	[2, 4, 2],
	[1, 4, 3],
	[1, 5, 3],
	[0, 5, 4]
];
var waveUnits = [[], [], [], [], [], [], [], []];
var maxWaves = waveContents.length;
var currentWave = 0;
var wavePlayerIndex = 0;
var waveSpawnTicker = 0;
var waveSpawnDelay = 2;
var wavesOver = false;
var waveActive = false;
var sendingWave = false;
var waveOffset = 270;
var waveCooldown = 360;
var warningDelay = 120;
var wavesToBuff = 2;
var buffedWaves = [];
var buffMultiplier = 1.5;


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
	// remove all existing victory conditions and set our custom objectives
	state.removeVictory(VictoryKind.VMilitary);
	state.removeVictory(VictoryKind.VFame);
	state.removeVictory(VictoryKind.VMoney);
	state.removeVictory(VictoryKind.VLore);
	state.removeVictory(VictoryKind.VHelheim);
	state.removeVictory(VictoryKind.VOdinSword);
	state.removeVictory(VictoryKind.VYggdrasil);
	if (isHost()) {
		@sync for (currentPlayer in state.players) {
			currentPlayer.objectives.add("survivewaves", "The [Helheim] is more active than ever! You must all brace yourselves and survive ::value:: waves of attacks from the vile undead!", {
				visible: true,
				showProgressBar: true,
				val: currentWave,
				goalVal: maxWaves,
				autoCheck: true
			});
			currentPlayer.objectives.add("closegate", "Now's our chance to close the gates once and for all! Every (non-AI) [Maiden] and [BearMaiden] should get there at once!", {
				visible: false,
				showProgressBar: true,
				val: 0,
				goalVal: heroesNeeded,
				autoCheck: true
			});

			// reveal the map center, but don't let anyone colonize it
			currentPlayer.discoverZone(centerZone);
			currentPlayer.allowColonize(centerZone, false);
		}

		// disable the normal random events
		noEvent();
	}
}


function onEachLaunch () {
	// we don't support saving and loading yet
}


// Regular update is called every 0.5s
function regularUpdate (dt : Float) {
	if (isHost()) {
		if (!wavesOver) {
			// warn about the next invasion shortly after sending the previous one (or starting the game)
			if ((toInt(state.time) - waveOffset) % waveCooldown == warningDelay) {
				state.events.setEvent(Event.HelheimInvasionStart, ((waveCooldown - warningDelay) / 60));
			}

			// if the time is right, send a wave
			if (!waveActive && (toInt(state.time) - waveOffset) % waveCooldown == 0 && toInt(state.time) > waveOffset) {
				sendingWave = true;
				waveActive = true;
				++currentWave;
				wavePlayerIndex = 0;
				waveSpawnTicker = 0;
				buffedWaves = [for(i in 0...wavesToBuff) randomInt(homeZones.length)];
			}
			// since the game crashes if we spawn too many units too quickly, we'll do one clan every few updates
			if (sendingWave) {
				if (waveSpawnTicker % waveSpawnDelay == 0) {
					var currentWaveContents = waveContents[currentWave - 1];
					var currentPlayer = homeZones[wavePlayerIndex].owner;
					var waveBuffed = arrayContains(buffedWaves, wavePlayerIndex);
					var unitIndex = 0;
					for (unitType in waveUnitTypes) {
						var unitCount = currentWaveContents[unitIndex];
						if (waveBuffed) {
							unitCount = toInt(unitCount * buffMultiplier);
						}
						if (unitCount > 0) {
							var newUnits = centerZone.addUnit(unitType, unitCount, null, false);
							waveUnits[wavePlayerIndex] = waveUnits[wavePlayerIndex].concat(newUnits);
						}
						++unitIndex;
					}
					launchAttackPlayer(waveUnits[wavePlayerIndex], currentPlayer);
					var message = "The undead are coming" + (waveBuffed ? ", and there appear to be more than usual!" : "!");
					currentPlayer.genericNotify(message, waveUnits[wavePlayerIndex][0]);
					++wavePlayerIndex;
					if (wavePlayerIndex >= homeZones.length) {
						sendingWave = false;
					}
				}
				++waveSpawnTicker;
			}

			// every so often, re-send the attack order in case any units decolonize a tile and decide to chill there
			if (waveActive && randomInt(10) == 0) {
				var playerIndex = 0;
				for (homeZone in homeZones) {
					if (waveUnits[playerIndex].length > 0) {
						launchAttackPlayer(waveUnits[playerIndex], homeZone.owner);
					}
					++playerIndex;
				}
			}

			// remove killed foes from our tracked list
			waveUnits = [for(waveUnitGroup in waveUnits) [for(waveUnit in waveUnitGroup) if (waveUnit.life > 0) waveUnit]];

			// if the waves were all cleared, update the objective progress
			var waveCleared = true;
			for (waveUnitGroup in waveUnits) {
				if (waveUnitGroup.length > 0) {
					waveCleared = false;
					break;
				}
			}
			if (waveActive && waveCleared) {
				waveActive = false;
				@sync for (currentPlayer in state.players) {
					currentPlayer.objectives.setCurrentVal("survivewaves", currentWave);
				}
			}

			// if the players have survived all of the waves, show them the next objective
			if (!waveActive && currentWave == maxWaves) {
				wavesOver = true;
				@sync for (currentPlayer in state.players) {
					currentPlayer.objectives.setVisible("closegate", true);
				}
				// TODO: maybe iterate through clans until we find a living warchief and have them do a cutscene?
			}
		}
		else {
			// if the waves are over, check how many hero units we have at the gate
			var heroes = [for (unit in centerZone.units) if (unit.kind == Unit.Maiden || unit.kind == Unit.Maiden02 || unit.kind == Unit.BearMaiden) unit];
			var playerHeroes = [for (unit in heroes) if (arrayContains(humanPlayers, unit.owner)) unit];
			@sync for (currentPlayer in state.players) {
				currentPlayer.objectives.setCurrentVal("closegate", playerHeroes.length);
			}

			// if we have all of the non-AI heroes here, trigger the victory!
			if (playerHeroes.length >= heroesNeeded) {
				player.customVictory("Congratulations! The gates have been sealed for good!", "If you can see this message, something is wrong with the team setup!");
				// TODO: maybe iterate through clans until we find a living warchief and have them do a cutscene?
			}
		}

		// if any clan has been defeated, they all lose
		if (state.players.length < state.startPlayers.length) {
			@sync for (currentPlayer in state.startPlayers) {
				currentPlayer.customDefeat("A member of the alliance has fallen to the horde!"); // "I understood that reference."
			}
		}
	}
}


function arrayContains(array : Dynamic, value : Dynamic) : Bool {
	var contains = false;
	for (item in array) {
		if (item == value) {
			contains = true;
			break;
		}
	}
	return contains;
}
