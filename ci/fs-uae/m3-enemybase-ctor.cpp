#include <stdlib.h>
#include "CLevel.h"
#include "CEnemyBase.h"

CEnemyBase::CEnemyBase()
{
    iName = NULL;
    iSprite = 0;
    iSpeed = 0.0f;
    iCurrentWeapon = EWeaponFist;
    iHostile = 0;
    iEnergy = 0;
    iReward = 0;
    iExplosionDeath = 0;
    iSightDistance = 10 * KBlockSpriteSize;
}
