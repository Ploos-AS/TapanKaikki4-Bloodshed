#include "CSteam.h"

CSteam::CSteam(float aX,float aY,int aAngle,int aSpeed)
{
	iX=aX;
	iY=aY;
	iAngle=aAngle;
	iSpeed=aSpeed;	
}

CSteam::CSteam(FILE *fptr, int aVersion)
{
	ReadFromFile(fptr, aVersion);
}
