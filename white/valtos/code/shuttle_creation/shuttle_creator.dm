#define SHUTTLE_CREATOR_MAX_SIZE 300
#define CUSTOM_SHUTTLE_LIMIT 6
#define CARDINAL_DIRECTIONS_X list(1, 0, -1, 0)
#define CARDINAL_DIRECTIONS_Y list(0, 1, 0, -1)

GLOBAL_VAR_INIT(custom_shuttle_count, 0)		//The amount of custom shuttles created to prevent creating hundreds
GLOBAL_LIST_EMPTY(custom_shuttle_machines)		//Machines that require updating (Heaters, engines)

//============ Shuttle Creator Object ============
/obj/item/shuttle_creator
	name = "Rapid Shuttle Designator"
	icon = 'icons/obj/tools.dmi'
	icon_state = "rsd"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	desc = "A device used to define the area required for custom ships. Uses bluespace crystals to create bluespace-capable ships."
	density = FALSE
	anchored = FALSE
	flags_1 = CONDUCT_1
	item_flags = NOBLUDGEON
	force = 0
	throwforce = 8
	throw_speed = 3
	throw_range = 5
	w_class = WEIGHT_CLASS_NORMAL
	req_access_txt = "11"
	armor = list("melee" = 0, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 0, "bio" = 0, "rad" = 0, "fire" = 100, "acid" = 50)
	resistance_flags = FIRE_PROOF
	var/ready = TRUE
	//pre-designation
	var/override_max_shuttles = FALSE
	var/obj/machinery/computer/camera_advanced/shuttle_creator/internal_shuttle_creator
	//During designation
	var/overwritten_area = /area/space
	var/list/loggedTurfs = list()
	var/loggedOldArea
	var/area/recorded_shuttle_area
	var/datum/shuttle_creator_overlay_holder/overlay_holder
	//After designation
	var/linkedShuttleId

/obj/item/shuttle_creator/Initialize()
	. = ..()
	internal_shuttle_creator = new()
	internal_shuttle_creator.owner_rsd = src
	overlay_holder = new()

/obj/item/shuttle_creator/Destroy()
	. = ..()
	if(internal_shuttle_creator)
		internal_shuttle_creator.owner_rsd = null
		QDEL_NULL(internal_shuttle_creator)
	if(overlay_holder)
		QDEL_NULL(overlay_holder)

/obj/item/shuttle_creator/attack_self(mob/user)
	..()
	if(linkedShuttleId)
		select_preferred_direction(user)
		return
	if(GLOB.custom_shuttle_count > CUSTOM_SHUTTLE_LIMIT && !override_max_shuttles)
		to_chat(user, span_warning("Too many shuttles have been created."))
		message_admins("[ADMIN_FLW(user)] attempted to create a shuttle, however [CUSTOM_SHUTTLE_LIMIT] have already been created.")
		return
	if(!internal_shuttle_creator)
		return
	overlay_holder.add_client(user.client)
	internal_shuttle_creator.attack_hand(user)

/obj/item/shuttle_creator/afterattack(atom/target, mob/user, proximity_flag)
	. = ..()
	if(!ready)
		to_chat(user, span_warning("You need to define a shuttle area first."))
		return
	if(!proximity_flag)
		return
	if(istype(target, /obj/machinery/computer/shuttle_flight/custom_shuttle))
		if(!linkedShuttleId)
			to_chat(user, span_warning("Error, no defined shuttle linked to device."))
			return
		var/obj/machinery/computer/shuttle_flight/custom_shuttle/console = target
		console.linkShuttle(linkedShuttleId)
		to_chat(user, span_notice("Console linked successfully!"))
		return
	to_chat(user, span_warning("The [src] bleeps. Select an airlock to create a docking port, or a valid machine to link."))
	return

