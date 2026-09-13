#include "CEnemyBase.h"

const char* CEnemyBase::Name() const { return iName; }
int CEnemyBase::Sprite() const { return iSprite; }
float CEnemyBase::Speed() const { return iSpeed; }
enum TWeapon CEnemyBase::CurrentWeapon() const { return iCurrentWeapon; }
int CEnemyBase::Hostile() const { return iHostile; }
int CEnemyBase::Energy() const { return iEnergy; }
int CEnemyBase::Reward() const { return iReward; }
int CEnemyBase::ExplosionDeath() const { return iExplosionDeath; }
int CEnemyBase::SightDistance() const { return iSightDistance; }
