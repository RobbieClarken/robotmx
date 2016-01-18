#include "networkdefs.inc"
#include "forcedefs.inc"
#include "mxrobotdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"

Global Preserve Real g_CASSampleDistanceError(NUM_CASSETTES, NUM_ROWS, NUM_COLUMNS)
Global Preserve Integer g_CAS_PortStatus(NUM_CASSETTES, NUM_ROWS, NUM_COLUMNS)

Function GTParseColumnIndex(columnChar$ As String, ByRef columnIndex As Integer) As Boolean
	columnChar$ = UCase$(columnChar$)
	columnIndex = Asc(columnChar$) - Asc("A")
	
	If (columnIndex < 0) Or (columnIndex > NUM_COLUMNS - 1) Then
		columnIndex = UNKNOWN_POSITION
		GTParseColumnIndex = False
		Exit Function
	EndIf

	GTParseColumnIndex = True
Fend

Function GTcolumnName$(columnIndex As Integer)
	GTcolumnName$ = Chr$(Asc("A") + columnIndex)
Fend

Function GTprobeCassettePort(cassette_position As Integer, rowIndex As Integer, columnIndex As Integer, jumpToStandbyPoint As Boolean)
	String msg$
	
	Tool PLACER_TOOL
	LimZ g_Jump_LimZ_LN2
	
	Integer standbyPoint
	standbyPoint = 52
	
	Real CAScolumnAngleOffset, Uangle, adjustedU
	CAScolumnAngleOffset = (columnIndex * 360.0) / NUM_COLUMNS
	Uangle = g_AngleOfFirstColumn(cassette_position) + g_AngleOffset(cassette_position) + CAScolumnAngleOffset + 180
	adjustedU = GTadjustUAngle(cassette_position, Uangle)

	Real ZoffsetFromBottom
	ZoffsetFromBottom = (CASSETTE_A1_HEIGHT + CASSETTE_ROW_HEIGHT * rowIndex) * CASSETTE_SHRINK_FACTOR

	Real standby_circle_radius
	standby_circle_radius = CASSETTE_RADIUS * CASSETTE_SHRINK_FACTOR + PROBE_STANDBY_DISTANCE
	
	GTSetCircumferencePointFromU(cassette_position, adjustedU, standby_circle_radius, ZoffsetFromBottom, standbyPoint)
			
	Real maxDistanceToScan
	maxDistanceToScan = PROBE_STANDBY_DISTANCE + SAMPLE_DIST_PIN_DEEP_IN_CAS + TOLERANCE_FROM_PIN_DEEP_IN_CAS
	
	If jumpToStandbyPoint Then
		Jump P(standbyPoint)
		ForceCalibrateAndCheck(LOW_SENSITIVITY, LOW_SENSITIVITY)
	Else
		Move P(standbyPoint)
	EndIf
	
	GTsetRobotSpeedMode(PROBE_SPEED)
	
	g_CAS_PortStatus(cassette_position, rowIndex, columnIndex) = PORT_UNKNOWN
	If ForceTouch(DIRECTION_CAVITY_TAIL, maxDistanceToScan, False) Then

		Real distanceCASSurfacetoHere
		distanceCASSurfacetoHere = Dist(P(standbyPoint), RealPos) - PROBE_STANDBY_DISTANCE
		
		'' Distance error from perfect sample position
		Real distErrorFromPerfectSamplePos
		distErrorFromPerfectSamplePos = distanceCASSurfacetoHere - SAMPLE_DIST_PIN_DEEP_IN_CAS
		g_CASSampleDistanceError(cassette_position, rowIndex, columnIndex) = distErrorFromPerfectSamplePos

		If distErrorFromPerfectSamplePos < -TOLERANCE_FROM_PIN_DEEP_IN_CAS Then
			''This condition means port jam or the sample is sticking out which is considered PORT_ERROR
			g_CAS_PortStatus(cassette_position, rowIndex, columnIndex) = PORT_ERROR
			msg$ = "GTprobeCassettePort: ForceTouch on " + GTcolumnName$(columnIndex) + ":" + Str$(rowIndex + 1) + " stopped " + Str$(distErrorFromPerfectSamplePos) + "mm before reaching theoretical sample surface."
			UpdateClient(TASK_MSG, msg$, WARNING_LEVEL)
		ElseIf distErrorFromPerfectSamplePos < TOLERANCE_FROM_PIN_DEEP_IN_CAS Then
			g_CAS_PortStatus(cassette_position, rowIndex, columnIndex) = PORT_OCCUPIED
			msg$ = "GTprobeCassettePort: ForceTouch detected Sample at " + GTcolumnName$(columnIndex) + ":" + Str$(rowIndex + 1) + " with distance error =" + Str$(distErrorFromPerfectSamplePos) + "."
			UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
		Else
			''This condition is never reached because ForceTouch stops when maxDistanceToScan is reached	
			''This condition is only to complete the If..Else Statement if an error occurs then we reach here
			g_CAS_PortStatus(cassette_position, rowIndex, columnIndex) = PORT_VACANT
			msg$ = "GTprobeCassettePort: ForceTouch on " + GTcolumnName$(columnIndex) + ":" + Str$(rowIndex + 1) + " moved " + Str$(distErrorFromPerfectSamplePos) + "mm beyond theoretical sample surface."
			UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
		EndIf
		
		GTTwistOffMagnet
	Else
		'' There is no sample (or ForceTouch failure)
		g_CAS_PortStatus(cassette_position, rowIndex, columnIndex) = PORT_VACANT
		g_CASSampleDistanceError(cassette_position, rowIndex, columnIndex) = Dist(P(standbyPoint), RealPos) - PROBE_STANDBY_DISTANCE - SAMPLE_DIST_PIN_DEEP_IN_CAS
		msg$ = "GTprobeCassettePort: ForceTouch failed to detect " + GTcolumnName$(columnIndex) + ":" + Str$(rowIndex + 1) + " even after travelling maximum scan distance!"
		UpdateClient(TASK_MSG, msg$, INFO_LEVEL)
		Move P(standbyPoint)
	EndIf
	
	'' Client Update after probing decision has been made
	msg$ = "{'set':'sample_distances', 'position':'" + GTCassettePosition$(cassette_position) + "', 'start':'" + Str$(GTgetPortIndexFromCassetteVars(cassette_position, columnIndex, rowIndex)) + ", 'value':[" + FmtStr$(g_CASSampleDistanceError(cassette_position, rowIndex, columnIndex), "0.000") + ",]}"
	UpdateClient(CLIENT_UPDATE, msg$, INFO_LEVEL)
	msg$ = "{'set':'PORT_STATES', 'position':" + GTCassettePosition$(cassette_position) + ", 'start':'" + Str$(GTgetPortIndexFromCassetteVars(cassette_position, columnIndex, rowIndex)) + ", 'value':[" + Str$(g_CAS_PortStatus(cassette_position, rowIndex, columnIndex)) + ",]}"
	UpdateClient(CLIENT_UPDATE, msg$, INFO_LEVEL)
		
	'' The following code just realigns the dumbbell from twistoffmagnet position so not required if sample present in port
	'' Move P(standbyPoint) '' This is commented to reduce the time for probing
	'' we have to move to standbyPoint only for the last port probe to avoid hitting the cassette when jump is called
	
	'' previous robot speed is restored only after coming back to standby point, otherwise sample might stick to placer magnet
	GTLoadPreviousRobotSpeedMode