//=========== shuttle designation actions ============
/obj/item/shuttle_creator/proc/calculate_bounds(obj/docking_port/mobile/port)
	if(!port || !istype(port, /obj/docking_port/mobile))
		return FALSE
	//Heights is the distance away from the port
	//width is the distance perpendicular to the port
	var/minX = INFINITY
	var/maxX = 0
	var/minY = INFINITY
	var/maxY = 0
	for(var/turf/T in loggedTurfs)
		minX = min(T.x, minX)
		maxX = max(T.x, maxX)
		minY = min(T.y, minY)
		maxY = max(T.y, maxY)
	//Make sure shuttle was actually found.
	if(maxX == INFINITY || maxY == INFINITY)
		return FALSE
	minX--
	minY--
	var/width = maxX - minX
	var/height = maxY - minY
	var/offset_x = port.x - minX
	var/offset_y = port.y - minY
	switch(port.dir) //Source: code/datums/shuttles.dm line 77 (14/03/2020) :)
		if(NORTH)
			port.width = width
			port.height = height
			port.dwidth = offset_x - 1
			port.dheight = offset_y - 1
		if(EAST)
			port.width = height
			port.height = width
			port.dwidth = height - offset_y
			port.dheight = offset_x - 1
		if(SOUTH)
			port.width = width
			port.height = height
			port.dwidth = width - offset_x
			port.dheight = height - offset_y
		if(WEST)
			port.width = height
			port.height = width
			port.dwidth = offset_y - 1
			port.dheight = width - offset_x
	return TRUE

//Go through all the all_turfs and check which direction doesn't have the shuttle
/obj/item/shuttle_creator/proc/getNonShuttleDirection(turf/targetTurf)
	var/position = null
	if(!(get_offset_target_turf(targetTurf, 0, 1) in loggedTurfs))
		if(position != null)
			return null
		position = NORTH
	if(!(get_offset_target_turf(targetTurf, 0, -1) in loggedTurfs))
		if(position != null)
			return null
		position = SOUTH
	if(!(get_offset_target_turf(targetTurf, 1, 0) in loggedTurfs))
		if(position != null)
			return null
		position = EAST
	if(!(get_offset_target_turf(targetTurf, -1, 0) in loggedTurfs))
		if(position != null)
			return null
		position = WEST
	return position

/obj/item/shuttle_creator/proc/shuttle_create_docking_port(atom/target, mob/user)

	if(loggedTurfs.len == 0 || !recorded_shuttle_area)
		to_chat(user, span_warning("Invalid shuttle, restarting bluespace systems..."))
		return FALSE

	var/datum/map_template/shuttle/new_shuttle = new /datum/map_template/shuttle()

	var/obj/docking_port/mobile/port = new /obj/docking_port/mobile(get_turf(target))
	port.shuttle_object_type = /datum/orbital_object/shuttle/custom_shuttle
	var/obj/docking_port/stationary/stationary_port = new /obj/docking_port/stationary(get_turf(target))
	stationary_port.delete_after = TRUE
	stationary_port.name = "[recorded_shuttle_area.name] Custom Shuttle construction site"
	port.callTime = 50
	port.dir = 1	//Point away from space.
	port.id = "custom_[GLOB.custom_shuttle_count]"
	linkedShuttleId = port.id
	port.ignitionTime = 25
	port.port_direction = 2
	port.preferred_direction = EAST
	port.name = "[recorded_shuttle_area.name] Custom Shuttle"
	port.area_type = recorded_shuttle_area

	stationary_port.area_type = overwritten_area

	var/portDirection = getNonShuttleDirection(get_turf(port))
	var/invertedDir = invertDir(portDirection)
	if(!portDirection || !invertedDir)
		to_chat(usr, span_warning("Shuttle creation aborted, docking airlock must be on an external wall. Please select a new airlock."))
		port.Destroy()
		stationary_port.Destroy()
		linkedShuttleId = null
		return FALSE
	port.dir = invertedDir
	port.port_direction = portDirection

	if(!calculate_bounds(port))
		to_chat(usr, span_warning("Bluespace calculations failed, please select a new airlock."))
		port.Destroy()
		stationary_port.Destroy()
		linkedShuttleId = null
		return FALSE

	port.shuttle_areas = list()
	//var/list/all_turfs = port.return_ordered_turfs(port.x, port.y, port.z, port.dir)
	var/list/all_turfs = loggedTurfs
	for(var/i in 1 to all_turfs.len)
		var/turf/curT = all_turfs[i]
		var/area/cur_area = curT.loc
		//Add the area to the shuttle <3
		if(istype(cur_area, recorded_shuttle_area))
			if(istype(curT, /turf/open/space))
				continue
			if(istype(curT, /turf/open/openspace))
				continue
			if(length(curT.baseturfs) < 2)
				continue
			//Add the shuttle base shit to the shuttle
			curT.baseturfs.Insert(3, /turf/baseturf_skipover/shuttle)
			port.shuttle_areas[cur_area] = TRUE

	port.linkup(new_shuttle, stationary_port)

	port.movement_force = list("KNOCKDOWN" = 0, "THROW" = 0)
	port.initiate_docking(stationary_port)

	port.mode = SHUTTLE_IDLE
	port.timer = 0

	port.register()

	icon_state = "rsd_used"

	//Select shuttle fly direction.
	select_preferred_direction(user)

	//Clear highlights
	overlay_holder.clear_highlights()
	GLOB.custom_shuttle_count ++
	message_admins("[ADMIN_LOOKUPFLW(user)] created a new shuttle with a [src] at [ADMIN_VERBOSEJMP(user)] with a name [recorded_shuttle_area.name] ([GLOB.custom_shuttle_count] custom shuttles, limit is [CUSTOM_SHUTTLE_LIMIT])")
	log_game("[key_name(user)] created a new shuttle with a [src] at [AREACOORD(user)] with a name [recorded_shuttle_area.name] ([GLOB.custom_shuttle_count] custom shuttles, limit is [CUSTOM_SHUTTLE_LIMIT])")
	return TRUE

