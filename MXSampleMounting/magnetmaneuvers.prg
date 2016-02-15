#include "networkdefs.inc"
#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "genericdefs.inc"
#include "superPuckdefs.inc"
#include "cassettedefs.inc"

#define CLOSE_DISTANCE 10

Global Preserve Integer g_dumbbellStatus

Function GTStartRobot
	'' This is the only function in GT domain which starts the motors and sets the power   	
	
   	If Not CheckEnvironment Then
   		Motor Off
		UpdateClient(TASK_MSG, "GTStartRobot:CheckEnvironment failed. So the robot motors are stopped, it can't move.", ERROR_LEVEL)
        Exit Function
   	EndIf
   	
	If Motor = Off Then
		Motor On

		''Set dumbbell status to unknown whenever motors are started from off state
		g_dumbbellStatus = DUMBBELL_STATUS_UNKNOWN
	EndIf
   	
   	Power Low ''For debugging use low power mode
   		   	
	Tool 0
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
Fend

Function GTJumpHomeToCoolingPointAndWait As Boolean
	String msg$
	
	GTJumpHomeToCoolingPointAndWait = False

	If (CX(RealPos) > 0) And (CX(P1) * CY(RealPos) < CX(RealPos) * CY(P1)) Then
		''The above condition checks whether the robot is in the region before P1 containing P0 
		'' Mathematically, Atan(CY(RealPos)/CX(RealPos)) <  Atan(CY(P1)/CX(P1)) checks the angle made by realpos < angle of P1
		'' CX(RealPos) > 0 checks whether the robot is in first quadrant (near home and not near goni)
		Jump P1
	EndIf
	
	If Not Open_Lid Then
		UpdateClient(TASK_MSG, "GTJumpHomeToCoolingPointAndWait:Open_Lid failed", ERROR_LEVEL)
        Exit Function
    EndIf
	
	Jump P3
	
	'' for testing only, should be put inside the below if statement
	GTsetRobotSpeedMode(INSIDE_LN2_SPEED)
	
	If g_LN2LevelHigh Then
		Integer timeTakenToCoolTong
		timeTakenToCoolTong = WaitLN2BoilingStop(SENSE_TIMEOUT, HIGH_SENSITIVITY, HIGH_SENSITIVITY)
		msg$ = "GTJumpHomeToCoolingPointAndWait: Cooled tong for " + Str$(timeTakenToCoolTong) + " seconds"
		UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
	EndIf
	
	GTJumpHomeToCoolingPointAndWait = True
Fend

Function GTIsMagnetInGripper As Boolean
	String msg$
	GTIsMagnetInGripper = False

	Tool 0

	'' Closing Gripper only matters because if Gripper is open we might loose magnet while hitting the cradle
	Close_Gripper

	Real probeDistanceFromCradleCenter
	probeDistanceFromCradleCenter = ((MAGNET_LENGTH /2) + (CRADLE_WIDTH /2) - (MAGNET_HEAD_THICKNESS /2)) * CASSETTE_SHRINK_FACTOR
	Integer standbyPoint
	standbyPoint = 52
	P(standbyPoint) = P3 -X(probeDistanceFromCradleCenter * g_dumbbell_Perfect_cosValue) -Y(probeDistanceFromCradleCenter * g_dumbbell_Perfect_sinValue)

	If Dist(RealPos, P3) < CLOSE_DISTANCE Then
		Move P(standbyPoint)
	Else
		Jump P(standbyPoint)
	EndIf
	
	Real maxDistanceToScan
	maxDistanceToScan = DISTANCE_P3_TO_P6 ''+ MAGNET_PROBE_DISTANCE_TOLERANCE
	
	GTsetRobotSpeedMode(PROBE_SPEED)
	
	ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
	If ForceTouch(DIRECTION_CAVITY_TO_MAGNET, maxDistanceToScan, False) Then
		'' Distance error from perfect magnet position
		Real distErrorFromPerfectMagnetPoint
		''distErrorFromPerfectMagnetPoint = Dist(P(standbyPoint), RealPos) - (DISTANCE_P3_TO_P6 - (MAGNET_AXIS_TO_CRADLE_EDGE + MAGNET_HEAD_RADIUS))
		distErrorFromPerfectMagnetPoint = Abs(CX(P(standbyPoint)) - CX(RealPos)) - (DISTANCE_P3_TO_P6 - (MAGNET_AXIS_TO_CRADLE_EDGE + MAGNET_HEAD_RADIUS))
		
		If distErrorFromPerfectMagnetPoint < -MAGNET_PROBE_DISTANCE_TOLERANCE Then
			msg$ = "IsMagnetInTong: ForceTouch stopped " + Str$(distErrorFromPerfectMagnetPoint) + "mm before reaching theoretical magnet position."
			UpdateClient(TASK_MSG, msg$, ERROR_LEVEL)
		ElseIf distErrorFromPerfectMagnetPoint < MAGNET_PROBE_DISTANCE_TOLERANCE Then
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
	
	Move P(standbyPoint)