Fend

Function GTProbeSpecificPortsInCassette(cassette_position As Integer) As Boolean
	Integer columnIndex, rowIndex
	Integer probeStringLengthToCheck
	Integer rowsToStep
	String PortProbeRequestChar$
	Boolean probeThisColumn
	Boolean jumpToStandbyPoint

	'' Check whether it is really a normal cassette OR calibration cassette
	'' This also sets rowsToStep for the following "for" loops in this function
	Select g_CassetteType(cassette_position)
		Case NORMAL_CASSETTE
			rowsToStep = 1
		Case CALIBRATION_CASSETTE
			rowsToStep = NUM_ROWS - 1
		Default
			UpdateClient(TASK_MSG, "GTProbeSpecificPortsInCassette failed: " + GTCassetteName$(cassette_position) + " is not a Normal Cassette!", ERROR_LEVEL)
			GTProbeSpecificPortsInCassette = False
			Exit Function
	Send

	For columnIndex = 0 To NUM_COLUMNS - 1
		'' probeStringLengthToCheck is also the number of ports in this column to check
		probeStringLengthToCheck = Len(g_PortsRequestString$(cassette_position)) - columnIndex * NUM_ROWS
		If NUM_ROWS < probeStringLengthToCheck Then probeStringLengthToCheck = NUM_ROWS

		'' Initial check through probe request string to check whether there is a request by user, to probe any port in this column
		probeThisColumn = False
		For rowIndex = 0 To probeStringLengthToCheck - 1 Step rowsToStep
			PortProbeRequestChar$ = Mid$(g_PortsRequestString$(cassette_position), GTgetPortIndexFromCassetteVars(cassette_position, columnIndex, rowIndex) + 1, 1)
			If PortProbeRequestChar$ = "1" Then
				probeThisColumn = True
				'' If a port is requested to probe, we don't have to check further, just exit for this for loop and start probing
				Exit For
			EndIf
		Next
		
		'' If there is a request to probe a port in this column
		If probeThisColumn Then
			'' jump to standy point when probing the first time in a column
			jumpToStandbyPoint = True
			
			For rowIndex = 0 To probeStringLengthToCheck - 1 Step rowsToStep
				PortProbeRequestChar$ = Mid$(g_PortsRequestString$(cassette_position), columnIndex * NUM_ROWS + rowIndex + 1, 1)
				If PortProbeRequestChar$ = "1" Then
					''UpdateClient(TASK_MSG, "GTProbeSpecificPortsInCassette->GTprobeCassettePort(" + GTCassetteName$(cassette_position) + ",row=" + Str$(rowIndex + 1) + ",col=" + GTcolumnName$(columnIndex) + ")", INFO_LEVEL)
					GTprobeCassettePort(cassette_position, rowIndex, columnIndex, jumpToStandbyPoint)
					'' Once jumped to a column, no more jumps are required for probing ports in the same column
					jumpToStandbyPoint = False
				EndIf
			Next
			
			'' we have to move to standbyPoint only for the last port probe to avoid hitting the cassette when jump is called
			Move P52 '' P52 is used as standbyPoint throughout GT domain
		EndIf
	Next
	
	GTProbeSpecificPortsInCassette = True
