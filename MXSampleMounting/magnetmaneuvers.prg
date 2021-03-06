#include "networkdefs.inc"
#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "genericdefs.inc"
#include "superPuckdefs.inc"
#include "cassettedefs.inc"

#define CLOSE_DISTANCE 10

Global Preserve Integer g_dumbbellStatus

Function GTsetDumbbellStatus(status As Integer)
	g_dumbbellStatus = status
	GTsendMagnetStateJSON
Fend

Function GTPositionCheckBeforeMotion As Boolean
	GTPositionCheckBeforeMotion = False
	
	If isCloseToPoint(0) Or isCloseToPoint(1) Or isCloseToPoint(3) Or isCloseToPoint(4) Then
		GTPositionCheckBeforeMotion = True
	Else
		g_RunResult$ = "error GTPositionCheckBeforeMotion: Robot can only start from P0, P1, P3 or P4. But Current position is not Close to any of them!"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
	EndIf

Fend

Function GTJumpHomeToCoolingPointAndWait As Boolean
	String msg$
	
	GTJumpHomeToCoolingPointAndWait = False
	
	Tool 0
	
	If (CX(RealPos) > 0) And (CX(P1) * CY(RealPos) < CX(RealPos) * CY(P1)) Then
		''The above condition checks whether the robot is in the region before P1 containing P0 
		'' Mathematically, Atan(CY(RealPos)/CX(RealPos)) <  Atan(CY(P1)/CX(P1)) checks the angle made by realpos < angle of P1
		'' CX(RealPos) > 0 checks whether the robot is in first quadrant (near home and not near goni)
		GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
		LimZ 0
		Jump P1
	EndIf
	
	If Not Open_Lid Then
		g_RunResult$ = "error GTJumpHomeToCoolingPointAndWait open lid failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
        Exit Function
    EndIf
    
    '' for testing only, should be put inside the below if statement
	GTsetRobotSpeedMode(INSIDE_LN2_SPEED)
	
	''This following condition check allows GTJumpHomeToCoolingPointAndWait to start from P3 
	If Dist(RealPos, P3) < CLOSE_DISTANCE Then
		Go P3
	ElseIf Dist(RealPos, P4) < CLOSE_DISTANCE Then
		'' After dismount before mount the robot ends at P4 and we don't want to jump out of the LN2
		Move P3
	Else
		LimZ 0
		Jump P3
	EndIf
	
	If g_LN2LevelHigh Then
		Integer timeTakenToCoolTong
		timeTakenToCoolTong = WaitLN2BoilingStop(SENSE_TIMEOUT, HIGH_SENSITIVITY, HIGH_SENSITIVITY)
		msg$ = "GTJumpHomeToCoolingPointAndWait: Cooled tong for " + Str$(timeTakenToCoolTong) + " seconds"
		UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
	EndIf
	
	GTJumpHomeToCoolingPointAndWait = True
Fend

