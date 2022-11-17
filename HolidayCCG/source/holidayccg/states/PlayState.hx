package holidayccg.states;

import flixel.FlxCamera.FlxCameraFollowStyle;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.tile.FlxBaseTilemap.FlxTilemapAutoTiling;
import flixel.tile.FlxTilemap;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxDirectionFlags;
import holidayccg.game.GameMap;
import holidayccg.game.GameObject;
import holidayccg.globals.Dialog;
import holidayccg.globals.GameGlobals;
import holidayccg.ui.DialogFrame;

class PlayState extends FlxState
{
	public var mapLayer:FlxTypedGroup<FlxTilemap>;
	public var objectLayer:FlxTypedGroup<GameObject>;
	public var playerLayer:FlxTypedGroup<GameObject>;

	public var baseMap:FlxTilemap = null;
	public var decorativeMap:FlxTilemap = null;

	public var player:GameObject;

	public var blackOut:FlxSprite;

	public var ready:Bool = false;

	public var talking:Bool = false;

	public var dialog:DialogFrame;

	public var battleState:BattleState;

	public var collectionState:CollectionState;

	public var mapData:GameMap;

	public var tutSeen:Bool = false;

	override public function create()
	{
		GameGlobals.PlayState = this;
		GameGlobals.init();

		trace(FlxG.camera.pixelPerfectRender);
		#if debug
		GameGlobals.Player.collection.add(10, 1);
		#end

		destroySubStates = false;

		add(mapLayer = new FlxTypedGroup<FlxTilemap>());
		add(objectLayer = new FlxTypedGroup<GameObject>());
		add(playerLayer = new FlxTypedGroup<GameObject>());
		add(dialog = new DialogFrame());

		playerLayer.add(player = new GameObject());

		FlxG.camera.follow(player, FlxCameraFollowStyle.TOPDOWN);

		add(blackOut = new FlxSprite(0, 0));
		blackOut.makeGraphic(Global.width, Global.height, GameGlobals.ColorPalette[1]);
		blackOut.scrollFactor.set();

		super.create();

		setMap("test room");

		battleState = new BattleState(returnFromBattle);
		collectionState = new CollectionState(returnFromCollection);

		tutSeen = Dialog.Flags.exists("tutSeen");

		fadeIn();
	}

	public function fadeIn():Void
	{
		blackOut.alpha = 1;
		FlxTween.tween(blackOut, {alpha: 0}, 1, {
			ease: FlxEase.quadOut,
			onComplete: (_) ->
			{
				ready = true;
			}
		});
	}

	public function setMap(RoomName:String):Void
	{
		mapData = GameGlobals.MapList.get(RoomName);

		if (baseMap != null)
		{
			baseMap.kill();
			mapLayer.remove(baseMap, true);
			baseMap = new FlxTilemap();

			decorativeMap.kill();
			mapLayer.remove(decorativeMap, true);
			decorativeMap = new FlxTilemap();

			for (o in objectLayer.members)
			{
				o.kill();
				objectLayer.remove(o, true);
			}
			objectLayer.clear();
		}
		else
		{
			baseMap = new FlxTilemap();
			decorativeMap = new FlxTilemap();
		}

		baseMap.loadMapFromArray(mapData.baseLayerData, mapData.widthInTiles, mapData.heightInTiles, Global.asset("assets/images/base_tiles.png"),
			GameGlobals.TILE_SIZE, GameGlobals.TILE_SIZE, FlxTilemapAutoTiling.OFF, 0, 0, 40);
		decorativeMap.loadMapFromArray(mapData.decorativeLayerData, mapData.widthInTiles, mapData.heightInTiles,
			Global.asset("assets/images/decorative_tiles.png"), GameGlobals.TILE_SIZE, GameGlobals.TILE_SIZE, FlxTilemapAutoTiling.OFF, 0, 1, 1);

		decorativeMap.x = decorativeMap.y = baseMap.x = baseMap.y = 0;
		mapLayer.add(baseMap);
		mapLayer.add(decorativeMap);

		FlxG.worldBounds.set(0, 2, baseMap.width, baseMap.height - 2);

		FlxG.camera.setScrollBounds(0, baseMap.width, 2, baseMap.height - 2);

		// add objects
		var o:GameObject = null;
		for (obj in mapData.objects)
		{
			switch (obj.objectType)
			{
				case PLAYER:
					player.spawn("player", "player", obj.x, obj.y, GameObject.facingFromString(obj.facing));

				case NPC:
					o = objectLayer.getFirstAvailable();
					if (o == null)
						objectLayer.add(o = new GameObject());
					o.spawn(obj.name, obj.sprite, obj.x, obj.y, GameObject.facingFromString(obj.facing));

				default:
			}
		}
		FlxG.camera.snapToTarget();
	}