Fend

Function GTResetSpecificPortsInCassette(cassette_position As Integer)
	Integer columnIndex, rowIndex
	Integer resetStringLengthToCheck
	String PortResetRequestChar$

	For columnIndex = 0 To NUM_COLUMNS - 1
		'' resetStringLengthToCheck is also the number of ports in this column to reset
		resetStringLengthToCheck = Len(g_PortsRequestString$(cassette_position)) - columnIndex * NUM_ROWS
		If NUM_ROWS < resetStringLengthToCheck Then resetStringLengthToCheck = NUM_ROWS
		
		For rowIndex = 0 To resetStringLengthToCheck - 1
			'' Reset the cassette ports corresponding to 1's in probeRequestString
			PortResetRequestChar$ = Mid$(g_PortsRequestString$(cassette_position), GTgetPortIndexFromCassetteVars(cassette_position, columnIndex, rowIndex), 1)
			If (PortResetRequestChar$ = "1") Then
				''UpdateClient(TASK_MSG, "GTResetSpecificPortsInCassette->GTprobeCassettePort(" + GTCassetteName$(cassette_position) + ",row=" + Str$(rowIndex + 1) + ",col=" + GTcolumnName$(columnIndex) + ")", INFO_LEVEL)
				g_CASSampleDistanceError(cassette_position, rowIndex, columnIndex) = 0.0
				g_CAS_PortStatus(cassette_position, rowIndex, columnIndex) = PORT_UNKNOWN
			EndIf
		Next
	Next
	
	If g_CassetteType(cassette_position) = CALIBRATION_CASSETTE Then
		For columnIndex = 0 To NUM_COLUMNS - 1
			'' Reset the cassette ports corresponding to the rows 2 to 7, because these ports don't exist in calibration cassette
			For rowIndex = 1 To NUM_ROWS - 2
				''UpdateClient(TASK_MSG, "GTResetSpecificPortsInCassette->GTprobeCassettePort(" + GTCassetteName$(cassette_position) + ",row=" + Str$(rowIndex + 1) + ",col=" + GTcolumnName$(columnIndex) + ")", INFO_LEVEL)
				g_CASSampleDistanceError(cassette_position, rowIndex, columnIndex) = 0.0
				g_CAS_PortStatus(cassette_position, rowIndex, columnIndex) = PORT_UNKNOWN
			Next
		Next
	ElseIf g_CassetteType(cassette_position) <> NORMAL_CASSETTE Then
		'' This condition is reached only if the cassette is nether a normal cassette nor a calibration cassette
		'' Or this function (GTResetSpecificPortsInCassette) is called before probing CassetteType
		'' So reset all the ports to unknown
		For columnIndex = 0 To NUM_COLUMNS - 1
			For rowIndex = 0 To NUM_ROWS - 1
				''UpdateClient(TASK_MSG, "GTResetSpecificPortsInCassette->GTprobeCassettePort(" + GTCassetteName$(cassette_position) + ",row=" + Str$(rowIndex + 1) + ",col=" + GTcolumnName$(columnIndex) + ")", INFO_LEVEL)
				g_CASSampleDistanceError(cassette_position, rowIndex, columnIndex) = 0.0
				g_CAS_PortStatus(cassette_position, rowIndex, columnIndex) = PORT_UNKNOWN
			Next
		Next
	EndIf