'' WARNING: GTJumpCoolingPointAndWait should be called before GTIsMagnetInGripper
'' because this function can only start from inside dewar (LimZ g_Jump_LimZ_LN2 is called inside this function)
Function GTIsMagnetInGripper As Boolean
	String msg$
	Integer prevPowerMode
	GTIsMagnetInGripper = False

	Tool 0

	'' Closing Gripper only matters because if Gripper is open we might loose magnet while hitting the cradle
	Close_Gripper

	Real probeDistanceFromCradleCenter
	probeDistanceFromCradleCenter = ((MAGNET_LENGTH /2) + (CRADLE_WIDTH /2) - (MAGNET_HEAD_THICKNESS /2)) * CASSETTE_SHRINK_FACTOR ''Picker based probe
	''probeDistanceFromCradleCenter = (-(MAGNET_LENGTH / 2) - (CRADLE_WIDTH / 2) + (3 * MAGNET_HEAD_THICKNESS / 2)) * CASSETTE_SHRINK_FACTOR ''Placer based probe
	
	Integer standbyPoint
	standbyPoint = 52
	P(standbyPoint) = P3 -X(probeDistanceFromCradleCenter * g_dumbbell_Perfect_cosValue) -Y(probeDistanceFromCradleCenter * g_dumbbell_Perfect_sinValue)

	'' In Low Power Mode, GTIsMagnetInGripper fails to detect magnet in gripper sometimes so this snippet runs it always in high power mode
	''Backup current power setting
	prevPowerMode = Power
	''Set high power for this function
	Power High
	
	If Dist(RealPos, P3) < CLOSE_DISTANCE Then
		Go P(standbyPoint)
	Else
		LimZ g_Jump_LimZ_LN2
		Jump P(standbyPoint)
	EndIf
	
	Real maxDistanceToScan
	maxDistanceToScan = DISTANCE_P3_TO_P6 ''+ MAGNET_PROBE_DISTANCE_TOLERANCE
	
	GTsetRobotSpeedMode(PROBE_SPEED)
	''GTsetRobotSpeedMode(SUPERSLOW_SPEED)
	
	ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
	If ForceTouch(DIRECTION_CAVITY_TO_MAGNET, maxDistanceToScan, False) Then
		'' Distance error from perfect magnet position
		Real distErrorFromPerfectMagnetPoint
		''distErrorFromPerfectMagnetPoint = Dist(P(standbyPoint), RealPos) - (DISTANCE_P3_TO_P6 - (MAGNET_AXIS_TO_CRADLE_EDGE + MAGNET_HEAD_RADIUS))
		distErrorFromPerfectMagnetPoint = Abs(CX(P(standbyPoint)) - CX(RealPos)) - (DISTANCE_P3_TO_P6 - (MAGNET_AXIS_TO_CRADLE_EDGE + MAGNET_HEAD_RADIUS))
		
		''If distErrorFromPerfectMagnetPoint < -MAGNET_PROBE_DISTANCE_TOLERANCE Then
		''	GTIsMagnetInGripper = True
		''	msg$ = "IsMagnetInTong: ForceTouch stopped " + Str$(distErrorFromPerfectMagnetPoint) + "mm before reaching theoretical magnet position."
		''	UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
		''Else
		If distErrorFromPerfectMagnetPoint < MAGNET_PROBE_DISTANCE_TOLERANCE Then
			GTIsMagnetInGripper = True
			msg$ = "IsMagnetInTong: ForceTouch detected magnet in tong with distance error =" + Str$(distErrorFromPerfectMagnetPoint) + "."
			UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
		Else
            msg$ = "IsMagnetInTong: ForceTouch moved " + Str$(distErrorFromPerfectMagnetPoint) + "mm beyond theoretical magnet position."
            UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
		EndIf
	Else
		msg$ = "IsMagnetInTong: ForceTouch did not detect magnet in tong even after travelling maximum scan distance!"
        UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
	EndIf
	
	GTLoadPreviousRobotSpeedMode
	
	Go P(standbyPoint)
	
	Move P3 ''because this function is called in several places, I didnot like it to end at standbyPoint
	
	''Restore power setting
	Power prevPowerMode
Fend

Function GTPickMagnet As Boolean
	GTPickMagnet = False

	Tool 0
	
	If Dist(RealPos, P3) < CLOSE_DISTANCE Then
		Go P3
	Else
		LimZ g_Jump_LimZ_LN2
		Jump P3 '' Cooling Point in front of cradle		
	EndIf

	If Not Open_Gripper Then
	    g_RunResult$ = "error GTPickMagnet open gripper failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	Move P6 '' gripper catches the magnet in cradle

	If Not Close_Gripper Then
		g_RunResult$ = "error GTPickMagnet close gripper failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	EndIf

	GTsetDumbbellStatus(DUMBBELL_IN_GRIPPER)

	'' move to p4 (point directly above cradle) and then to P3 to avoid jumping outside LN2
	Move P4
	Move P3
	
	GTPickMagnet = True
Fend

