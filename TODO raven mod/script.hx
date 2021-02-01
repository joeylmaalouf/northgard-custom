var centerZone = getZone(164);
var homeZones = [for(i in [70, 30, 63, 155, 250, 304, 267, 174]) getZone(i)];


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
		// TODO
	}
}

// figure out a way to let them colonize the mainland via boat; per-player objective buttons?
// periodically scan through all uncolonized mainland beach tiles visible to each human player
// and show them a list of buttons to colonize based on the tile type/contents, since we can't see zone ids in game
// ship units to each landing point and back via buttons as well