Fend

Function GTPickMagnet As Boolean
	GTPickMagnet = False

	Tool 0
	
	If Dist(RealPos, P3) < CLOSE_DISTANCE Then
		Go P3
	Else
		Jump P3 '' Cooling Point in front of cradle		
	EndIf

	If Not Open_Gripper Then
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:Open_Gripper failed", ERROR_LEVEL)
		Exit Function
	EndIf
	
	Move P6 '' gripper catches the magnet in cradle

	If Not Close_Gripper Then
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:Close_Gripper failed", ERROR_LEVEL)
		Exit Function
	EndIf

	g_dumbbellStatus = DUMBBELL_IN_GRIPPER

	''Move P4 '' point directly above cradle : P4 can be thought of as ready for action point = Instead of jump to p3, move to p4
	Jump P3
	
	GTPickMagnet = True
Fend

Function GTCheckAndPickMagnet As Boolean
	GTCheckAndPickMagnet = False
	
	If g_dumbbellStatus = DUMBBELL_MISSING Then
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:g_dumbbellStatus says DUMBBELL_MISSING. Please check the robot and update g_dumbbellStatus.", ERROR_LEVEL)
		Exit Function
	ElseIf g_dumbbellStatus = DUMBBELL_IN_GRIPPER Then
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:g_dumbbellStatus is DUMBBELL_IN_GRIPPER", INFO_LEVEL)
	ElseIf g_dumbbellStatus = DUMBBELL_IN_CRADLE Then
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:g_dumbbellStatus is DUMBBELL_IN_CRADLE", INFO_LEVEL)
		If Not GTPickMagnet Then
			UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTPickMagnet failed!", ERROR_LEVEL)
			Exit Function
		EndIf
	ElseIf GTIsMagnetInGripper Then ''CheckMagnet
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTIsMagnetInGripper found magnet on tong.", INFO_LEVEL)
	Else
		UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTIsMagnetInGripper did not find magnet on tong.", INFO_LEVEL)
		If Not GTPickMagnet Then
			UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTPickMagnet failed!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		'' Second check to determine whether magnet is missing
		If GTIsMagnetInGripper Then ''CheckMagnet
			g_dumbbellStatus = DUMBBELL_IN_GRIPPER '' assert again
			UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTIsMagnetInGripper found magnet on tong after GTPickMagnet.", INFO_LEVEL)
		Else
			g_dumbbellStatus = DUMBBELL_MISSING
			UpdateClient(TASK_MSG, "GTCheckAndPickMagnet:GTIsMagnetInGripper failed to detect magnet on tong even after GTPickMagnet.", ERROR_LEVEL)
			Exit Function
		EndIf
	EndIf
	
	GTCheckAndPickMagnet = True
Fend

Function GTCheckMagnetForDismount As Boolean
	GTCheckMagnetForDismount = False
'' if magnet is in gripper, put it in Cradle
	If g_dumbbellStatus = DUMBBELL_IN_GRIPPER Then
		If Not GTReturnMagnet Then
			g_RunResult$ = "GTCheckMagnetForDismount->GTReturnMagnet failed"
			UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
			Exit Function
		EndIf
	ElseIf g_dumbbellStatus = DUMBBELL_IN_CRADLE Then
		UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:g_dumbbellStatus is DUMBBELL_IN_CRADLE", INFO_LEVEL)
	ElseIf GTIsMagnetInGripper Then ''CheckMagnet
		'' This and the following checks whether magnet is in cradle or gripper and sets g_dumbbellStatus accordingly
		'' Bit of a lengthy process but because this is called only once when robot is restarted, I am sticking with this
		UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:GTIsMagnetInGripper found magnet on tong.", INFO_LEVEL)
	Else
		UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:GTIsMagnetInGripper did not find magnet on tong.", INFO_LEVEL)
		If Not GTPickMagnet Then
			UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:GTPickMagnet failed!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		'' Second check to determine whether magnet is missing
		If GTIsMagnetInGripper Then ''CheckMagnet
			g_dumbbellStatus = DUMBBELL_IN_GRIPPER '' assert again
			UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:GTIsMagnetInGripper found magnet on tong after GTPickMagnet.", INFO_LEVEL)
	
			If Not GTReturnMagnet Then
				g_RunResult$ = "GTCheckMagnetForDismount->GTReturnMagnet failed"
				UpdateClient(TASK_MSG, g_RunResult$, ERROR_LEVEL)
				Exit Function
			EndIf
		Else
			g_dumbbellStatus = DUMBBELL_MISSING
			UpdateClient(TASK_MSG, "GTCheckMagnetForDismount:GTIsMagnetInGripper failed to detect magnet on tong even after GTPickMagnet.", ERROR_LEVEL)
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
		Jump P4 '' this point is directly above cradle
	EndIf

	Move P6 '' gripper catches the magnet in cradle
	
	If Not Open_Gripper Then
		UpdateClient(TASK_MSG, "GTReturnMagnet:Open_Gripper failed", INFO_LEVEL)
		Exit Function
	EndIf

	Move P3 '' Cooling Point in front of cradle
	
	'' No need to close gripper
	''If Not Close_Gripper Then
	''	GTUpdateClient(TASK_FAILURE_REPORT, MID_LEVEL_FUNCTION, "GTReturnMagnet:Close_Gripper failed")
	''	Exit Function
	''EndIf
	
	g_dumbbellStatus = DUMBBELL_IN_CRADLE
	
	GTReturnMagnet = True