'' WARNING: GTJumpCoolingPointAndWait should be called before GTCheckAndPickMagnet
'' because this function can only start from inside dewar (LimZ g_Jump_LimZ_LN2 is called inside this function)
Function GTCheckAndPickMagnet As Boolean
	GTCheckAndPickMagnet = False
	
	If g_dumbbellStatus = DUMBBELL_MISSING Then
	    g_RunResult$ = "error GTCheckAndPickMagnet: Dumbbell missing.  Place dumbbell in cradle"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		Exit Function
	ElseIf g_dumbbellStatus = DUMBBELL_IN_GRIPPER Then
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:g_dumbbellStatus is DUMBBELL_IN_GRIPPER", INFO_LEVEL)
	ElseIf g_dumbbellStatus = DUMBBELL_IN_CRADLE Then
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:g_dumbbellStatus is DUMBBELL_IN_CRADLE", INFO_LEVEL)
		If Not GTPickMagnet Then
			Exit Function
		EndIf
	ElseIf GTIsMagnetInGripper Then ''CheckMagnet
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTIsMagnetInGripper found magnet on tong.", INFO_LEVEL)
	Else
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTIsMagnetInGripper did not find magnet on tong.", INFO_LEVEL)
		If Not GTPickMagnet Then
			Exit Function
		EndIf
		
		'' Second check to determine whether magnet is missing
		If GTIsMagnetInGripper Then ''CheckMagnet
			GTsetDumbbellStatus(DUMBBELL_IN_GRIPPER) '' assert again
			UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTIsMagnetInGripper found magnet on tong after GTPickMagnet.", INFO_LEVEL)
		Else
			GTsetDumbbellStatus(DUMBBELL_MISSING)
			g_RunResult$ = "error GTCheckAndPickMagnet: Dumbbell missing.  Place dumbbell in cradle"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			GTGoHome
			Exit Function
		EndIf
	EndIf
	
	GTCheckAndPickMagnet = True
Fend

'' WARNING: GTJumpCoolingPointAndWait should be called before GTCheckMagnetForDismount
'' because this function can only start from inside dewar (LimZ g_Jump_LimZ_LN2 is called inside this function)
Function GTCheckMagnetForDismount As Boolean
	GTCheckMagnetForDismount = False
'' if magnet is in gripper, put it in Cradle
	If g_dumbbellStatus = DUMBBELL_IN_GRIPPER Then
		If Not GTReturnMagnet Then
			UpdateClient(TASK_MSG, "GTCheckMagnetForDismount->GTReturnMagnet failed", ERROR_LEVEL)
			Exit Function
		EndIf
	ElseIf g_dumbbellStatus = DUMBBELL_IN_CRADLE Then
		UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:g_dumbbellStatus is DUMBBELL_IN_CRADLE", INFO_LEVEL)
	ElseIf GTIsMagnetInGripper Then ''CheckMagnet
		'' This and the following checks whether magnet is in cradle or gripper and sets g_dumbbellStatus accordingly
		'' Bit of a lengthy process but because this is called only once when robot is restarted, I am sticking with this
		UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:GTIsMagnetInGripper found magnet on tong.", INFO_LEVEL)
		If Not GTReturnMagnet Then
			UpdateClient(TASK_MSG, "GTCheckMagnetForDismount->GTReturnMagnet failed", ERROR_LEVEL)
			Exit Function
		EndIf
	Else
		UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:GTIsMagnetInGripper did not find magnet on tong.", INFO_LEVEL)
		If Not GTPickMagnet Then
			UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:GTPickMagnet failed!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		'' Second check to determine whether magnet is missing
		If GTIsMagnetInGripper Then ''CheckMagnet
			GTsetDumbbellStatus(DUMBBELL_IN_GRIPPER) '' assert again
			UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:GTIsMagnetInGripper found magnet on tong after GTPickMagnet.", INFO_LEVEL)
	
			If Not GTReturnMagnet Then
				UpdateClient(TASK_MSG, "GTCheckMagnetForDismount->GTReturnMagnet failed", ERROR_LEVEL)
				Exit Function
			EndIf
		Else
			GTsetDumbbellStatus(DUMBBELL_MISSING)
			g_RunResult$ = "error GTCheckMagnetForDismount:GTIsMagnetInGripper failed to detect magnet on tong even after GTPickMagnet."
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	EndIf
	
	GTCheckMagnetForDismount = True
Fend

Function GTReturnMagnet As Boolean
	GTReturnMagnet = False
	
	Tool 0
	
	If Dist(RealPos, P4) < CLOSE_DISTANCE Then
		Go P4
	Else
		LimZ g_Jump_LimZ_LN2
		Jump P4 '' this point is directly above cradle
	EndIf

	Move P6 '' gripper catches the magnet in cradle
	
	If Not Open_Gripper Then
		g_RunResult$ = "error GTReturnMagnet:Open_Gripper failed"
		UpdateClient(TASK_MSG, g_RunResult$, INFO_LEVEL)
		Exit Function
	EndIf

	Move P3 '' Cooling Point in front of cradle
	
	'' No need to close gripper
	''If Not Close_Gripper Then
	''	GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTReturnMagnet:Close_Gripper failed")
	''	Exit Function
	''EndIf
	
	GTsetDumbbellStatus(DUMBBELL_IN_CRADLE)
	
	GTReturnMagnet = True
