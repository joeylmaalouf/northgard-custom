var humanPlayers = [for (currentPlayer in state.players) if (!currentPlayer.isAI) currentPlayer];
var centerZone = getZone(161);
var homeZones = [for (i in [85, 106, 119, 221, 227, 219, 169, 176]) getZone(i)];
var wavePaths = [
	[142, 128, 117, 105, 85],
	[145, 133, 125, 112, 106],
	[150, 138, 122, 131, 119],
	[166, 171, 193, 213, 221],
	[173, 194, 204, 209, 227],
	[173, 187, 192, 208, 219],
	[166, 158, 170, 159, 169],
	[164, 155, 146, 168, 176]
];
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
var inCutscene = false;


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
			// I'd like to say "[Maiden]" instead of "warchief", but for some reason it shifts the objective window over a lot
			currentPlayer.objectives.add("closegate", "Now's your chance to close the gates once and for all! Every (non-AI) warchief should head there at once and clear the zone of foes!", {
				visible: false
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
	if (isHost() && !inCutscene) {
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
				// we aren't ensuring that the players chosen to get buffed waves are human or unique, we'll let them get lucky
				buffedWaves = [for (i in 0...wavesToBuff) randomInt(homeZones.length)];
			}
			// since the game crashes if we spawn too many units too quickly, we'll do one clan every few updates
			if (sendingWave) {
				if (waveSpawnTicker % waveSpawnDelay == 0) {
					var currentWaveContents = waveContents[currentWave - 1];
					var currentPlayer = homeZones[wavePlayerIndex].owner;
					if (!currentPlayer.isAI) { // we don't actually want to send waves to the AI, they'd lose too quickly
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
						launchAttack(waveUnits[wavePlayerIndex], wavePaths[wavePlayerIndex], false);
						var message = "The undead are coming" + (waveBuffed ? ", and there appear to be more than usual!" : "!");
						currentPlayer.genericNotify(message, waveUnits[wavePlayerIndex][0]); // TODO: figure out why the alerts don't always show up?
					}
					++wavePlayerIndex;
					if (wavePlayerIndex >= homeZones.length) {
						sendingWave = false;
					}
				}
				++waveSpawnTicker;
			}

			// every so often, re-send the attack order in case any units decolonize a tile and decide to chill there
			// ideally we do this not on a timer but on a decolonization event, but idk if that's possible
			if (waveActive && toInt(state.time) % 15 == 0) {
				var playerIndex = 0;
				for (homeZone in homeZones) {
					if (waveUnits[playerIndex].length > 0) {
						var targetIndex = wavePaths[playerIndex].length;
						var validTarget = false;
						while (!validTarget && targetIndex > 0) {
							--targetIndex;
							validTarget = launchAttack(waveUnits[playerIndex], [wavePaths[playerIndex][targetIndex]], false);
						}
					}
					++playerIndex;
				}
			}

			// remove killed foes from our tracked list
			waveUnits = [for (waveUnitGroup in waveUnits) [for (waveUnit in waveUnitGroup) if (waveUnit.life > 0) waveUnit]];

			// if the waves were all cleared, update the objective progress
			if (!sendingWave) {
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
			}

			// if the players have survived all of the waves, show them the next objective
			// and if any warchiefs are alive, we'll have one of them star in a cutscene
			if (!waveActive && currentWave == maxWaves) {
				wavesOver = true;
				var warchief;
				@sync for (zone in state.zones) {
					for (unit in zone.units) {
						if (unit.kind == Unit.Maiden || unit.kind == Unit.Maiden02) {
							warchief = unit;
							break;
						}
					}
					if (warchief != null) {
						break;
					}
				}
				if (warchief != null) {
					var args : Array<Dynamic> = [];
					args.push(warchief);
					invokeAll("playInspireCutscene", args);
				}
				@sync for (currentPlayer in state.players) {
					currentPlayer.objectives.setVisible("closegate", true);
				}
				killFoes([
					{z: centerZone.id, u: Unit.Death, nb: 100},
					{z: centerZone.id, u: Unit.Valkyrie, nb: 100},
					{z: centerZone.id, u: Unit.UndeadGiant, nb: 100}
				]);
				centerZone.addUnit(Unit.Valkyrie, humanPlayers.length * 3, null, false);
			}
		}
		else {
			// if we have no foes and all of the non-AI warchiefs here, trigger the victory scene!
			var foes = [for (unit in centerZone.units) if (unit.isFoe) unit];
			var warchiefs = [for (unit in centerZone.units) if (unit.kind == Unit.Maiden || unit.kind == Unit.Maiden02) unit];
			var playerWarchiefs = [for (unit in warchiefs) if (!unit.owner.isAI) unit];
			if (foes.length == 0 && playerWarchiefs.length >= humanPlayers.length) {
				invokeAll("playFinishCutscene", []);
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


function playInspireCutscene (warchief : Unit) {
	inCutscene = true;
	setPause(true);
	followUnit(warchief);
	wait(1);
	@async playAnim(warchief, "aye", false);
	talk("The gates have been exhausted! We should take this chance to close them once and for all!", {
		who: Banner.BannerBear,
		textSize: FontKind.Title,
	}, warchief, 5);
	wait(1);
	followUnit(null);
	moveCamera({x: 472, y: 455});
	wait(1);
	setPause(false);
	inCutscene = false;
}


function playFinishCutscene () {
	inCutscene = true;
	setPause(true);
	moveCamera({x: 472, y: 455});
	var centerPositions = [
		[469, 440],
		[459, 450],
		[480, 446],
		[467, 467],
		[475, 469],
		[486, 463],
		[457, 456],
		[488, 454]
	];
	var playerIndex = 0;
	var warchiefs = [];
	for (homeZone in homeZones) {
		var warchief = summonWarchief(homeZone.owner, centerZone, centerPositions[playerIndex][0], centerPositions[playerIndex][1]);
		warchief.setControlable(false);
		warchief.canPatrol = false;
		warchief.orientToPosSmooth(472, 455, 30);
		warchiefs.push(warchief);
		++playerIndex;
	}
	wait(1);
	@async for (warchief in warchiefs) {
		playAnim(warchief, "victory", false);
	};
	wait(2);
	shakeCamera();
	// TODO: select center building and deactivate it to make it stop glowing? can make it global and orient/move camera to it instead of (472, 455)
	wait(1);
	setPause(false);
	inCutscene = false;
	player.customVictory("Congratulations! The gates have been sealed for good!", "If you can see this message, something is wrong with the team setup!");
}


function arrayContains (array : Dynamic, value : Dynamic) : Bool {
	var contains = false;
	for (item in array) {
		if (item == value) {
			contains = true;
			break;
		}
	}
	return contains;
}
