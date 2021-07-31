
enum struct CEStrangePartDefinition 
{
	int m_iIndex;
	char m_sEvent[256];
}

enum struct CEStrangePartLevelData
{
	char m_sDataName[128];
	ArrayList m_Levels;
}

enum struct CEStrangePartLevel
{
	int m_Points;
	char m_sItemPrefix[64];
	int m_iItemStyle;
}