Fend

Function GTGoHome
	LimZ 0
	Tool 0
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	
	If (Dist(RealPos, P18) > CLOSE_DISTANCE) And (CX(RealPos) < 0) And (CX(P18) * CY(RealPos) > CX(RealPos) * CY(P18)) Then
		''The above condition checks whether the robot is in the region after P18 containing gonio 
		'' Mathematically, Atan(CY(RealPos)/CX(RealPos)) >  Atan(CY(P18)/CX(P18)) checks the angle made by realpos > angle of P18
		'' CX(RealPos) < 0 checks whether the robot is in second or third quadrant (near goni and not near home)
		'' Also checks Dist(RealPos, P18) > CLOSE_DISTANCE because if it is close we just jump to p1 directly (we don't have to jump to p18)
		Jump P18
	EndIf
	
	Jump P1
	Jump P0
	Close_Lid
	
	If g_LN2LevelHigh Then
		UpdateClient(TASK_MSG, "Tong is cold. Performing Robot Dance to heat tong.", INFO_LEVEL)
		'' Turn on air flow before switching heater on
		TurnOnHeater
		
		'' Wait 40 Seconds
		''If heater is still not hot, report error
		UpdateClient(TASK_MSG, "Waiting 40 seconds to allow for enough heat propogation in space around (and to) the tong.", INFO_LEVEL)
		If Not WaitHeaterHot(40) Then
			g_RunResult$ = "error Heater is not working!"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		EndIf
		
		'' Start Robot Dance inside Heater
		GTsetRobotSpeedMode(DANCE_SPEED)
		Dance
		GTLoadPreviousRobotSpeedMode
		
		'' Turn off Heater and then turn off air flow
		TurnOffHeater
		UpdateClient(TASK_MSG, "Robot Dance Complete.", INFO_LEVEL)
	EndIf
Fend

Function GTReturnMagnetAndGoHome As Boolean
	GTReturnMagnetAndGoHome = False

	If Not GTReturnMagnet Then
		UpdateClient(TASK_MSG, "GTReturnMagnetAndGoHome:GTReturnMagnet failed", ERROR_LEVEL)
		Exit Function
	EndIf

	'' Return Home and Close Lid
	GTGoHome
	
	GTReturnMagnetAndGoHome = True
Fend

Function GTTwistOffMagnet
	Real currentUAngle
	
	currentUAngle = CU(RealPos)
	
	Integer currentTool
	currentTool = Tool()
		
	Real twistOffAngle
	twistOffAngle = 60 ''degrees

	''Safe distance for magnet to twist (otherwise the magnet head front edge would overpress the sample)
	Real twistMagnetRadiusSafeDistance, twistMagnetRadiusSafeDistanceX, twistMagnetRadiusSafeDistanceY
	twistMagnetRadiusSafeDistance = MAGNET_HEAD_RADIUS * Sin(DegToRad(twistOffAngle)) ''Note:If samples are falling only in LN2, then we need multiply CASSETTE_SHRINK_FACTOR to MAGNET_HEAD_RADIUS
	twistMagnetRadiusSafeDistanceX = -twistMagnetRadiusSafeDistance * Cos(DegToRad(currentUAngle))
	twistMagnetRadiusSafeDistanceY = -twistMagnetRadiusSafeDistance * Sin(DegToRad(currentUAngle))

	''Safe distance for magnet to twist (otherwise the magnet head back edge would hit the port edge)
	Real twistMagnetHeadSafeDistance, twistMagnetHeadSafeDistanceX, twistMagnetHeadSafeDistanceY
	twistMagnetHeadSafeDistance = MAGNET_HEAD_THICKNESS

	Real twistAngleInGlobalCoordinates
	Select currentTool
		Case PICKER_TOOL
			twistAngleInGlobalCoordinates = twistOffAngle ''degrees
			twistMagnetHeadSafeDistanceX = MAGNET_HEAD_THICKNESS * Cos(DegToRad(currentUAngle + 90))
			twistMagnetHeadSafeDistanceY = MAGNET_HEAD_THICKNESS * Sin(DegToRad(currentUAngle + 90))
		Case PLACER_TOOL
			twistAngleInGlobalCoordinates = -twistOffAngle ''degrees
			twistMagnetHeadSafeDistanceX = MAGNET_HEAD_THICKNESS * Cos(DegToRad(currentUAngle - 90))
			twistMagnetHeadSafeDistanceY = MAGNET_HEAD_THICKNESS * Sin(DegToRad(currentUAngle - 90))
		Case PORT_JAM_RECHECK_TOOL
			twistAngleInGlobalCoordinates = -twistOffAngle ''degrees
			twistMagnetHeadSafeDistanceX = MAGNET_HEAD_THICKNESS * Cos(DegToRad(currentUAngle - 90))
			twistMagnetHeadSafeDistanceY = MAGNET_HEAD_THICKNESS * Sin(DegToRad(currentUAngle - 90))
		Default
			''If other toolsets are used, do not perform twistoff moves (just return before moving)
			Exit Function
	Send
	
	''Move safe distance before twistoff so that there is no overpress of sample due to magnet radius
	Move RealPos +X(twistMagnetRadiusSafeDistanceX) +Y(twistMagnetRadiusSafeDistanceY)
	
	''Perform the twistoff, (If the following XY move is not added, then the back of the magnet head's backedge hits the port edge)
	Move RealPos +X(twistMagnetHeadSafeDistanceX) +Y(twistMagnetHeadSafeDistanceY) +U(twistAngleInGlobalCoordinates) ROT
	
	Exit Function
Fend
''twist cavity off gonio to break magnetic field
Function GTTwistOffCavityFromGonio
	Integer currTool
	Real currAngle, dx, dy
	''Setup variables	
	currTool = Tool()
	currAngle = DegToRad(CU(RealPos))
	dx = -10.0 * Cos(currAngle);
	dy = -10.0 * Sin(currAngle);
	''if near gonio
	If isCloseToPoint(21) Then
		'if near gonio (called during dismount routine after grabbing sample in cavity from gonio)
		''If p12 defined then define toolset for cavity twistoff 
		If PDef(P12) Then
			''Setup the toolset
			TLSet 3, XY(CX(P12), CY(P12), CZ(P12), CU(P12))
			''do the move
			Tool 3
			Go (RealPos +U(45))
			Move (RealPos +X(dx) +Y(dy))
			''restore tool
			Tool currTool
		EndIf
	EndIf
Fend
''' *** Goniometer Mount/Dismount Moves *** '''
Function GTMoveToGoniometer As Boolean
	GTMoveToGoniometer = False

	If Not Close_Gripper Then
		g_RunResult$ = "error GTMoveToGoniometer:Close_Gripper failed"
		UpdateClient(TASK_MSG, g_runresult$, ERROR_LEVEL)
		Exit Function
	EndIf
	
	Tool 0
	LimZ 0
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	
	If (CX(RealPos) > 0) And (CX(P1) * CY(RealPos) < CX(RealPos) * CY(P1)) Then
		''The above condition checks whether the robot is in the region before P1 containing P0 
		'' Mathematically, Atan(CY(RealPos)/CX(RealPos)) <  Atan(CY(P1)/CX(P1)) checks the angle made by realpos < angle of P1
		'' CX(RealPos) > 0 checks whether the robot is in first quadrant (near home and not near goni)
		Jump P1
		
		''This function starts from P0 in Dismounting, so open lid before dismounting
		If Not Open_Lid Then
			g_RunResult$ = "error GTMoveToGoniometer:Open_Lid failed"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
	        Exit Function
	    EndIf
	EndIf
	
	If Dist(RealPos, P4) < CLOSE_DISTANCE Then
		'' This function is called when Robot is at P4, during MountSample
		Move P2 CP
		Move P18 CP
	ElseIf Dist(RealPos, P18) < CLOSE_DISTANCE Then ''Required in StressTestSuperPuck
		Go P18 ''Required in StressTestSuperPuck
	Else
		'' This allows us to call GTMoveToGoniometer from P3
        Jump P18
	EndIf

	Move P22 CP
	'' Only if P22 is reached return True

	GTMoveToGoniometer = True
Fend


Function GTMoveGoniometerToAboveCradle As Boolean
	''Starts from P22 or away from goniometer by 40mm from P22
	If Not Close_Gripper Then
		g_RunResult$ = "error GTMoveGoniometerToAboveCradle:Close_Gripper failed"
		UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
		GTMoveGoniometerToAboveCradle = False
		Exit Function
	EndIf
	
	LimZ 0
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	Move P18 CP
	Jump P4

	GTMoveGoniometerToAboveCradle = True
Fend