Fend

'' *************** Mounting Code starts from here ***************
Function GTsetCassetteMountStandbyPoints(cassette_position As Integer, rowIndex As Integer, columnIndex As Integer, standbyDistanceFromCASSurface As Real)
	Real ZoffsetFromBottom
	ZoffsetFromBottom = (CASSETTE_A1_HEIGHT + CASSETTE_ROW_HEIGHT * rowIndex) * CASSETTE_SHRINK_FACTOR
	
	Real standby_circle_radius
	standby_circle_radius = CASSETTE_RADIUS * CASSETTE_SHRINK_FACTOR + standbyDistanceFromCASSurface

	Real uPointingTowardsPort, adjustedUPointingTowardsPort
	uPointingTowardsPort = g_AngleOfFirstColumn(cassette_position) + g_AngleOffset(cassette_position) + (columnIndex * 360.0) / NUM_COLUMNS
	adjustedUPointingTowardsPort = GTadjustUAngle(cassette_position, uPointingTowardsPort)

	Real uAngleOfPassingArcPoint
	uAngleOfPassingArcPoint = (g_AngleOfFirstColumn(cassette_position) + adjustedUPointingTowardsPort) /2.0


	Integer cassetteStandbyPoint, casStandbyToPortStandbyArcPoint, portStandbyPoint
	cassetteStandbyPoint = 50
	casStandbyToPortStandbyArcPoint = 51
	portStandbyPoint = 52

	GTSetCircumferencePointFromU(cassette_position, g_UForNormalStandby(cassette_position), standby_circle_radius, ZoffsetFromBottom, cassetteStandbyPoint)
	GTSetCircumferencePointFromU(cassette_position, uAngleOfPassingArcPoint, standby_circle_radius, ZoffsetFromBottom, casStandbyToPortStandbyArcPoint)
	GTSetCircumferencePointFromU(cassette_position, adjustedUPointingTowardsPort, standby_circle_radius, ZoffsetFromBottom, portStandbyPoint)
Fend

