#include "GTGenericdefs.inc"
#include "GTCassettedefs.inc"
#include "GTSuperPuckdefs.inc"
#include "GTReporterdefs.inc"

Function GTProbeOneCassette(cassette_position As Integer) As Boolean
	Integer standbyPointNum
	Real scanZdistance
	Real cassette_top_Z_value, scanned_cassette_height
	Integer guessedCassetteType
	Real guessedCassetteType_height_error
	
	standbyPointNum = 52
	
	Tool PICKER_TOOL
	
	g_RunResult$ = "progress GTProbeOneCassette->GTSetScanCassetteTopStandbyPoint"
	GTSetScanCassetteTopStandbyPoint(cassette_position, standbyPointNum, 0, ByRef scanZdistance)
	
	g_RunResult$ = "progress GTProbeOneCassette->GTScanCassetteTop"
	If GTScanCassetteTop(standbyPointNum, scanZdistance, ByRef cassette_top_Z_value) Then
		scanned_cassette_height = cassette_top_Z_value - g_BottomZ(cassette_position)
		GTUpdateClient(TASK_MESSAGE_REPORT, HIGH_LEVEL_FUNCTION, "GTScanCassetteTop completed.  Detected Cassette Height = " + Str$(scanned_cassette_height))
	Else
		GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTScanCassetteTop failed: error in GTScanCassetteTop!")
		g_RunResult$ = "error GTProbeOneCassette->GTScanCassetteTop"
		GTProbeOneCassette = False
		Exit Function
	EndIf

	g_RunResult$ = "progress GTProbeOneCassette->GTCassetteTypeFromHeight"
	If Not GTCassetteTypeFromHeight(cassette_position, scanned_cassette_height, ByRef guessedCassetteType, ByRef guessedCassetteType_height_error) Then
		If guessedCassetteType_height_error > MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY Then
			GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeOneCassette->GTCassetteTypeFromHeight failed: guessedCassetteType_height_error > MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY!")
			g_RunResult$ = "error GTProbeOneCassette->GTCassetteTypeFromHeight: guessedCassetteType_height_error > MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY"
			GTProbeOneCassette = False
			Exit Function
		Else
			GTUpdateClient(TASK_MESSAGE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeOneCassette->GTCassetteTypeFromHeight: guessedCassetteType_height_error < MAX_ERR_FOR_SCAN_CAS_TYPE_RTRY. Starting comprehensive scan for Cassette Type")

			g_RunResult$ = "progress GTProbeOneCassette->GTfindAverageCassetteHeight"
			Real averageCassetteHeight
			If GTfindAverageCassetteHeight(cassette_position, scanned_cassette_height, guessedCassetteType, ByRef averageCassetteHeight) Then
				If Not GTCassetteTypeFromHeight(cassette_position, averageCassetteHeight, ByRef guessedCassetteType, ByRef guessedCassetteType_height_error) Then
					g_RunResult$ = "error GTCassetteTypeFromHeight: averageHeight > ACCPT_ERROR_IN_CASSETTE_HEIGHT"
					GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeOneCassette->GTCassetteTypeFromHeight failed: guessedCassetteType_height_error=" + Str$(guessedCassetteType_height_error) + " for averageCassetteHeight=" + Str$(averageCassetteHeight))
					GTProbeOneCassette = False
					Exit Function
				EndIf
			Else
				g_RunResult$ = "error GTProbeOneCassette->GTfindAverageCassetteHeight!"
				GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeOneCassette failed: error in GTfindAverageCassetteHeight!")
				GTProbeOneCassette = False
				Exit Function
			EndIf
		EndIf
	EndIf
	
	SetVerySlowSpeed
	g_RunResult$ = "success GTProbeOneCassette"
	GTProbeOneCassette = True
Fend

Function GTProbeAllPorts(cassette_position As Integer) As Boolean
	Integer rowIndex, columnIndex

	Select g_CassetteType(cassette_position)
		Case CALIBRATION_CASSETTE
			For columnIndex = 0 To NUM_COLUMNS - 1
				rowIndex = 0
				g_RunResult$ = "progress GTProbeAllPorts->GTprobeCassettePort(" + GTCassetteName$(cassette_position) + ",row=" + Str$(rowIndex) + ",col=" + GTcolumnName$(columnIndex) + ")"
				GTprobeCassettePort(cassette_position, rowIndex, columnIndex)

				rowIndex = NUM_ROWS - 1
				g_RunResult$ = "progress GTProbeAllPorts->GTprobeCassettePort(" + GTCassetteName$(cassette_position) + ",row=" + Str$(rowIndex) + ",col=" + GTcolumnName$(columnIndex) + ")"
				GTprobeCassettePort(cassette_position, rowIndex, columnIndex)
			Next
			
		Case NORMAL_CASSETTE
			For columnIndex = 0 To NUM_COLUMNS - 1
				For rowIndex = 0 To NUM_ROWS - 1
					g_RunResult$ = "progress GTProbeAllPorts->GTprobeCassettePort(" + GTCassetteName$(cassette_position) + ",row=" + Str$(rowIndex) + ",col=" + GTcolumnName$(columnIndex) + ")"
					GTprobeCassettePort(cassette_position, rowIndex, columnIndex)
				Next
			Next
			
		Case SUPERPUCK_CASSETTE
			Integer puckIndex, portIndex
			For puckIndex = 0 To NUM_PUCKS - 1
				g_RunResult$ = "progress GTProbeAllPorts->GTprobePuckAngleCorrection(" + GTCassetteName$(cassette_position) + "," + GTpuckName$(puckIndex) + ")"
				If Not GTprobeAdaptorAngleCorrection(cassette_position, puckIndex) Then
					g_RunResult$ = "error GTProbeAllPorts->GTprobeAdaptorAngleCorrection!"
					GTUpdateClient(TASK_FAILURE_REPORT, HIGH_LEVEL_FUNCTION, "GTProbeAllPorts failed: error in GTprobeAdaptorAngleCorrection!")
					GTProbeAllPorts = False
					Exit Function
				EndIf

				g_RunResult$ = "progress GTProbeAllPorts->GTprobeSPPuck(" + GTCassetteName$(cassette_position) + "," + GTpuckName$(puckIndex) + ")"
				GTprobeSPPuck(cassette_position, puckIndex)
			
				If g_PuckPresent(cassette_position, puckIndex) Then
					For portIndex = 0 To NUM_PUCK_PORTS - 1
						g_RunResult$ = "progress GTProbeAllPorts->GTprobeSPPuck(" + GTCassetteName$(cassette_position) + "," + GTpuckName$(puckIndex) + "," + Str$(portIndex) + ")"
						GTprobeSPPort(cassette_position, puckIndex, portIndex)
					Next
				EndIf
			Next
	Send

	g_RunResult$ = "success GTProbeAllPorts(" + GTCassetteName$(cassette_position) + ")"
	GTProbeAllPorts = True
Fend

Function ResetPorts(cassette_position As Integer)
	If g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		Integer puckIndex, portIndex
		For puckIndex = 0 To NUM_ROWS - 1
			g_PuckPresent(cassette_position, puckIndex) = False
			For portIndex = 0 To NUM_PUCK_PORTS - 1
				g_SampleDistancefromPuckSurface(cassette_position, puckIndex, portIndex) = 0.0
				g_SP_SamplePresent(cassette_position, puckIndex, NUM_PUCK_PORTS) = False
			Next
		Next
	Else
		Integer columnIndex, rowIndex
		For columnIndex = 0 To NUM_COLUMNS - 1
			For rowIndex = 0 To NUM_ROWS - 1
				g_SampleDistancefromCASSurface(cassette_position, rowIndex, columnIndex) = 0.0
				g_CAS_SamplePresent(cassette_position, rowIndex, columnIndex) = False
			Next
		Next
	EndIf
Fend

Function GTtestCassetteScan(cassette_position As Integer)
	
	''Remove after defining Gonio point
	P21 = XY(0, 0, 0, 0)
	
	If Not GTInitialize Then
		Exit Function
	EndIf
	
	If Not GTProbeOneCassette(cassette_position) Then
		Exit Function
	EndIf
	
	GTProbeAllPorts(cassette_position)
Fend

