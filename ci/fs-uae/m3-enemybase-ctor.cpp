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

const char* CEnemyBase::Name() const { return NULL; }
int CEnemyBase::Sprite() const { return 0; }
float CEnemyBase::Speed() const { return 0.0f; }
enum TWeapon CEnemyBase::CurrentWeapon() const { return EWeaponFist; }
int CEnemyBase::Hostile() const { return 0; }
int CEnemyBase::Energy() const { return 0; }
int CEnemyBase::Reward() const { return 0; }
int CEnemyBase::ExplosionDeath() const { return 0; }
int CEnemyBase::SightDistance() const { return 0; }
