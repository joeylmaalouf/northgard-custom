var centerZone = getZone(161);
var homeZones = [for(i in [85, 106, 110, 221, 227, 219, 169, 176]) getZone(i)];
var maxWaves = 12;
var currentWave = 0;
var waveOffset = 270;
var waveCooldown = 360;
var warningDelay = 120;
var waveActive = false;
var waveUnits = [[], [], [], [], [], [], [], []];
var waveUnitTypes = [Unit.Death, Unit.Valkyrie, Unit.UndeadGiant];
var waveContents = [ // number of each unit type to send in each wave
	[2, 0, 0],
	[3, 0, 0],
	[4, 0, 0],
	[4, 1, 0],
	[6, 1, 0],
	[6, 2, 0],
	[8, 2, 0],
	[8, 2, 1],
	[10, 2, 1],
	[10, 4, 1],
	[12, 4, 1],
	[12, 4, 2]
];


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
		// warn about the next invasion shortly after sending the previous one (or starting the game)
		if ((toInt(state.time) - waveOffset) % waveCooldown == warningDelay) {
			state.events.setEvent(Event.HelheimInvasionStart, ((waveCooldown - warningDelay) / 60));
		}

		// if the time is right, send a wave
		if (!waveActive && (toInt(state.time) - waveOffset) % waveCooldown == 0 && toInt(state.time) > waveOffset) {
			waveActive = true;
			++currentWave;
			var currentWaveContents = waveContents[currentWave - 1];
			var playerIndex = 0;
			for (homeZone in homeZones) {
				var currentPlayer = homeZone.owner;
				var unitIndex = 0;
				for (unitType in waveUnitTypes) {
					var unitCount = currentWaveContents[unitIndex];
					if (unitCount > 0) {
						var newUnits = centerZone.addUnit(unitType, unitCount, null, true);
						waveUnits[playerIndex] = waveUnits[playerIndex].concat(newUnits);
					}
					++unitIndex;
				}
				launchAttackPlayer(waveUnits[playerIndex], currentPlayer);
				currentPlayer.genericNotify("The undead are coming!", waveUnits[playerIndex][0]);
				// TODO: instead of even waves, have one or two players randomly selected to get bigger waves? make sure to notify them!
				++playerIndex;
			}
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

		// if any clan has been defeated, they all lose
		if (state.players.length < state.startPlayers.length) {
			@sync for (currentPlayer in state.startPlayers) {
				currentPlayer.customDefeat("A member of the alliance has fallen to the horde!"); // "I understood that reference."
			}
		}

		if (!waveActive && currentWave == maxWaves) {
			player.customVictory("Congratulations on your survival! For now...", "If you can see this message, something is wrong with the team setup!");
			// TODO: maybe, after they survive all the waves, mark that objective as done and have them do something else special to close the gate and win?
			// maybe bring all human-controlled warchiefs & kaijas to map center? new objective like "now's our chance to close the gates once and for all!"
		}
	}
}