Fend

Function GTReturnMagnetAndGoHome As Boolean
	GTReturnMagnetAndGoHome = False

	If Not GTReturnMagnet Then
		UpdateClient(TASK_MSG, "GTReturnMagnetAndGoHome:GTReturnMagnet failed", ERROR_LEVEL)
		Exit Function
	EndIf

	'' Return Home and Close Lid
	LimZ 0
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	Jump P1
	Jump P0
	Close_Lid
	
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
		Case ANGLED_PLACER_TOOL
			''The angles in this condition have a small mathematical error.
			''The following is copied from PLACER_TOOL. Although not mathematically perfect, (-90) works.
			''For mathematical perfection we need to offset CU(Tlset(ANGLED_PLACER_TOOL)) for all angles below
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
	Move RealPos +X(twistMagnetHeadSafeDistanceX) +Y(twistMagnetHeadSafeDistanceY) +U(twistAngleInGlobalCoordinates)
Fend

''' *** Goniometer Mount/Dismount Moves *** '''
Function GTJumpHomeToGonioDewarSide As Boolean
	String msg$

	If (Dist(RealPos, P0) < CLOSE_DISTANCE) Then Jump P1
		
	If Not Open_Lid Then
		UpdateClient(TASK_MSG, "GTJumpHomeToGonioDewarSide:Open_Lid failed", ERROR_LEVEL)
		GTJumpHomeToGonioDewarSide = False
        Exit Function
    EndIf
   
   	If (Dist(RealPos, P18) < CLOSE_DISTANCE) Then ''Required in StressTestSuperPuck
   		Go P18 ''Required in StressTestSuperPuck
   	Else
		Jump P18
	EndIf
	
	GTJumpHomeToGonioDewarSide = True
Fend

Function GTMoveToGoniometer As Boolean
	GTMoveToGoniometer = False

	If Not Close_Gripper Then
		UpdateClient(TASK_MSG, "GTMoveToGoniometer:Close_Gripper failed", ERROR_LEVEL)
		Exit Function
	EndIf
	
	Tool 0
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	
	If (CX(RealPos) > 0) And (CX(P1) * CY(RealPos) < CX(RealPos) * CY(P1)) Then
		''The above condition checks whether the robot is in the region before P1 containing P0 
		'' Mathematically, Atan(CY(RealPos)/CX(RealPos)) <  Atan(CY(P1)/CX(P1)) checks the angle made by realpos < angle of P1
		'' CX(RealPos) > 0 checks whether the robot is in first quadrant (near home and not near goni)
		Jump P1
	EndIf
	
	If Dist(RealPos, P4) < CLOSE_DISTANCE Then
		'' This function is called when Robot is at P4, during MountSample
		Move P2 CP
		Move P18 CP
	ElseIf Dist(RealPos, P18) < CLOSE_DISTANCE Then ''Required in StressTestSuperPuck
		Go P18 ''Required in StressTestSuperPuck
	Else
        Jump P18
	EndIf

	Arc P28, P38 CP
	Move P22
	'' Only if P22 is reached return True

	GTMoveToGoniometer = True
Fend


Function GTMoveGoniometerToDewarSide As Boolean

	If Not Close_Gripper Then
		UpdateClient(TASK_MSG, "GTMoveGoniometerToDewarSide:Close_Gripper failed", ERROR_LEVEL)
		GTMoveGoniometerToDewarSide = False
		Exit Function
	EndIf
	
	GTsetRobotSpeedMode(OUTSIDE_LN2_SPEED)
	Move P38 CP
	Arc P28, P18
	''Move P18

	GTMoveGoniometerToDewarSide = True
Fend