/obj/item/shuttle_creator/proc/create_shuttle_area(mob/user)
	if(!loggedTurfs)
		return FALSE
	if(!check_area(loggedTurfs, FALSE))	//Makes sure nothing (Shuttles) has moved into the area during creation
		return FALSE
	//Create the new area
	var/area/shuttle/custom/powered/newS
	var/area/oldA = loggedOldArea
	var/str = stripped_input(user, "Shuttle Name:", "Blueprint Editing", "", MAX_NAME_LEN)
	if(!str || !length(str))
		return FALSE
	if(length(str) > 50)
		to_chat(user, span_warning("The provided ship name is too long, blares the [src]."))
		return FALSE
	newS = new /area/shuttle/custom/powered()
	newS.setup(str)
	newS.static_lighting = FALSE
	//Shuttles always have gravity
	newS.has_gravity = TRUE
	newS.requires_power = TRUE
	//Record the area for use when creating the docking port
	recorded_shuttle_area = newS

	for(var/i in 1 to loggedTurfs.len)
		var/turf/turf_holder = loggedTurfs[i]
		var/area/old_area = turf_holder.loc
		newS.contents += turf_holder
		turf_holder.change_area(old_area, newS)

	newS.reg_in_areas_in_z()

	var/list/firedoors = oldA.firedoors
	for(var/door in firedoors)
		var/obj/machinery/door/firedoor/FD = door
		FD.CalculateAffectingAreas()
	return TRUE

//Select shuttle fly direction.
/obj/item/shuttle_creator/proc/select_preferred_direction(mob/user)
	var/obj/docking_port/mobile/port = SSshuttle.getShuttle(linkedShuttleId)
	if(!port || !istype(port, /obj/docking_port/mobile))
		return FALSE
	var/static/list/choice = list("NORTH" = NORTH, "SOUTH" = SOUTH, "EAST" = EAST, "WEST" = WEST)
	var/Pdir = input(user, "Shuttle Fly Direction:", "Blueprint Editing", "NORTH") as null|anything in list("NORTH", "SOUTH", "EAST", "WEST")
	if(Pdir)
		port.preferred_direction = choice[Pdir]

