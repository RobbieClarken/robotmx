#include "networkdefs.inc"
#include "genericdefs.inc"

Boolean m_GTInitialized

Function GTInitialize() As Boolean
	If m_GTInitialized Then
		GTInitialize = True
		Exit Function
	Else
		'' This is the first call of GTInitialize() function
		GTInitialize = False
		m_GTInitialized = False
	EndIf

	InitForceConstants
	
	initSuperPuckConstants
	GTInitPrintLevel
	
	If Not GTInitAllPoints Then
		UpdateClient(TASK_MSG, "GTInitialize:GTInitAllPoints failed", ERROR_LEVEL)
		Exit Function
	EndIf
	
	GTInitialize = True
	m_GTInitialized = True
Fend

