#include "networkdefs.inc"
#include "genericdefs.inc"
#include "cassettedefs.inc"
#include "superpuckdefs.inc"
#include "jsondefs.inc"

Function GTgetPortIndexFromCassetteVars(cassette_position As Integer, columnPuckIndex As Integer, rowPuckPortIndex As Integer) As Integer
	If g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		GTgetPortIndexFromCassetteVars = columnPuckIndex * NUM_PUCK_PORTS + rowPuckPortIndex
	ElseIf (g_CassetteType(cassette_position) = NORMAL_CASSETTE Or g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Then
		GTgetPortIndexFromCassetteVars = columnPuckIndex * NUM_ROWS + rowPuckPortIndex
	EndIf
Fend

Function GTsendNormalCassetteData(dataToSend As Integer, cassette_position As Integer)
	'' This function also sends Calibration Cassette data
	
	String JSONResponse$
	Integer portsPerJSONPacket, numJSONPackets, responseJSONPacketIndex
	Integer startPortIndex, endPortIndex, portIndex
	Integer columnIndex, rowIndex
	Integer puckIndex, puckPortIndex

	portsPerJSONPacket = 16
	numJSONPackets = (NUM_ROWS * NUM_COLUMNS) / portsPerJSONPacket
	
	For responseJSONPacketIndex = 0 To numJSONPackets - 1
		startPortIndex = responseJSONPacketIndex * portsPerJSONPacket
		endPortIndex = (responseJSONPacketIndex + 1) * portsPerJSONPacket - 1
		
		If dataToSend = PORT_STATES Then
			JSONResponse$ = "{'set':'PORT_STATES'"
		ElseIf dataToSend = sample_distances Then
			JSONResponse$ = "{'set':'sample_distances'"
		Else
			UpdateClient(TASK_MSG, "Invalid dataToSend Request!", ERROR_LEVEL)
			Exit Function
		EndIf

		JSONResponse$ = JSONResponse$ + ",'position':'" + GTCassettePosition$(cassette_position) + "'"
		JSONResponse$ = JSONResponse$ + ",'type':'" + GTCassetteType$(g_CassetteType(cassette_position)) + "'"
		JSONResponse$ = JSONResponse$ + ",'start':" + Str$(startPortIndex) + ",'value':["
		For portIndex = startPortIndex To endPortIndex
			columnIndex = portIndex / NUM_ROWS
			rowIndex = portIndex - (columnIndex * NUM_ROWS)
			
			If dataToSend = PORT_STATES Then
				JSONResponse$ = JSONResponse$ + Str$(g_CAS_PortStatus(cassette_position, rowIndex, columnIndex)) + "," ''GTPortStatusString$
			ElseIf dataToSend = sample_distances Then
				JSONResponse$ = JSONResponse$ + FmtStr$(g_CASSampleDistanceError(cassette_position, rowIndex, columnIndex), "0.00") + ","
			EndIf
		Next
		JSONResponse$ = JSONResponse$ + "]}"

		UpdateClient(CLIENT_UPDATE, JSONResponse$, INFO_LEVEL)
	Next

Fend

Function GTsendSuperPuckData(dataToSend As Integer, cassette_position As Integer)
	String JSONResponse$
	Integer portsPerJSONPacket, numJSONPackets, responseJSONPacketIndex
	Integer startPortIndex, endPortIndex, portIndex
	Integer puckIndex, puckPortIndex
	
	portsPerJSONPacket = 16 '' One packet for each puck
	numJSONPackets = NUM_PUCKS
	
	For responseJSONPacketIndex = 0 To numJSONPackets - 1
		startPortIndex = responseJSONPacketIndex * portsPerJSONPacket
		endPortIndex = (responseJSONPacketIndex + 1) * portsPerJSONPacket - 1
		
		If dataToSend = PORT_STATES Then
			JSONResponse$ = "{'set':'PORT_STATES'"
		ElseIf dataToSend = sample_distances Then
			JSONResponse$ = "{'set':'sample_distances'"
		Else
			UpdateClient(TASK_MSG, "Invalid dataToSend Request!", ERROR_LEVEL)
			Exit Function
		EndIf
		
		JSONResponse$ = JSONResponse$ + ",'position':'" + GTCassettePosition$(cassette_position) + "'"
		JSONResponse$ = JSONResponse$ + ",'type':'" + GTCassetteType$(g_CassetteType(cassette_position)) + "'"
		JSONResponse$ = JSONResponse$ + ",'start':" + Str$(startPortIndex) + ",'value':["
		puckIndex = responseJSONPacketIndex
		For puckPortIndex = 0 To NUM_PUCK_PORTS - 1
			If dataToSend = PORT_STATES Then
				JSONResponse$ = JSONResponse$ + Str$(g_SP_PortStatus(cassette_position, puckIndex, puckPortIndex)) + ","
			ElseIf dataToSend = sample_distances Then
				JSONResponse$ = JSONResponse$ + FmtStr$(g_SPSampleDistanceError(cassette_position, puckIndex, puckPortIndex), "0.00") + ","
			EndIf
		Next
		JSONResponse$ = JSONResponse$ + "]}"

		UpdateClient(CLIENT_UPDATE, JSONResponse$, INFO_LEVEL)
	Next

Fend

Function GTsendPuckData(cassette_position As Integer)
	String JSONResponse$
	Integer puckIndex
	
	JSONResponse$ = "{'set':'puck_states'"
	JSONResponse$ = JSONResponse$ + ",'position':'" + GTCassettePosition$(cassette_position) + "'"
	JSONResponse$ = JSONResponse$ + ",'type':'" + GTCassetteType$(g_CassetteType(cassette_position)) + "'"
	JSONResponse$ = JSONResponse$ + ",'start':" + Str$(0)
	JSONResponse$ = JSONResponse$ + ",'value':["
	For puckIndex = 0 To NUM_PUCKS - 1
		JSONResponse$ = JSONResponse$ + Str$(g_PuckStatus(cassette_position, puckIndex)) + ","
	Next
	JSONResponse$ = JSONResponse$ + "]}"

	UpdateClient(CLIENT_UPDATE, JSONResponse$, INFO_LEVEL)
Fend

Function GTsendCassetteData(dataToSend As Integer, cassette_position As Integer)
	If (g_CassetteType(cassette_position) = NORMAL_CASSETTE) Or (g_CassetteType(cassette_position) = CALIBRATION_CASSETTE) Then
		GTsendNormalCassetteData(dataToSend, cassette_position)
	ElseIf g_CassetteType(cassette_position) = SUPERPUCK_CASSETTE Then
		If dataToSend = puck_states Then
			GTsendPuckData(cassette_position)
		Else
			GTsendSuperPuckData(dataToSend, cassette_position)
		EndIf
	Else
		'' Unknown Cassette
		String JSONResponse$
		
		If dataToSend = PORT_STATES Then
			JSONResponse$ = "{'set':'PORT_STATES'"
		ElseIf dataToSend = sample_distances Then
			JSONResponse$ = "{'set':'sample_distances'"
		ElseIf dataToSend = puck_states Then
			JSONResponse$ = "{'set':'puck_states'"
		Else
			UpdateClient(TASK_MSG, "Invalid dataToSend Request!", ERROR_LEVEL)
			Exit Function
		EndIf

		JSONResponse$ = JSONResponse$ + ",'position':'" + GTCassettePosition$(cassette_position) + "'"
		JSONResponse$ = JSONResponse$ + ",'type':'" + GTCassetteType$(g_CassetteType(cassette_position)) + "'"
		JSONResponse$ = JSONResponse$ + ",'start':0','value':[]}"
	
		UpdateClient(CLIENT_UPDATE, JSONResponse$, INFO_LEVEL)
	EndIf
Fend