//Checks an area to ensure that the turfs provided are valid to be made into a shuttle
/obj/item/shuttle_creator/proc/check_area(list/turfs, addingTurfs = TRUE)
	if(!turfs)
		to_chat(usr, span_warning("Shuttles must be created in an airtight space, ensure that the shuttle is airtight, including corners."))
		return FALSE
	if(turfs.len + (addingTurfs ? loggedTurfs.len : 0) > SHUTTLE_CREATOR_MAX_SIZE)
		to_chat(usr, span_warning("The [src]'s internal cooling system wizzes violently and a message appears on the screen, \"Caution, this device can only handle the creation of shuttles up to [SHUTTLE_CREATOR_MAX_SIZE] units in size. Please reduce your shuttle by [turfs.len-SHUTTLE_CREATOR_MAX_SIZE]. Sorry for the inconvinience\""))
		return FALSE
	//Check to see if it's a valid shuttle
	for(var/i in 1 to turfs.len)
		var/area/place = get_area(turfs[i])
		//If any of the turfs are on station / not in space, a shuttle cannot be forced there
		if(!place)
			to_chat(usr, span_warning("You can't seem to overpower the bluespace harmonics in this location, try somewhere else."))
			return FALSE
		if(istype(place, /area/space))
			overwritten_area = /area/space
		else if(istype(place, /area/lavaland/surface/outdoors))
			overwritten_area = /area/lavaland/surface/outdoors
		else if(istype(place, /area/service/electronic_marketing_den))
			overwritten_area = /area/service/electronic_marketing_den
		else if(istype(place, /area/asteroid/generated))
			overwritten_area = /area/asteroid/generated
		else
			to_chat(usr, span_warning("Caution, shuttle must not use any material connected to the station. Your shuttle is currenly overlapping with [place.name]."))
			return FALSE
	//Finally, check to see if the area is actually attached
	if(!LAZYLEN(loggedTurfs))
		return TRUE
	for(var/turf/T in turfs)
		if(turf_connected_to_saved_turfs(T))
			return TRUE
		CHECK_TICK
	to_chat(usr, span_warning("Caution, new areas of the shuttle must be connected to the other areas of the shuttle."))
	return FALSE

/obj/item/shuttle_creator/proc/turf_connected_to_saved_turfs(turf/T)
	for(var/i in 1 to 4)
		var/turf/adjacentT = get_offset_target_turf(T, CARDINAL_DIRECTIONS_X[i], CARDINAL_DIRECTIONS_Y[i])
		if(adjacentT in loggedTurfs)
			return TRUE
	return FALSE

/obj/item/shuttle_creator/proc/turf_in_list(turf/T)
	return loggedTurfs.Find(T)

/obj/item/shuttle_creator/proc/add_single_turf(turf/T)
	if(!check_area(list(T)))
		return FALSE
	loggedTurfs |= T
	loggedOldArea = get_area(T)
	overlay_holder.highlight_turf(T)

/obj/item/shuttle_creator/proc/add_saved_area(mob/user)
	var/static/area_or_turf_fail_types = typecacheof(list(
		/turf/open/space,
		/turf/open/openspace,
		/area/shuttle
		))
	//Detect the turfs connected in the curerrent enclosed area
	var/list/turfs = detect_room(get_turf(user), area_or_turf_fail_types)
	if(!check_area(turfs))
		return FALSE
	loggedOldArea = get_area(get_turf(user))
	loggedTurfs |= turfs
	overlay_holder.highlight_area(turfs)
	//TODO READD THIS SHIT: icon_state = "rsd_used"
	to_chat(user, span_notice("You add the area into the buffer of the [src], you made add more areas or select an airlock to act as a docking port to complete the shuttle."))
	return turfs

/obj/item/shuttle_creator/proc/remove_single_turf(turf/T)
	if(!turf_in_list(T))
		return
	loggedTurfs -= T
	loggedOldArea = get_area(T)
	overlay_holder.unhighlight_turf(T)

/obj/item/shuttle_creator/proc/reset_saved_area()
	overlay_holder.clear_highlights()
	loggedTurfs.Cut()
	to_chat(usr, span_notice("You reset the area buffer on the [src]."))

#undef CARDINAL_DIRECTIONS_X
#undef CARDINAL_DIRECTIONS_Y

/obj/item/storage/box/diy_shuttle
	name = "набор шаттлостроителя"
	desc = "Сделай сам!"

/obj/item/storage/box/diy_shuttle/PopulateContents()
	..()
	new /obj/item/shuttle_creator(src)
	new /obj/item/circuitboard/computer/shuttle/flight_control(src)
	new /obj/item/circuitboard/machine/shuttle/engine/plasma(src)
	new /obj/item/circuitboard/machine/shuttle/engine/plasma(src)
	new /obj/item/circuitboard/machine/shuttle/heater(src)
	new /obj/item/circuitboard/machine/shuttle/heater(src)
