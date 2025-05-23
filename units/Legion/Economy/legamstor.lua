return {
	legamstor = {
		buildangle = 6093,
		energycost = 11000,
		metalcost = 760,
		buildpic = "legamstor.DDS",
		buildtime = 20500,
		canrepeat = false,
		category = "CANBEUW",
		collisionvolumeoffsets = "-6 0 0",
		collisionvolumescales = "46 40 58",
		collisionvolumetype = "Box",
		corpse = "DEAD",
		explodeas = "mediumBuildingexplosiongeneric",
		footprintx = 4,
		footprintz = 4,
		idleautoheal = 5,
		idletime = 1800,
		health = 11200,
		maxslope = 20,
		maxwaterdepth = 9999,
		metalstorage = 10000,
		objectname = "Units/legamstor.s3o",
		script = "Units/legamstor.cob",
		seismicsignature = 0,
		selfdestructas = "mediumBuildingExplosionGenericSelfd",
		sightdistance = 182,
		yardmap = "oooooooooooooooo",
		customparams = {
			usebuildinggrounddecal = true,
			buildinggrounddecaltype = "decals/legamstor_aoplane.dds",
			buildinggrounddecalsizey = 6,
			buildinggrounddecalsizex = 6,
			buildinggrounddecaldecayspeed = 30,
			unitgroup = 'metal',
			model_author = "Protar",
			normaltex = "unittextures/leg_normal.dds",
			removestop = true,
			removewait = true,
			subfolder = "CorBuildings/SeaEconomy",
			techlevel = 2,
		},
		featuredefs = {
			dead = {
				blocking = true,
				category = "corpses",
				collisionvolumeoffsets = "-8.0463180542 -4.28710937506e-05 2.1676940918",
				collisionvolumescales = "49.8645172119 42.9171142578 64.3353881836",
				collisionvolumetype = "Box",
				damage = 4020,
				featuredead = "HEAP",
				footprintx = 4,
				footprintz = 4,
				height = 9,
				metal = 462,
				object = "Units/legamstor_dead.s3o",
				reclaimable = true,
			},
			heap = {
				blocking = false,
				category = "heaps",
				collisionvolumescales = "85.0 14.0 6.0",
				collisionvolumetype = "cylY",
				damage = 2010,
				footprintx = 4,
				footprintz = 4,
				metal = 185,
				object = "Units/cor4X4A.s3o",
				reclaimable = true,
				resurrectable = 0,
			},
		},
		sfxtypes = {
			pieceexplosiongenerators = {
				[1] = "deathceg2",
				[2] = "deathceg3",
				[3] = "deathceg4",
			},
		},
		sounds = {
			canceldestruct = "cancel2",
			underattack = "warning1",
			count = {
				[1] = "count6",
				[2] = "count5",
				[3] = "count4",
				[4] = "count3",
				[5] = "count2",
				[6] = "count1",
			},
			select = {
				[1] = "stormtl2",
			},
		},
	},
}