	public function showDialog(Dialog:DialogData):Void
	{
		talking = true;
		dialog.display(Dialog);
		ready = true;
	}

	public function checkForObjects(X:Float, Y:Float):GameObject
	{
		for (o in objectLayer.members)
		{
			if (Std.int(o.x / GameGlobals.TILE_SIZE) == X && Std.int(o.y / GameGlobals.TILE_SIZE) == Y)
				return o;
		}
		return null;
	}

	public function openCollection():Void
	{
		ready = false;
		collectionState.refresh();
		openSubState(collectionState);
	}

	public function returnFromTutorial():Void
	{
		ready = true;
		tutSeen = true;
		Dialog.Flags.set("tutSeen", true);
		GameGlobals.save();
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (ready && !tutSeen)
		{
			tutSeen = true;
			ready = false;
			openSubState(new PlayStateTutorial(returnFromTutorial));
			return;
		}

		if (!ready || player.moving)
			return;

		var pause:Bool = Controls.justPressed.PAUSE;
		if (pause && !talking)
		{
			openCollection();
			return;
		}

		var a:Bool = Controls.justPressed.A;

		if (a)
		{
			// if talking, advance/close text
			if (talking)
			{
				talking = false;
				dialog.hide();
				return;
			}
			else
			{
				var dX:Int = player.facing == FlxDirectionFlags.LEFT ? -1 : player.facing == FlxDirectionFlags.RIGHT ? 1 : 0;
				var dY:Int = player.facing == FlxDirectionFlags.UP ? -1 : player.facing == FlxDirectionFlags.DOWN ? 1 : 0;

				var talkTo:GameObject = checkForObjects(Std.int(player.x / GameGlobals.TILE_SIZE) + dX, Std.int(player.y / GameGlobals.TILE_SIZE) + dY);
				if (talkTo != null)
				{
					if (Dialog.talk(talkTo.name))
					{
						return;
					}
				}
			}
			return;
		}

		if (talking && (Controls.justPressed.LEFT || Controls.justPressed.RIGHT))
		{
			if (dialog.isQuestion)
				dialog.changeSelection();
			return;
		}

		if (talking)
			return;

		var left:Bool = Controls.pressed.LEFT;
		var right:Bool = Controls.pressed.RIGHT;
		var up:Bool = Controls.pressed.UP;
		var down:Bool = Controls.pressed.DOWN;
		if (left && right)
			left = right = false;
		if (up && down)
			up = down = false;

		if (up)
			player.move(0, -1, checkPlayerMove);
		else if (down)
			player.move(0, 1, checkPlayerMove);
		else if (left)
			player.move(-1, 0, checkPlayerMove);
		else if (right)
			player.move(1, 0, checkPlayerMove);
	}

	public function checkPlayerMove():Void
	{
		if (player.x >= baseMap.width)
		{
			// moved to the right room
			switchToRoom(RIGHT);
		}
		else if (player.x <= 0)
		{
			// moved to the left room
			switchToRoom(LEFT);
		}
		else if (player.y >= baseMap.height)
		{
			// moved to the bottom room
			switchToRoom(DOWN);
		}
		else if (player.y <= 0)
		{
			// moved to the top room
			switchToRoom(UP);
		}
	}

	public function switchToRoom(Dir:FlxDirectionFlags):Void
	{
		ready = false;

		FlxTween.tween(blackOut, {alpha: 1}, 1, {
			ease: FlxEase.quadOut,
			onComplete: (_) ->
			{
				setMap(mapData.neighbors.get(Dir));
				switch (Dir)
				{
					case UP:
						player.y = baseMap.y + baseMap.height - (GameGlobals.TILE_SIZE * 2);

					case DOWN:
						player.y = baseMap.y + GameGlobals.TILE_SIZE;

					case LEFT:
						player.x = baseMap.x + baseMap.width - (GameGlobals.TILE_SIZE * 2);

					case RIGHT:
						player.x = baseMap.x + GameGlobals.TILE_SIZE;

					default:
				}
				fadeIn();
			}
		});
	}

	public function returnFromBattle(Actions:String):Void
	{
		Dialog.parseScripts([Actions]);
		GameGlobals.save();
	}

	public function returnFromCollection():Void
	{
		ready = true;
	}

	public function startBattle(Vs:String):Void
	{
		ready = false;
		battleState.init(GameGlobals.Player.deck, Vs);
		openSubState(battleState);
	}
}
